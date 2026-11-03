import 'dart:io';

/// A throwaway OpenSSH server on 127.0.0.1 for integration tests: its own host key, config and
/// authorized_keys in a temp dir. Null when sshd is not installed.
/// Passwords are offered but never match (the test user has no usable password).
class TestSshServer {
  TestSshServer._(this.dir, this.port, this._process);

  final Directory dir;
  final int port;
  final Process _process;

  String get authorizedKeysPath => '${dir.path}/authorized_keys';

  static String get user => Platform.environment['USER'] ?? (Process.runSync('whoami', []).stdout as String).trim();

  static Future<TestSshServer?> start() async {
    const sshd = '/usr/sbin/sshd';
    if (!File(sshd).existsSync() || Process.runSync('sh', ['-c', 'command -v ssh-keygen']).exitCode != 0) return null;
    final dir = Directory.systemTemp.createTempSync('nux-sshd-');
    Process.runSync('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-f', '${dir.path}/host_ed25519']);
    File('${dir.path}/authorized_keys').writeAsStringSync('');
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final config = File('${dir.path}/sshd_config');
    final text = '''
Port $port
ListenAddress 127.0.0.1
HostKey ${dir.path}/host_ed25519
PidFile ${dir.path}/sshd.pid
AuthorizedKeysFile ${dir.path}/authorized_keys
PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
PermitRootLogin yes
AllowTcpForwarding yes
Subsystem sftp internal-sftp
LogLevel ERROR
''';
    // OpenSSH 9.8+ blocks a source address after failed logins, which would lock the remaining tests
    // out after the wrong-password test. Older servers do not know the option.
    config.writeAsStringSync('${text}PerSourcePenalties no\n');
    final check = Process.runSync(sshd, ['-t', '-f', config.path]);
    if (check.exitCode != 0 && '${check.stderr}'.contains('PerSourcePenalties')) config.writeAsStringSync(text);
    if (Platform.environment['USER'] == 'root' || Process.runSync('id', ['-u']).stdout.toString().trim() == '0') {
      Directory('/run/sshd').createSync(recursive: true);
    }
    final process = await Process.start(sshd, ['-D', '-e', '-f', '${dir.path}/sshd_config']);
    for (var i = 0; i < 50; i++) {
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, port);
        s.destroy();
        return TestSshServer._(dir, port, process);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    process.kill();
    // ignore: avoid_print
    print('sshd did not start: ${await process.stderr.transform(const SystemEncoding().decoder).join()}');
    return null;
  }

  void authorize(String publicLine) => File(authorizedKeysPath).writeAsStringSync('$publicLine\n', mode: FileMode.append);

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
    dir.deleteSync(recursive: true);
  }
}
