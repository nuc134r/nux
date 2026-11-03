import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/features/forwarding/data/keep_alive.dart';
import 'package:nux/features/forwarding/domain/forward_rule.dart';
import 'package:nux/features/forwarding/domain/forwarder.dart';
import 'package:nux/features/forwarding/domain/forwarding_manager.dart';

class FakeForward implements RunningForward {
  bool closed = false;

  @override
  final stats = ForwardStats();

  @override
  int get port => 8080;

  @override
  Future<void> close() async => closed = true;
}

class FakeKeepAlive implements KeepAlive {
  final calls = <String>[];
  final _stop = StreamController<void>.broadcast();

  void pressStop() => _stop.add(null);

  @override
  Future<void> start({required String title, required String text, required String stopLabel}) async => calls.add('start $title');

  @override
  Future<void> update({required String title, required String text}) async => calls.add('update $title');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Stream<void> get stopRequested => _stop.stream;
}

ForwardRule rule(String id, {bool auto = false}) => ForwardRule(
      id: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      connectionId: 'c',
      kind: ForwardKind.local.name,
      label: '',
      bindHost: '127.0.0.1',
      bindPort: 8080,
      targetHost: 'db',
      targetPort: 5432,
      autoStart: auto,
      sortOrder: 0,
    );

void main() {
  late FakeKeepAlive keepAlive;
  late List<Completer<void>> connections;
  late List<FakeForward> forwards;
  late int connectFailures;
  late ForwardException? startError;
  late ForwardingManager manager;

  setUp(() {
    keepAlive = FakeKeepAlive();
    connections = [];
    forwards = [];
    connectFailures = 0;
    startError = null;
    var released = 0;
    manager = ForwardingManager(
      connect: (id) async {
        if (connectFailures > 0) {
          connectFailures--;
          throw Exception('unreachable');
        }
        final done = Completer<void>();
        connections.add(done);
        return ForwardLease(client: Object(), done: done.future, release: () => released++);
      },
      startForward: (lease, rule, onChange) async {
        if (startError != null) throw startError!;
        final f = FakeForward();
        forwards.add(f);
        return f;
      },
      keepAlive: keepAlive,
      log: Log(),
      texts: () => ForwardingTexts(title: (n) => '$n active', text: (i, o) => '$i/$o', stop: 'Stop'),
      retryDelays: const [Duration(milliseconds: 10), Duration(milliseconds: 10)],
    );
  });
  tearDown(() => manager.dispose());

  test('start and stop drive the background service', () async {
    await manager.start(rule('a'));
    expect(manager.status('a').state, ForwardState.active);
    expect(keepAlive.calls.first, 'start 1 active');
    await manager.stop('a');
    expect(forwards.single.closed, isTrue);
    expect(manager.status('a').state, ForwardState.stopped);
    expect(keepAlive.calls.last, 'stop');
  });

  test('a dropped connection reconnects', () async {
    await manager.start(rule('a'));
    connections.single.complete();
    await pumpEventQueue();
    expect(manager.status('a').state, ForwardState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(manager.status('a').state, ForwardState.active);
    expect(forwards, hasLength(2));
    expect(forwards.first.closed, isTrue);
  });

  test('gives up after the retries; configuration errors fail at once', () async {
    connectFailures = 5;
    await manager.start(rule('a'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(manager.status('a').state, ForwardState.failed);

    connectFailures = 0;
    startError = const ForwardException(ForwardError.portInUse, 'taken');
    await manager.start(rule('b'));
    expect(manager.status('b').state, ForwardState.failed);
    expect(manager.status('b').error, isA<ForwardException>());
  });

  test('the notification can stop everything; auto-start rules start', () async {
    await manager.startAuto([rule('a', auto: true), rule('b')]);
    await pumpEventQueue();
    expect(manager.status('a').on, isTrue);
    expect(manager.status('b').on, isFalse);
    keepAlive.pressStop();
    await pumpEventQueue();
    expect(manager.activeCount, 0);
  });
}
