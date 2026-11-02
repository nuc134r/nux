import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/known_hosts_repository.dart';
import '../../connections/domain/host_key_check.dart';
import '../../identities/data/identity_repository.dart';
import '../../identities/domain/key_import.dart';
import '../../identities/domain/key_material.dart';
import '../domain/ssh_prompter.dart';

/// Opens the transport to a host. The default is a TCP socket; ZeroTier plugs in here later.
typedef SshSocketFactory = Future<SSHSocket> Function(String host, int port, Duration timeout);

Future<SSHSocket> tcpSocket(String host, int port, Duration timeout) => SSHSocket.connect(host, port, timeout: timeout);

enum SshFailure {
  /// DNS, refused, unreachable, timed out.
  unreachable,

  /// The user did not trust the server's key.
  hostKeyRejected,

  /// No offered key or password was accepted.
  authFailed,

  /// The user cancelled a prompt.
  cancelled,

  /// The connection (or its jump host) is missing.
  notFound,
  other,
}

class SshConnectException implements Exception {
  const SshConnectException(this.failure, this.message, {this.via});

  final SshFailure failure;
  final String message;

  /// Name of the jump host that failed, when it was not the target itself.
  final String? via;

  @override
  String toString() => 'SshConnectException(${failure.name}${via == null ? '' : ' via $via'}): $message';
}

/// Formats dartssh2's raw SHA-256 host key fingerprint like OpenSSH does.
String formatHostFingerprint(Uint8List sha256) => 'SHA256:${base64.encode(sha256).replaceAll('=', '')}';

/// Connects and authenticates SSH clients for saved connections.
class SshConnector {
  SshConnector({
    required this.connections,
    required this.identities,
    required this.knownHosts,
    required this.log,
    this.socketFactory = tcpSocket,
    this.timeout = const Duration(seconds: 15),
  });

  final ConnectionRepository connections;
  final IdentityRepository identities;
  final KnownHostsRepository knownHosts;
  final Log log;
  final SshSocketFactory socketFactory;
  final Duration timeout;

  /// Keys unlocked with "remember until the app closes", by identity id.
  final Map<String, KeyMaterial> _unlocked = {};

  /// Passwords typed this session (not saved), by connection id, so reconnects do not ask again.
  final Map<String, String> _sessionPasswords = {};

  void forgetUnlockedKeys() {
    _unlocked.clear();
    _sessionPasswords.clear();
  }

  /// Connects to [connectionId] (through its jump hosts) and waits for authentication.
  /// Closing the returned client also closes the jump hosts.
  Future<SSHClient> connect(String connectionId, SshPrompter prompter) => _connect(connectionId, prompter, const {});

  Future<SSHClient> _connect(String id, SshPrompter prompter, Set<String> seen) async {
    final c = await connections.get(id);
    if (c == null) throw const SshConnectException(SshFailure.notFound, 'The connection no longer exists');
    if (seen.contains(id)) throw SshConnectException(SshFailure.other, 'Jump hosts form a loop at ${c.name}');

    SSHClient? jump;
    late SSHSocket socket;
    if (c.jumpHostId != null) {
      try {
        jump = await _connect(c.jumpHostId!, prompter, {...seen, id});
      } on SshConnectException catch (e) {
        throw SshConnectException(e.failure, e.message, via: e.via ?? (await connections.get(c.jumpHostId!))?.name);
      }
      log.i('ssh', 'Forwarding to ${c.host}:${c.port} through jump host');
      try {
        socket = await jump.forwardLocal(c.host, c.port).timeout(timeout);
      } catch (e) {
        jump.close();
        throw SshConnectException(SshFailure.unreachable, '$e');
      }
    } else {
      log.i('ssh', 'Connecting to ${c.host}:${c.port}');
      try {
        socket = await socketFactory(c.host, c.port, timeout);
      } on SocketException catch (e) {
        throw SshConnectException(SshFailure.unreachable, e.osError?.message ?? e.message);
      } on TimeoutException {
        throw const SshConnectException(SshFailure.unreachable, 'Timed out');
      }
    }

    try {
      final client = await _authenticate(c, socket, prompter);
      unawaited(client.done.whenComplete(() => jump?.close()));
      return client;
    } catch (_) {
      jump?.close();
      rethrow;
    }
  }

