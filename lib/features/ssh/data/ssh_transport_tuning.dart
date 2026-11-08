import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// dartssh2 encrypts in Dart on the UI thread, so the cipher decides how fast files move and how smooth
/// the app stays meanwhile. Measured (6 MB over SFTP, AOT): AES-GCM 6.1 s, ChaCha20-Poly1305 0.3 s,
/// AES-CTR with an encrypt-then-MAC 0.7 s. dartssh2 prefers GCM, which every OpenSSH accepts, so
/// without this every connection ran on the slowest one. GCM stays last for servers that offer nothing
/// else.
const nuxSshAlgorithms = SSHAlgorithms(
  cipher: [
    SSHCipherType.chacha20poly1305,
    SSHCipherType.aes128ctr,
    SSHCipherType.aes256ctr,
    SSHCipherType.aes128gcm,
    SSHCipherType.aes256gcm,
  ],
);

/// Hands what the socket receives to dartssh2 in pieces of at most [piece] bytes, one per event-loop
/// turn. dartssh2 decrypts everything a read delivers before returning (its awaits only yield to
/// microtasks), so a burst of a few hundred KB froze the screen for a moment; in pieces, frames are drawn
/// in between (longest stall measured 100 ms → 3 ms, same speed).
class PacedSocket implements SSHSocket {
  PacedSocket(this._inner, {this.piece = 32 << 10});

  final SSHSocket _inner;
  final int piece;

  @override
  late final Stream<Uint8List> stream = _inner.stream.asyncExpand(_split);

  Stream<Uint8List> _split(Uint8List chunk) async* {
    if (chunk.length <= piece) {
      yield chunk;
      await Future<void>.delayed(Duration.zero);
      return;
    }
    for (var i = 0; i < chunk.length; i += piece) {
      yield Uint8List.sublistView(chunk, i, i + piece > chunk.length ? chunk.length : i + piece);
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() => _inner.close();

  @override
  void destroy() => _inner.destroy();

  @override
  Future<void> flush() => _inner.flush();
}
