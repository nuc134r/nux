import 'dart:async';
import 'dart:convert';

import 'package:flterm/flterm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_backend.dart';
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/data/ssh_pool.dart';
import '../../ssh/domain/ssh_prompter.dart';

enum TerminalState { idle, connecting, connected, closed }

/// Lines the session writes into the terminal itself (translated by the view).
class TerminalStrings {
  const TerminalStrings({
    required this.connecting,
    required this.disconnected,
    required this.pressEnter,
    required this.failure,
  });

  final String Function(String address) connecting;
  final String disconnected;
  final String pressEnter;
  final String Function(SshConnectException error) failure;

  static final fallback = TerminalStrings(
    connecting: (a) => 'Connecting to $a…',
    disconnected: 'Disconnected',
    pressEnter: 'Press Enter to reconnect',
    failure: (e) => e.message,
  );
}

/// A shell on a saved connection, rendered by a flterm [TerminalController].
///
/// Lives in the tab object, so scrollback and the connection survive the tab being parked.
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.connectionId,
    this.directory,
    required this._pool,
    required this._prompter,
    required ConnectionRepository connections,
    required this._log,
  }) : _connections = connections {
    terminal
      ..onOutput = _input
      ..onResize = _resized
      ..onTitleChanged = notifyListeners
      ..onBell = HapticFeedback.mediumImpact;
    _connectionSub = connections.watch(connectionId).listen((c) {
      connection = c;
      notifyListeners();
    });
  }

  final String connectionId;
  final String? directory;
  final SshPool _pool;
  final SshPrompter Function() _prompter;
  final ConnectionRepository _connections;
  final Log _log;

  final TerminalController terminal = TerminalController();
  TerminalStrings strings = TerminalStrings.fallback;

  TerminalState state = TerminalState.idle;
  Connection? connection;

  /// Why the last attempt failed, if it did.
  SshConnectException? error;

  StreamSubscription<Connection?>? _connectionSub;
  SshLease? _lease;
  PtySession? _pty;
  StreamSubscription<Uint8List>? _output;
  (int, int)? _size;
  Completer<void>? _sized;
  bool _disposed = false;

  /// The window title the remote program set (e.g. `user@host: ~/src`), if any.
  String get remoteTitle => terminal.title;

  Future<void> connect() async {
    if (_disposed || state == TerminalState.connecting || state == TerminalState.connected) return;
    error = null;
    _set(TerminalState.connecting);
    final c = connection ?? await _connections.get(connectionId);
    _note(strings.connecting(c?.address ?? connectionId));
    try {
      final lease = await _pool.acquire(connectionId, _prompter());
      if (_disposed) return lease.release();
      _lease = lease;
      final (cols, rows) = await _waitForSize();
      final pty = await SshBackend(id: connectionId, displayName: c?.name ?? '', client: lease.client)
          .ptyHost
          .open(columns: cols, rows: rows, workingDirectory: directory);
      if (_disposed) {
        await pty.close();
        return lease.release();
      }
      _pty = pty;
      _output = pty.output.listen(terminal.write);
      _set(TerminalState.connected);
      pty.done.whenComplete(_closed).ignore();
      lease.done.whenComplete(_closed).ignore();
    } on SshConnectException catch (e) {
      _fail(e);
    } catch (e, st) {
      _log.e('terminal', 'Shell failed', e, st);
      _fail(SshConnectException(SshFailure.other, '$e'));
    }
  }

  void _fail(SshConnectException e) {
    _lease?.release();
    _lease = null;
    error = e;
    if (_disposed) return;
    _note(strings.failure(e), error: true);
    _note(strings.pressEnter);
    _set(TerminalState.closed);
  }

  /// Ends the shell; the tab stays with its scrollback.
  Future<void> disconnect() async {
    await _pty?.close();
    _closed();
  }

  void _closed() {
    if (state != TerminalState.connected) return;
    _output?.cancel();
    _output = null;
    _pty = null;
    _lease?.release();
    _lease = null;
    if (_disposed) return;
    _note('\r\n${strings.disconnected}');
    _note(strings.pressEnter);
    _set(TerminalState.closed);
  }

  void _input(Uint8List bytes) {
    final pty = _pty;
    if (pty != null) {
      pty.write(bytes);
    } else if (state == TerminalState.closed && bytes.contains(13)) {
      connect();
    }
  }

  void _resized(int cols, int rows) {
    _size = (cols, rows);
    _pty?.resize(cols, rows);
    final sized = _sized;
    if (sized != null && !sized.isCompleted) sized.complete();
  }

  /// The view reports its grid after its first layout; a parked tab never does, so fall back to 80×24.
  Future<(int, int)> _waitForSize() async {
    if (_size == null) {
      _sized = Completer<void>();
      await _sized!.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    return _size ?? (80, 24);
  }

  /// A dim (or red) line from nux itself, not from the server.
  void _note(String text, {bool error = false}) {
    final style = error ? '\x1b[31m' : '\x1b[2m';
    terminal.write(Uint8List.fromList(utf8.encode('$style$text\x1b[0m\r\n')));
  }

  void _set(TerminalState s) {
    state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionSub?.cancel();
    _output?.cancel();
    _pty?.close();
    _lease?.release();
    terminal.dispose();
    super.dispose();
  }
}
