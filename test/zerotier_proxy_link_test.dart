import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/proxy/domain/socks5.dart';
import 'package:nux/features/proxy/domain/zerotier_proxy_link.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart' show ZeroTierUdpRelay;

import 'socks5_test_server.dart';

// The node is not touched: setRelay records what it would be told (libzt stays out of tests).
void main() {
  late List<ZeroTierUdpRelay?> relays;
  late ZeroTierProxyLink link;

  setUp(() {
    relays = [];
    link = ZeroTierProxyLink(
      setRelay: relays.add,
      firstRetry: const Duration(milliseconds: 50),
      maxRetry: const Duration(milliseconds: 200),
    );
  });
  tearDown(() => link.dispose());

  Future<void> until(bool Function() ok) async {
    for (var i = 0; i < 100 && !ok(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(ok(), isTrue);
  }

  test('held until the association is made, then through its relay; direct again without a proxy', () async {
    final socks = await TestSocks5Server.start(username: 'nux', password: 'secret');
    addTearDown(socks.close);
    await link.use(Socks5Proxy('127.0.0.1', socks.port, username: 'nux', password: 'secret'));
    expect(link.state, ProxyLinkState.connected);
    expect(relays.first, ZeroTierUdpRelay.hold, reason: 'nothing goes out directly while it is being made');
    expect(relays.last, isA<ZeroTierUdpRelay>().having((r) => '$r', 'relay', startsWith('ZeroTierUdpRelay.socks5(127.0.0.1, ')));
    expect(link.relay, startsWith('127.0.0.1:'));

    await link.use(null);
    expect(link.state, ProxyLinkState.off);
    expect(relays.last, isNull);
  });

  test('a dropped association holds the node and is made again', () async {
    final socks = await TestSocks5Server.start();
    addTearDown(socks.close);
    await link.use(Socks5Proxy('127.0.0.1', socks.port));
    expect(socks.associations, 1);
    relays.clear();
    socks.dropAll();
    await until(() => socks.associations == 2 && link.state == ProxyLinkState.connected);
    expect(relays.first, ZeroTierUdpRelay.hold);
    expect('${relays.last}', startsWith('ZeroTierUdpRelay.socks5('));
  });

  test('a proxy that fails keeps the node held and is retried; stopping keeps it held', () async {
    final socks = await TestSocks5Server.start(udp: false);
    addTearDown(socks.close);
    await link.use(Socks5Proxy('127.0.0.1', socks.port));
    expect(link.state, ProxyLinkState.failed);
    expect(link.error, isA<Socks5Exception>().having((e) => e.error, 'error', Socks5Error.commandNotSupported));
    expect(relays, [ZeroTierUdpRelay.hold], reason: 'never direct');
    await until(() => socks.requests >= 3);
    expect(link.state, ProxyLinkState.failed);
    expect(relays.whereType<Object>().every((r) => r == ZeroTierUdpRelay.hold), isTrue);

    link.close();
    final asked = socks.requests;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(socks.requests, asked, reason: 'no more attempts once closed');
    expect(relays.last, ZeroTierUdpRelay.hold, reason: 'a node started again sends nothing until use()');
  });
}
