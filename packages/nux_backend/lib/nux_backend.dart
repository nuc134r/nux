/// Backend-neutral interfaces for nux.
///
/// The UI talks to a [Backend] and never needs to know whether files come over SFTP,
/// from Termux (SSH to localhost) or from local storage. See docs/PLAN.md §3.
library;

export 'src/backend.dart';
export 'src/errors.dart';
export 'src/file_system.dart';
export 'src/process_runner.dart';
export 'src/pty.dart';
export 'src/shell_quote.dart';
