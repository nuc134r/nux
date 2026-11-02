import 'dart:typed_data';

/// An interactive terminal session (an SSH shell channel, a local PTY).
abstract interface class PtySession {
  Stream<Uint8List> get output;

  void write(Uint8List data);

  void resize(int columns, int rows);

  /// Completes when the session ends (shell exited or connection dropped).
  Future<void> get done;

  Future<void> close();
}

abstract interface class PtyHost {
  Future<PtySession> open({
    required int columns,
    required int rows,
    String terminalType = 'xterm-256color',
    String? workingDirectory,
    Map<String, String>? environment,
  });
}
