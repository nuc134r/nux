import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/background/background_quit.dart';
import 'package:nux/core/background/keep_alive.dart';
import 'package:nux/core/background/keep_alive_hub.dart';

void main() {
  late KeepAliveHub hub;
  late BackgroundQuit quitter;
  var shutdowns = 0, quits = 0;

  Future<void> state(WidgetTester tester, AppLifecycleState s) async {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester) async {
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      await state(tester, s);
    }
    await state(tester, AppLifecycleState.detached);
  }

  setUp(() {
    shutdowns = quits = 0;
  });

  Future<void> start(WidgetTester tester) async {
    hub = KeepAliveHub(NoKeepAlive(), stopLabel: () => 'Stop', idleText: () => '');
    quitter = BackgroundQuit(
      hub: hub,
      shutdown: () async => shutdowns++,
      quit: () => quits++,
      grace: const Duration(seconds: 3),
    );
    addTearDown(quitter.dispose);
    await state(tester, AppLifecycleState.resumed);
  }

  testWidgets('without a screen and with nothing running, nux quits after the grace period', (tester) async {
    await start(tester);
    await leave(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(quits, 0, reason: 'still within the grace period');
    await tester.pump(const Duration(seconds: 2));
    expect((shutdowns, quits), (1, 1));
  });

  testWidgets('a session keeps it running; once it ends (Stop in the notification), nux quits', (tester) async {
    await start(tester);
    final ssh = hub.slot('ssh');
    await ssh.start(title: '1 connection', text: '', stopLabel: 'Disconnect');
    await leave(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(quits, 0, reason: 'a connection is in use');
    await ssh.stop();
    await tester.pump(const Duration(seconds: 4));
    expect(quits, 1);
  });

  testWidgets('a screen that comes back within the grace period cancels the quit', (tester) async {
    await start(tester);
    await leave(tester);
    await tester.pump(const Duration(seconds: 1));
    await state(tester, AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    expect(quits, 0);
  });

  testWidgets('in the background with the screen still there (Home), nux keeps running', (tester) async {
    await start(tester);
    await state(tester, AppLifecycleState.inactive);
    await state(tester, AppLifecycleState.hidden);
    await state(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(quits, 0);
  });
}
