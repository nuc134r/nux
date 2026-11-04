import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/viewer/domain/line_diff.dart';
import 'package:nux/features/workspace/domain/git_model.dart';
import 'package:nux/features/workspace/domain/git_repo.dart';
import 'package:nux/features/workspace/domain/git_status.dart';
import 'package:nux_backend/nux_backend.dart';

import 'local_runner.dart';

Future<void> sh(String dir, String command) async {
  final r = await Process.run('sh', ['-c', command], workingDirectory: dir);
  if (r.exitCode != 0) throw Exception('$command: ${r.stderr}');
}

void main() {
  late Directory dir;
  late GitRepo git;
  setUp(() async {
    dir = Directory(Directory.systemTemp.createTempSync('nux-git-').resolveSymbolicLinksSync());
    await sh(dir.path, 'git init -q -b main && git config user.name T && git config user.email t@example.com');
    File('${dir.path}/a.txt').writeAsStringSync('one\ntwo\n');
    await sh(dir.path, 'git add . && git commit -qm init');
    git = GitRepo(LocalRunner(), dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('stage, unstage, diff and commit', () async {
    File('${dir.path}/a.txt').writeAsStringSync('one\nTWO\n');
    File('${dir.path}/new.txt').writeAsStringSync('hi\n');
    var s = (await git.status())!;
    final a = s.changeOf('${dir.path}/a.txt')!;
    expect((a.indexKind, a.worktreeKind), (null, GitChangeKind.modified));
    expect(s.changeOf('${dir.path}/new.txt')!.worktreeKind, GitChangeKind.untracked);

    final lines = parseUnifiedDiff(await git.diff('${dir.path}/a.txt'));
    expect(lines.whereType<DiffLine>().map((l) => '$l'), [' one', '-two', '+TWO']);
    expect(parseUnifiedDiff(await git.diff('${dir.path}/new.txt', untracked: true)).single.toString(), '+hi');

    await git.stage(['${dir.path}/a.txt']);
    s = (await git.status())!;
    expect(s.changeOf('${dir.path}/a.txt')!.indexKind, GitChangeKind.modified);
    expect(parseUnifiedDiff(await git.diff('${dir.path}/a.txt', staged: true)), isNotEmpty);
    await git.unstage(['${dir.path}/a.txt']);
    expect((await git.status())!.changeOf('${dir.path}/a.txt')!.indexKind, isNull);

    await git.stage(['${dir.path}/a.txt', '${dir.path}/new.txt']);
    await git.commit("second 'quoted' commit");
    expect((await git.status())!.changes, isEmpty);
    expect(await git.lastMessage(), "second 'quoted' commit");
    await git.commit('second, reworded', amend: true);
    expect(await git.lastMessage(), 'second, reworded');
  });

  test('discard, branches', () async {
    File('${dir.path}/a.txt').writeAsStringSync('changed\n');
    File('${dir.path}/junk.txt').writeAsStringSync('x\n');
    await git.discard('${dir.path}/a.txt', untracked: false);
    await git.discard('${dir.path}/junk.txt', untracked: true);
    expect((await git.status())!.changes, isEmpty);
    expect(File('${dir.path}/junk.txt').existsSync(), isFalse);

    await git.createBranch('feature');
    expect(await git.branches(), ['feature', 'main']);
    await git.switchTo('main');
    expect((await git.branches()).first, 'main');
    expect((await git.status())!.branch, 'main');
  });

  test('pull and push against a remote: no upstream, diverged branches', () async {
    final remote = Directory(Directory.systemTemp.createTempSync('nux-remote-').resolveSymbolicLinksSync());
    addTearDown(() => remote.deleteSync(recursive: true));
    await sh(remote.path, 'git init -q --bare -b main');
    await sh(dir.path, 'git remote add origin ${remote.path}');
    await expectLater(git.push(), throwsA(isA<GitException>().having((e) => e.noUpstream, 'noUpstream', isTrue)));
    await git.push(setUpstream: true);

    // Another clone pushes; we commit too: the branches diverge.
    final other = Directory(Directory.systemTemp.createTempSync('nux-other-').resolveSymbolicLinksSync());
    addTearDown(() => other.deleteSync(recursive: true));
    await sh(other.path, 'git clone -q ${remote.path} . && git config user.name O && git config user.email o@example.com '
        '&& echo b > b.txt && git add . && git commit -qm theirs && git push -q');
    File('${dir.path}/c.txt').writeAsStringSync('c\n');
    await git.stage(['${dir.path}/c.txt']);
    await git.commit('ours');
    await git.fetch();
    await expectLater(git.pull(), throwsA(isA<GitException>().having((e) => e.diverged, 'diverged', isTrue)));
    await git.pull(rebase: true);
    expect(File('${dir.path}/b.txt').existsSync(), isTrue);
    await git.push();
  });

  test('credentials reach git through stdin, not the command line', () async {
    final command = GitRepo.withCredentialsCommand(dir.path, 'credential fill');
    expect(command, isNot(contains('s3cret')));
    final p = await LocalRunner().start(command);
    final out = p.stdout.map(String.fromCharCodes).join();
    p.stdin.add('me\ns3cret\nprotocol=https\nhost=example.com\n\n'.codeUnits);
    await p.stdin.close();
    expect(await out, allOf(contains('username=me'), contains('password=s3cret')));
  });

  test('a fetch that needs credentials asks for them once and retries with them', () async {
    final runner = _AuthRunner();
    String? askedFor;
    final repo = GitRepo(runner, '/repo', askCredentials: (remote, {required retry}) async {
      askedFor = remote;
      return (username: 'me', password: 'tok');
    });
    await repo.fetch();
    expect(askedFor, 'https://example.com');
    expect(runner.stdin, 'me\ntok\n');
    expect(repo.credentials?.username, 'me', reason: 'kept for the next fetch');
  });

  test("history with a graph, a commit's diff, blame", () async {
    await sh(dir.path, 'echo three >> a.txt && git commit -qam "add three" && git switch -q -c side && '
        'echo s > s.txt && git add s.txt && git commit -qm side && git switch -q main && echo m > m.txt && '
        'git add m.txt && git commit -qm main-work && git merge -q --no-edit side');
    final log = await git.log();
    expect(log.first.isMerge, isTrue);
    expect(log.map((c) => c.subject), containsAll(['add three', 'side', 'main-work', 'init']));
    expect(log.first.refs.join(' '), contains('main'));
    final graph = graphLanes(log);
    expect(graph.first.merges, isNotEmpty, reason: 'the merge draws a line to its second parent');
    expect(graph.map((r) => r.lanes).reduce((a, b) => a > b ? a : b), 2);

    final three = log.firstWhere((c) => c.subject == 'add three');
    final files = await git.show(three.hash);
    expect(files.single.path, 'a.txt');
    expect(files.single.lines.whereType<DiffLine>().where((l) => l.kind == DiffKind.added).single.text, 'three');
    expect(await git.message(three.hash), 'add three');
    expect((await git.log(path: 'a.txt')).map((c) => c.subject), ['add three', 'init']);

    final blame = await git.blame('a.txt');
    expect(blame.map((b) => b.text), ['one', 'two', 'three']);
    expect(blame.last.summary, 'add three');
  });

  test('stage one hunk of two', () async {
    File('${dir.path}/long.txt').writeAsStringSync([for (var i = 0; i < 30; i++) 'line $i'].join('\n'));
    await sh(dir.path, 'git add long.txt && git commit -qm long');
    final lines = [for (var i = 0; i < 30; i++) 'line $i'];
    lines[1] = 'FIRST';
    lines[28] = 'LAST';
    File('${dir.path}/long.txt').writeAsStringSync(lines.join('\n'));
    final hunks = PatchHunks.parse(await git.diff('${dir.path}/long.txt'));
    expect(hunks.hunks, hasLength(2));
    await git.applyToIndex(hunks.patchFor(0));
    final staged = await git.diff('${dir.path}/long.txt', staged: true);
    expect(staged, contains('+FIRST'));
    expect(staged, isNot(contains('+LAST')));
    await git.applyToIndex(PatchHunks.parse(staged).patchFor(0), reverse: true);
    expect(await git.diff('${dir.path}/long.txt', staged: true), isEmpty);
  });

  test('a merge conflict: resolve block by block, stage, continue; or abort', () async {
    await sh(dir.path, 'git switch -q -c other && printf "one\\nTHEIRS\\n" > a.txt && git commit -qam theirs && '
        'git switch -q main && printf "one\\nOURS\\n" > a.txt && git commit -qam ours');
    await sh(dir.path, 'git merge -q other || true');
    expect(await git.operation(), GitOperation.merge);
    final s = (await git.status())!;
    expect(s.changeOf('${dir.path}/a.txt')!.kind, GitChangeKind.conflict);

    final file = ConflictFile.parse(File('${dir.path}/a.txt').readAsStringSync());
    final block = file.blocks.single;
    expect(block.ours, ['OURS']);
    expect(block.theirs, ['THEIRS']);
    block.choice = ConflictChoice.both;
    File('${dir.path}/a.txt').writeAsStringSync(file.resolve());
    expect(File('${dir.path}/a.txt').readAsStringSync(), 'one\nOURS\nTHEIRS\n');
    await git.stage(['${dir.path}/a.txt']);
    await git.continueOperation(GitOperation.merge);
    expect(await git.operation(), isNull);
    expect((await git.log()).first.isMerge, isTrue);

    // Again, and give up this time.
    await sh(dir.path, 'git switch -q other && printf "one\\nX\\n" > a.txt && git commit -qam x && git switch -q main && '
        'printf "one\\nY\\n" > a.txt && git commit -qam y && (git merge -q other || true)');
    expect(await git.operation(), GitOperation.merge);
    await git.abortOperation(GitOperation.merge);
    expect(await git.operation(), isNull);
    expect(File('${dir.path}/a.txt').readAsStringSync(), 'one\nY\n');
  });

  test('stash, branches, tags, sign-off, the equivalent command', () async {
    File('${dir.path}/a.txt').writeAsStringSync('wip\n');
    await git.stash('work in progress');
    expect((await git.status())!.changes, isEmpty);
    final stashes = await git.stashes();
    expect((stashes.single.ref, stashes.single.message.contains('work in progress')), ('stash@{0}', true));
    await git.stashApply('stash@{0}', drop: true);
    expect(File('${dir.path}/a.txt').readAsStringSync(), 'wip\n');
    expect(await git.stashes(), isEmpty);

    await git.stage(['${dir.path}/a.txt']);
    await git.commit('signed', signOff: true);
    expect(git.lastCommand, startsWith('git commit'));
    expect(await git.message('HEAD'), contains('Signed-off-by: T <t@example.com>'));

    await git.createBranch('feat');
    File('${dir.path}/f.txt').writeAsStringSync('f\n');
    await git.stage(['${dir.path}/f.txt']);
    await git.commit('feature');
    await git.switchTo('main');
    await expectLater(git.deleteBranch('feat'), throwsA(isA<GitException>().having((e) => e.notMerged, 'notMerged', isTrue)));
    await git.renameBranch('feat', 'feature');
    expect(await git.branches(), containsAll(['main', 'feature']));
    await git.deleteBranch('feature', force: true);
    expect(await git.branches(), ['main']);

    await git.createTag('v1', message: 'first');
    await git.createTag('light');
    expect(await git.tags(), containsAll(['v1', 'light']));
  });

  test('push preview, and force-with-lease after a rejected push', () async {
    final remote = Directory(Directory.systemTemp.createTempSync('nux-remote2-').resolveSymbolicLinksSync());
    addTearDown(() => remote.deleteSync(recursive: true));
    await sh(remote.path, 'git init -q --bare -b main');
    await sh(dir.path, 'git remote add origin ${remote.path}');
    expect(await git.outgoing(), isNull, reason: 'no upstream yet');
    await git.push(setUpstream: true);
    File('${dir.path}/b.txt').writeAsStringSync('b\n');
    await git.stage(['${dir.path}/b.txt']);
    await git.commit('outgoing one');
    expect((await git.outgoing())!.map((c) => c.subject), ['outgoing one']);
    await git.push();
    // Rewrite the pushed commit: the next push is rejected; force-with-lease goes through.
    await git.commit('reworded', amend: true);
    await expectLater(git.push(), throwsA(isA<GitException>().having((e) => e.rejected, 'rejected', isTrue)));
    await git.push(force: true);
    expect(await git.outgoing(), isEmpty);
  });
}

/// Fails without credentials like git over HTTPS does; succeeds when they come through stdin.
class _AuthRunner implements ProcessRunner {
  String stdin = '';

  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async =>
      const CommandResult(
        exitCode: 128,
        stdout: '',
        stderr: "fatal: could not read Username for 'https://example.com': terminal prompts disabled",
      );

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) async =>
      _FakeProcess(this);
}

class _FakeProcess implements RunningProcess {
  _FakeProcess(this.runner);

  final _AuthRunner runner;
  final _in = StreamController<List<int>>();

  @override
  StreamSink<List<int>> get stdin {
    _in.stream.listen((d) => runner.stdin += String.fromCharCodes(d));
    return _in.sink;
  }

  @override
  Stream<Uint8List> get stdout => const Stream.empty();

  @override
  Stream<Uint8List> get stderr => const Stream.empty();

  @override
  Future<int?> get exitCode async {
    await Future<void>.delayed(Duration.zero);
    return 0;
  }

  @override
  void kill() {}
}
