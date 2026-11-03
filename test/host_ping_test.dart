import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/connections/data/host_ping.dart';

import 'helpers.dart';

void main() {
  test('direct hosts are pinged; ZeroTier hosts only while their network is up', () async {
    var zeroTierPings = 0;
    final c = ProviderContainer(overrides: [
      ...testOverrides(),
      zeroTierPingerProvider.overrideWithValue((host, port) async {
        zeroTierPings++;
        return const Duration(milliseconds: 7);
      }),
    ]);
    addTearDown(c.dispose);

    final direct = c.listen(hostPingProvider((id: 'a', host: 'build.example.com', port: 22, network: null, viaJump: false)), (_, _) {});
    expect((await c.read(hostPingProvider((id: 'a', host: 'build.example.com', port: 22, network: null, viaJump: false)).future)).rtt, const Duration(milliseconds: 42));
    direct.close();

    // The node is not running in tests: not measurable, and ZeroTier is not started for it.
    final zt = c.listen(hostPingProvider((id: 'b', host: '192.0.2.5', port: 22, network: '8056c2e21c000001', viaJump: false)), (_, _) {});
    expect((await c.read(hostPingProvider((id: 'b', host: '192.0.2.5', port: 22, network: '8056c2e21c000001', viaJump: false)).future)).measured, isFalse);
    expect(zeroTierPings, 0);
    zt.close();

    // Behind a jump host and not connected: not measurable (no direct route).
    final viaJump = (id: 'c', host: '192.0.2.9', port: 22, network: null, viaJump: true);
    final j = c.listen(hostPingProvider(viaJump), (_, _) {});
    expect((await c.read(hostPingProvider(viaJump).future)).measured, isFalse);
    j.close();
  });
}
