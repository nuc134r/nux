import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/workspace/domain/git_activity.dart';

void main() {
  test('progress lines replace each other; the percentage is read from the latest', () {
    final a = GitActivity();
    final run = a.start('git pull');
    a.output(run, 'remote: Counting objects: 20, done.\n');
    a.output(run, 'Receiving objects:  10% (2/20)\rReceiving objects:  45% (9/20)\r');
    expect(run.lastLine, 'Receiving objects:  45% (9/20)');
    expect(run.progress, closeTo(.45, 1e-9));
    a.output(run, 'Receiving objects: 100% (20/20), done.\nFast-forward\n');
    expect(run.lines.where((l) => l.isNotEmpty).toList(), [
      'remote: Counting objects: 20, done.',
      'Receiving objects: 100% (20/20), done.',
      'Fast-forward',
    ]);
    a.finish(run, 0);
    expect(run.running, isFalse);
    expect(run.progress, isNull);
    expect(a.current, isNull);
    expect(a.last, same(run));
  });

  test('keeps the newest runs', () {
    final a = GitActivity(keep: 2);
    for (final c in ['a', 'b', 'c']) {
      a.finish(a.start(c), 0);
    }
    expect(a.runs.map((r) => r.command), ['b', 'c']);
  });
}
