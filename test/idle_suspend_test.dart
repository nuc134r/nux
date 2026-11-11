import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/background/idle_suspend.dart';
import 'package:nux/core/background/keep_alive.dart';
import 'package:nux/core/background/keep_alive_hub.dart';
import 'package:nux/features/zerotier/presentation/zerotier_path_badge.dart';

void main() {
  late KeepAliveHub hub;
  var suspends = 0, resumes = 0;

  Future<void> state(WidgetTester tester, AppLifecycleState s) async {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }

  // Home: the app stays alive, only out of sight.
  Future<void> home(WidgetTester tester) async {
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      await state(tester, s);
    }
  }

  Future<void> back(WidgetTester tester) async {
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      await state(tester, s);
    }
  }

  Future<void> start(WidgetTester tester) async {
    suspends = resumes = 0;
    hub = KeepAliveHub(NoKeepAlive(), stopLabel: () => 'Stop', idleText: () => '');
    final idle = IdleSuspend(
      hub: hub,
      suspend: () async => suspends++,
      resume: () async => resumes++,
      after: const Duration(minutes: 2),
    );
    addTearDown(idle.dispose);
    await state(tester, AppLifecycleState.resumed);
  }

  testWidgets('out of sight with nothing running: suspends after the delay, resumes when shown', (tester) async {
    await start(tester);
    await home(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(suspends, 0);
    await tester.pump(const Duration(minutes: 2));
    expect(suspends, 1);
    resumes = 0;
    await back(tester);
    expect(resumes, 1);
  });

  testWidgets('a connection or forward in use keeps it going', (tester) async {
    await start(tester);
    final ssh = hub.slot('ssh');
    await ssh.start(title: '1 connection', text: '', stopLabel: 'Disconnect');
    await home(tester);
    await tester.pump(const Duration(minutes: 10));
    expect(suspends, 0);
    await ssh.stop();
    await tester.pump(const Duration(minutes: 3));
    expect(suspends, 1, reason: 'the delay counts from when nothing is in use');
  });

  testWidgets('coming back within the delay suspends nothing', (tester) async {
    await start(tester);
    await home(tester);
    await tester.pump(const Duration(minutes: 1));
    await back(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(suspends, 0);
  });

  test('path endpoints', () {
    expect(ZeroTierPathBadge.endpoint('192.0.2.7/9993'), '192.0.2.7:9993');
    expect(ZeroTierPathBadge.endpoint('2001:db8::1/41641'), '[2001:db8::1]:41641');
  });
}
