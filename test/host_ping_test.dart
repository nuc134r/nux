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

    final direct = c.listen(hostPingProvider(('build.example.com', 22, null)), (_, _) {});
    expect((await c.read(hostPingProvider(('build.example.com', 22, null)).future)).rtt, const Duration(milliseconds: 42));
    direct.close();

    // The node is not running in tests: not measurable, and ZeroTier is not started for it.
    final zt = c.listen(hostPingProvider(('192.0.2.5', 22, '8056c2e21c000001')), (_, _) {});
    expect((await c.read(hostPingProvider(('192.0.2.5', 22, '8056c2e21c000001')).future)).measured, isFalse);
    expect(zeroTierPings, 0);
    zt.close();
  });
}
