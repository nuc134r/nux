import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../../core/log/log.dart';
import '../domain/ssh_prompter.dart';
import 'ssh_connector.dart';

enum SshState { disconnected, connecting, connected }

/// One user of a pooled connection. Call [release] when done.
class SshLease {
  SshLease._(this.connectionId, this.client, this._pool);

  final String connectionId;
  final SSHClient client;
  final SshPool _pool;
  bool _released = false;

  /// Completes when the connection closes (for any reason).
  Future<void> get done => client.done;

  void release() {
    if (_released) return;
    _released = true;
    _pool._release(connectionId, client);
  }
}

class _Entry {
  _Entry(this.future);

  final Future<SSHClient> future;
  SSHClient? client;
  int refs = 0;
  Timer? idle;
}

/// Shares one SSH connection per saved connection between terminals, file browsers and forwardings.
/// A connection without users stays open for [idleTimeout] so a quick reopen is instant.
class SshPool extends ChangeNotifier {
  SshPool(this._connector, this._log, {this.idleTimeout = const Duration(seconds: 30)});

  final SshConnector _connector;
  final Log _log;
  final Duration idleTimeout;
  final Map<String, _Entry> _entries = {};
  bool _disposed = false;

  SshState state(String connectionId) {
    final e = _entries[connectionId];
    if (e == null) return SshState.disconnected;
    return e.client == null ? SshState.connecting : SshState.connected;
  }

  /// Connected or connecting connection ids.
  Set<String> get active => _entries.keys.toSet();

  /// The open connection to [connectionId], if there is one (not one being set up).
  SSHClient? connectedClient(String connectionId) => _entries[connectionId]?.client;

  /// Open connections that something uses (idle ones close by themselves soon).
  int get inUseCount => _entries.values.where((e) => e.client != null && e.refs > 0).length;

  /// Connects (or joins a connection in progress) and takes a lease on it.
  Future<SshLease> acquire(String connectionId, SshPrompter prompter) async {
    var entry = _entries[connectionId];
    if (entry == null) {
      entry = _Entry(_connector.connect(connectionId, prompter));
      _entries[connectionId] = entry;
      _notify();
      final e = entry;
      e.future.then((client) {
        if (_entries[connectionId] != e) return;
        e.client = client;
        // A dropped connection completes done with its error; that is handled here, not uncaught.
        client.done.whenComplete(() => _closed(connectionId, client)).ignore();
        _notify();
      }, onError: (Object error) {
        if (_entries[connectionId] == e) _entries.remove(connectionId);
        _notify();
      });
    }
    entry.refs++;
    entry.idle?.cancel();
    if (entry.refs == 1 && entry.client != null) _notify();
    try {
      final client = await entry.future;
      return SshLease._(connectionId, client, this);
    } catch (_) {
      entry.refs--;
      rethrow;
    }
  }

  void _release(String connectionId, SSHClient client) {
    final e = _entries[connectionId];
    if (e == null || e.client != client) return;
    e.refs--;
    if (e.refs <= 0) {
      _notify();
      e.idle?.cancel();
      e.idle = Timer(idleTimeout, () {
        if (_entries[connectionId] == e && e.refs <= 0) {
          _log.i('ssh', 'Closing idle connection');
          client.close();
        }
      });
    }
  }

  void _closed(String connectionId, SSHClient client) {
    final e = _entries[connectionId];
    if (e != null && e.client == client) {
      e.idle?.cancel();
      _entries.remove(connectionId);
      _log.i('ssh', 'Connection closed');
      _notify();
    }
  }

  /// Closes the connection now, for all its users.
  void disconnect(String connectionId) {
    final e = _entries[connectionId];
    e?.client?.close();
  }

  /// Closes every connection (the background notification's "Disconnect all").
  void disconnectAll() {
    for (final e in _entries.values.toList()) {
      e.client?.close();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _entries.values) {
      e.idle?.cancel();
      e.client?.close();
    }
    _entries.clear();
    super.dispose();
  }
}
