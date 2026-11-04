import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/viewer/domain/line_diff.dart';
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
