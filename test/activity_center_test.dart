import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/activity/activity_center.dart';

void main() {
  test('operations run, progress and finish; events count as new until read', () {
    final c = ActivityCenter();
    final pull = c.start(ActivitySource.git, 'git pull', cancel: () {});
    expect(c.running, [pull]);
    c.update(pull, progress: .4, subtitle: 'Receiving objects: 40%');
    expect(pull.progress, .4);
    c.finish(pull, ActivityState.done, subtitle: 'Fast-forward');
    expect(c.running, isEmpty);
    expect(pull.cancel, isNull);
    expect(pull.progress, isNull);
    c.event(ActivitySource.forwarding, 'Database failed', state: ActivityState.failed);
    expect(c.unread, 2);
    expect(c.entries.first.title, 'Database failed', reason: 'newest first');
    c.markRead();
    expect(c.unread, 0);
    c.update(pull, progress: .9);
    expect(pull.progress, isNull, reason: 'finished entries do not change');
  });

  test('clear keeps what runs; the oldest finished go first when full', () {
    final c = ActivityCenter(keep: 2);
    final running = c.start(ActivitySource.transfer, 'up');
    c.event(ActivitySource.other, 'a');
    c.event(ActivitySource.other, 'b');
    expect(c.entries.map((e) => e.title), ['b', 'up']);
    c.clear();
    expect(c.entries, [running]);
  });
}
