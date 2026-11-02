/// Why a backend operation failed, independent of the transport (SFTP status codes, errno, …).
enum BackendErrorKind {
  notFound,
  alreadyExists,
  permissionDenied,
  notADirectory,
  isADirectory,
  notEmpty,

  /// The connection dropped or could not be established.
  disconnected,

  /// The backend does not support the operation.
  unsupported,
  other,
}

class BackendException implements Exception {
  const BackendException(this.kind, this.message, {this.path, this.cause});

  final BackendErrorKind kind;
  final String message;

  /// The path the operation was about, if any.
  final String? path;

  /// The transport-level error, for logs.
  final Object? cause;

  @override
  String toString() => 'BackendException(${kind.name}${path == null ? '' : ', $path'}): $message';
}
