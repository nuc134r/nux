/// Removes secrets from text before it is logged, shown or shared.
///
/// Always removed: private key blocks, `password=`/`passphrase=`/`token=`-style values,
/// Authorization headers, GitHub tokens and URL credentials (`https://user:secret@host`).
/// With [maskHosts] (used when the user shares a log): IPv4/IPv6 addresses, `user@host` and
/// host names are replaced too.
String redact(String text, {bool maskHosts = false}) {
  var out = text
      .replaceAll(_privateKey, '[private key]')
      .replaceAllMapped(_assignment, (m) => '${m[1]}${m[2]}[redacted]')
      .replaceAllMapped(_authorization, (m) => '${m[1]}[redacted]')
      .replaceAll(_githubToken, '[token]')
      .replaceAllMapped(_urlCredentials, (m) => '${m[1]}[redacted]@');
  if (maskHosts) {
    out = out
        .replaceAllMapped(_userAtHost, (m) => '[user]@[host]')
        .replaceAll(_ipv4, '[ip]')
        .replaceAll(_ipv6, '[ip]')
        .replaceAll(_hostName, '[host]')
        .replaceAllMapped(
          _anyHost,
          (m) => _notHosts.contains(m[1]) || m[0]!.startsWith('io.nuc134r') ? m[0]! : '[host]',
        );
  }
  return out;
}

final _privateKey = RegExp(r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?(-----END [A-Z0-9 ]*PRIVATE KEY-----|$)');
final _assignment = RegExp(
  r'''\b(password|passwd|passphrase|pass|secret|token|api[_-]?key)(["']?\s*[:=]\s*["']?)[^\s"',;&]+''',
  caseSensitive: false,
);
final _authorization = RegExp(r'\b(Authorization:\s*(?:Bearer|Basic|token)?\s*)\S+', caseSensitive: false);
final _githubToken = RegExp(r'\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b');
final _urlCredentials = RegExp(r'(\b[a-z][a-z0-9+.-]*://[^\s/:@]+:)[^\s/@]+@', caseSensitive: false);
final _userAtHost = RegExp(
  r'\b[a-z_][a-z0-9_.-]*@[a-z0-9.-]+\.[a-z]{2,}\b|\b[a-z_][a-z0-9_.-]*@\d{1,3}(\.\d{1,3}){3}\b',
  caseSensitive: false,
);
final _ipv4 = RegExp(r'\b(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}\b');
// Full form (7 colons) or compressed with "::"; never a clock time like 22:15:31.
final _ipv6 = RegExp(
  r'\b(?:(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,6}:(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4})*)?)(?![0-9a-f:])',
  caseSensitive: false,
);
final _hostName = RegExp(
  r'\b(?:[a-z0-9-]+\.)+(?:com|net|org|io|dev|local|lan|home|internal|ru|de|uk|app|cloud)\b',
  caseSensitive: false,
);

// Any other lowercase dotted name (a TLD list misses most hosts); stack traces stay readable: their
// class names are capitalised and their files end in an extension listed in [_notHosts].
final _anyHost = RegExp(r'\b(?:[a-z0-9-]+\.)+([a-z]{2,24})\b(?![.(])');
const _notHosts = {
  'dart', 'kt', 'java', 'so', 'js', 'ts', 'json', 'yaml', 'yml', 'txt', 'log', 'md', 'png', 'jpg', 'svg', //
  'html', 'css', 'py', 'sh', 'cc', 'cpp', 'xml', 'gradle', 'apk', 'zip', 'gz', 'tar', 'lock', 'toml', 'ini',
  'conf', 'pem', 'pub', 'key', 'arb', 'db', 'sqlite', 'tmp', 'bak', 'csv', 'pdf', 'oat', 'odex', 'vdex', 'art',
  'jar', 'dex',
};
