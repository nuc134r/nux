import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/background/keep_alive.dart';
import 'package:nux/core/background/keep_alive_hub.dart';

class RecordingKeepAlive implements KeepAlive {
  final calls = <String>[];
  final _stop = StreamController<void>.broadcast();

  void pressStop() => _stop.add(null);

  @override
  Future<void> start({required String title, required String text, required String stopLabel}) async =>
      calls.add('start $title | $text | $stopLabel');

  @override
  Future<void> update({required String title, required String text}) async => calls.add('update $title | $text');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Stream<void> get stopRequested => _stop.stream;
}

void main() {
  late RecordingKeepAlive service;
  late KeepAliveHub hub;
  setUp(() {
    service = RecordingKeepAlive();
    hub = KeepAliveHub(service, stopLabel: () => 'Disconnect all', idleText: () => 'In the background');
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('one service for all slots, shown together in slot order, stopped when the last one stops', () async {
    final ssh = hub.slot('ssh');
    final fwd = hub.slot('forwarding', order: 1);

    await fwd.start(title: '1 forward', text: '↓ 1 KB', stopLabel: 'Stop all');
    await ssh.start(title: '2 SSH connections', text: '', stopLabel: 'Disconnect all');
    await fwd.update(title: '1 forward', text: '↓ 2 KB');
    await fwd.stop();
    await ssh.update(title: '1 SSH connection', text: '');
    await ssh.stop();
    await ssh.stop(); // already stopped: nothing
    await flush();

    expect(service.calls, [
      'start 1 forward | ↓ 1 KB | Stop all',
      'start 2 SSH connections · 1 forward | ↓ 1 KB | Disconnect all', // two reasons: a common button
      'update 2 SSH connections · 1 forward | ↓ 2 KB',
      'update 2 SSH connections | In the background',
      'update 1 SSH connection | In the background',
      'stop',
    ]);
  });

  test("the notification's button reaches every slot", () async {
    final pressed = <String>[];
    hub.slot('ssh').stopRequested.listen((_) => pressed.add('ssh'));
    hub.slot('forwarding').stopRequested.listen((_) => pressed.add('forwarding'));
    service.pressStop();
    await flush();
    expect(pressed, unorderedEquals(['ssh', 'forwarding']));
  });

  test('resync starts the service again while it is wanted (a start refused in the background)', () async {
    final ssh = hub.slot('ssh');
    hub.resync(); // nothing wanted: nothing to do
    await ssh.start(title: '1 SSH connection', text: '', stopLabel: 'Disconnect all');
    hub.resync();
    await ssh.stop();
    hub.resync();
    await flush();
    expect(service.calls, [
      'start 1 SSH connection | In the background | Disconnect all',
      'start 1 SSH connection | In the background | Disconnect all',
      'stop',
    ]);
  });
}
