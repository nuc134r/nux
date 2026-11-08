import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/log/redact.dart';

void main() {
  test('removes private key blocks, even unterminated ones', () {
    const key = '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----';
    expect(redact('key: $key done'), 'key: [private key] done');
    expect(redact('-----BEGIN RSA PRIVATE KEY-----\nMIIE'), '[private key]');
  });

  test('removes passwords, tokens and credentials', () {
    expect(redact('login password=hunter2 ok'), 'login password=[redacted] ok');
    expect(redact('{"passphrase": "s3cret"}'), '{"passphrase": "[redacted]"}');
    expect(redact('Authorization: Bearer abc.def.ghi'), 'Authorization: Bearer [redacted]');
    expect(redact('push with ghp_${'a' * 36}'), 'push with [token]');
    expect(redact('git clone https://me:tok3n@example.com/r.git'), 'git clone https://me:[redacted]@example.com/r.git');
  });

  test('keeps hosts unless asked to mask them', () {
    const line = 'connect user@build.example.com and 192.0.2.10 via 2001:db8::1:5';
    expect(redact(line), line);
    expect(redact(line, maskHosts: true), 'connect [user]@[host] and [ip] via [ip]');
    expect(redact('ping example.org', maskHosts: true), 'ping [host]');
    // Any top-level domain, in the places the log names hosts.
    expect(
      redact('Connecting to db.example.xyz:1348 ... address = box.example.pw, port = 1', maskHosts: true),
      'Connecting to [host]:1348 ... address = [host], port = 1',
    );
    // Stack traces and package ids stay readable.
    const frame = '#0 TerminalState.terminate (package:dartssh2/src/utils/terminal_state.dart:30) io.nuc134r.nux';
    expect(redact(frame, maskHosts: true), frame);
    expect(redact('stop com.example.app due to x', maskHosts: true), 'stop [host] due to x');
    expect(redact('fe80::1 and 2001:db8:0:0:0:0:0:1', maskHosts: true), '[ip] and [ip]');
    expect(redact('at 2026-11-02T22:15:31.160 took 1:30', maskHosts: true), 'at 2026-11-02T22:15:31.160 took 1:30');
  });

  test('log redacts on write and masks hosts on export', () {
    final log = Log(capacity: 2);
    addTearDown(log.dispose);
    log.i('ssh', 'auth with password=hunter2 to 192.0.2.7');
    expect(log.entries.single.message, 'auth with password=[redacted] to 192.0.2.7');
    expect(log.export(), contains('to [ip]'));
    expect(log.export(includeHosts: true), contains('to 192.0.2.7'));
    log
      ..i('a', '1')
      ..i('a', '2');
    expect(log.entries.map((e) => e.message), ['1', '2']);
  });
}
