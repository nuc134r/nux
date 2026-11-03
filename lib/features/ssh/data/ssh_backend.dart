import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:nux_backend/nux_backend.dart';

import 'sftp_file_system.dart';

/// A [Backend] on top of an authenticated SSH connection: SFTP, exec channels and shells.
class SshBackend implements Backend {
  SshBackend({required this.id, required this.displayName, required SSHClient client, this.kind = BackendKind.ssh})
      : _client = client,
        processRunner = SshProcessRunner(client),
        ptyHost = SshPtyHost(client),
        fileSystem = SftpFileSystem(client);

  @override
  final String id;

  @override
  final String displayName;

  @override
  final BackendKind kind;

  final SSHClient _client;

  @override
  Set<Capability> get capabilities => const {Capability.files, Capability.exec, Capability.pty};

  @override
  final SftpFileSystem fileSystem;

  @override
  final ProcessRunner processRunner;

  @override
  final PtyHost ptyHost;

  @override
  Future<void> close() async {
    await fileSystem.close();
    _client.close();
  }
}

/// Prefixes [command] with `cd` and exported variables (servers often refuse `env` requests).
String wrapCommand(String command, {String? workingDirectory, Map<String, String>? environment}) {
  final parts = [
    for (final MapEntry(:key, :value) in (environment ?? const <String, String>{}).entries)
      'export $key=${shellQuote(value)};',
    if (workingDirectory != null) 'cd ${shellQuote(workingDirectory)} &&',
    command,
  ];
  return parts.join(' ');
}

class SshProcessRunner implements ProcessRunner {
  SshProcessRunner(this._client);

  final SSHClient _client;

  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async {
    final session = await _client.execute(wrapCommand(command, workingDirectory: workingDirectory, environment: environment));
    await session.stdin.close();
    final out = session.stdout.cast<List<int>>().transform(utf8.decoder).join();
    final err = session.stderr.cast<List<int>>().transform(utf8.decoder).join();
    final results = await Future.wait([out, err]);
    await session.done;
    return CommandResult(exitCode: session.exitCode, stdout: results[0], stderr: results[1]);
  }

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) async {
    final session = await _client.execute(wrapCommand(command, workingDirectory: workingDirectory, environment: environment));
    return _SshProcess(session);
  }
}

class _SshProcess implements RunningProcess {
  _SshProcess(this._session);

  final SSHSession _session;

  @override
  StreamSink<List<int>> get stdin => _ListSink(_session.stdin);

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  Future<int?> get exitCode => _session.done.then((_) => _session.exitCode);

  @override
  void kill() {
    _session.kill(SSHSignal.TERM);
    _session.close();
  }
}

/// Adapts dartssh2's `StreamSink<Uint8List>` to `StreamSink<List<int>>`.
class _ListSink implements StreamSink<List<int>> {
  _ListSink(this._inner);

  final StreamSink<Uint8List> _inner;

  @override
  void add(List<int> data) => _inner.add(data is Uint8List ? data : Uint8List.fromList(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream.map(Uint8List.fromList));

  @override
  Future<void> close() async => _inner.close();

  @override
  Future<void> get done => _inner.done;
}

class SshPtyHost implements PtyHost {
  SshPtyHost(this._client);

  final SSHClient _client;

  @override
  Future<PtySession> open({
    required int columns,
    required int rows,
    String terminalType = 'xterm-256color',
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final session = await _client.shell(pty: SSHPtyConfig(type: terminalType, width: columns, height: rows));
    if (workingDirectory != null) session.write(utf8.encode('cd ${shellQuote(workingDirectory)} && clear\n'));
    return _SshPty(session);
  }
}

class _SshPty implements PtySession {
  _SshPty(this._session) {
    // stdout and stderr both go to the terminal, in arrival order.
    var open = 2;
    void closeOne() {
      if (--open == 0) _output.close();
    }

    _session.stdout.listen(_output.add, onDone: closeOne, onError: (Object _) => closeOne());
    _session.stderr.listen(_output.add, onDone: closeOne, onError: (Object _) => closeOne());
  }

  final SSHSession _session;
  final _output = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int columns, int rows) => _session.resizeTerminal(columns, rows);

  @override
  Future<void> get done => _session.done;

  @override
  Future<void> close() async => _session.close();
}