  Future<SSHClient> _authenticate(Connection c, SSHSocket socket, SshPrompter prompter) async {
    final keys = <SSHKeyPair>[];
    try {
      for (final identityId in c.identityIdList) {
        final key = await _unlock(identityId, prompter);
        if (key != null) keys.add(key.pair);
      }
    } catch (_) {
      socket.destroy();
      rethrow;
    }

    SshFailure? hostKeyFailure;
    var passwordAttempts = 0;
    SecretAnswer? typedPassword;
    final address = c.address;

    final client = SSHClient(
      socket,
      username: c.username,
      identities: keys,
      keepAliveInterval: c.keepAliveSeconds > 0 ? Duration(seconds: c.keepAliveSeconds) : null,
      onVerifyHostKey: (type, fingerprint) async {
        final fp = formatHostFingerprint(fingerprint);
        final status = await knownHosts.check(c.host, c.port, type, fp);
        if (status == HostKeyStatus.trusted) {
          await knownHosts.touch(c.host, c.port, type);
          return true;
        }
        log.w('ssh', 'Host key ${status.name} for ${c.host}:${c.port}: $type $fp');
        final known = await knownHosts.forHost(c.host, c.port);
        final ok = await prompter.confirmHostKey(HostKeyQuestion(
          host: c.host,
          port: c.port,
          keyType: type,
          fingerprint: fp,
          status: status,
          knownFingerprints: [for (final k in known) '${k.keyType} ${k.fingerprint}'],
        ));
        if (!ok) {
          hostKeyFailure = SshFailure.hostKeyRejected;
          return false;
        }
        await knownHosts.trust(c.host, c.port, type, fp);
        return true;
      },
      onPasswordRequest: () async {
        passwordAttempts++;
        if (passwordAttempts == 1) {
          final saved = c.savePassword ? await connections.savedPassword(c.id) : null;
          if (saved != null) return saved;
          final session = _sessionPasswords[c.id];
          if (session != null) return session;
        }
        typedPassword = await prompter.password(connectionName: c.name, address: address, retry: passwordAttempts > 1);
        return typedPassword?.value;
      },
      onUserInfoRequest: (request) async {
        if (request.prompts.isEmpty) return const [];
        return prompter.keyboardInteractive(
          address: address,
          name: request.name,
          instruction: request.instruction,
          prompts: [for (final p in request.prompts) KeyboardInteractivePrompt(p.promptText, echo: p.echo)],
        );
      },
    );

    try {
      await client.authenticated.timeout(const Duration(minutes: 5));
    } catch (e) {
      client.close();
      if (hostKeyFailure != null) throw const SshConnectException(SshFailure.hostKeyRejected, 'Host key not trusted');
      if (e is SSHAuthError) {
        throw SshConnectException(passwordAttempts > 0 && typedPassword == null ? SshFailure.cancelled : SshFailure.authFailed, e.toString());
      }
      if (e is TimeoutException) throw const SshConnectException(SshFailure.unreachable, 'Timed out');
      throw SshConnectException(SshFailure.other, e.toString());
    }

    log.i('ssh', 'Authenticated as ${c.username}');
    final password = typedPassword;
    if (password != null) {
      if (password.remember) {
        await connections.setSavedPassword(c.id, password.value);
      } else {
        _sessionPasswords[c.id] = password.value;
      }
    }
    unawaited(connections.markUsed(c.id));
    return client;
  }

  /// The decrypted key, asking for the passphrase / device unlock when needed. Null when the user
  /// skipped it (the remaining methods are still tried).
  Future<KeyMaterial?> _unlock(String identityId, SshPrompter prompter) async {
    final identity = await identities.get(identityId);
    if (identity == null) return null;
    if (identity.requireBiometric &&
        !await prompter.authenticateUser(reason: identity.name)) {
      throw const SshConnectException(SshFailure.cancelled, 'Device unlock was cancelled');
    }
    final cached = _unlocked[identityId];
    if (cached != null) return cached;
    if (!identity.encrypted) return identities.unlock(identityId);
    for (var retry = false;; retry = true) {
      final answer = await prompter.passphrase(identityName: identity.name, retry: retry);
      if (answer == null) return null;
      try {
        final key = await identities.unlock(identityId, passphrase: answer.value);
        if (answer.remember) _unlocked[identityId] = key;
        return key;
      } on KeyImportException catch (e) {
        if (e.error != KeyImportError.wrongPassphrase) rethrow;
      }
    }
  }
}
