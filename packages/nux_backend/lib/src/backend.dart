import 'file_system.dart';
import 'process_runner.dart';
import 'pty.dart';

/// What a backend can do. The UI hides features whose capability is missing.
enum Capability {
  /// Browse, read and write files ([Backend.fileSystem]).
  files,

  /// Run non-interactive commands ([Backend.processRunner]); needed for git CLI, search and LSP.
  exec,

  /// Interactive terminals ([Backend.ptyHost]).
  pty,

  /// Git operations (CLI over [exec], or libgit2 on the local backend).
  git,

  /// Language servers over the stdio of a process.
  lsp,
}

/// Kind of backend, used for icons and for choosing defaults.
enum BackendKind { ssh, termux, local }

/// A place where a workspace lives: a remote host, Termux, or the device itself.
///
/// Members are null when the backend lacks the matching [Capability].
abstract interface class Backend {
  /// Stable id (the connection's id for SSH/Termux, `local` for the device).
  String get id;

  BackendKind get kind;

  /// What the user sees, e.g. "build server" or "This device".
  String get displayName;

  Set<Capability> get capabilities;

  FileSystem? get fileSystem;

  ProcessRunner? get processRunner;

  PtyHost? get ptyHost;

  /// Closes the underlying connection. Open sessions end.
  Future<void> close();
}

extension BackendCapabilities on Backend {
  bool can(Capability capability) => capabilities.contains(capability);
}
