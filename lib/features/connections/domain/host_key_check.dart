/// What to do with the key a server presented, given the keys trusted for that host before.
enum HostKeyStatus {
  /// Same type and fingerprint as a trusted key.
  trusted,

  /// Nothing trusted for this host yet: ask (trust on first use).
  unknown,

  /// Another key type was trusted for this host, but not this one: ask, mentioning the known key.
  newKeyType,

  /// A different key of a trusted type: possibly an attack. Warn loudly.
  changed,
}

class KnownHostKey {
  const KnownHostKey(this.keyType, this.fingerprint);

  final String keyType;
  final String fingerprint;
}

HostKeyStatus checkHostKey(Iterable<KnownHostKey> known, String keyType, String fingerprint) {
  if (known.isEmpty) return HostKeyStatus.unknown;
  for (final k in known) {
    if (k.keyType == keyType) return k.fingerprint == fingerprint ? HostKeyStatus.trusted : HostKeyStatus.changed;
  }
  return HostKeyStatus.newKeyType;
}

/// `user@host:port`, `host`, `host:2222`, `user@[2001:db8::1]:22` — what people type into a quick-connect box.
class QuickTarget {
  const QuickTarget({required this.host, this.username, this.port});

  final String host;
  final String? username;
  final int? port;

  static QuickTarget? tryParse(String input) {
    final m = RegExp(r'^(?:([^@\s]+)@)?(\[[0-9a-fA-F:.]+\]|[^\s:@\[\]]+)(?::(\d{1,5}))?$').firstMatch(input.trim());
    if (m == null) return null;
    final host = m.group(2)!.replaceAll(RegExp(r'^\[|\]$'), '');
    final port = m.group(3) == null ? null : int.parse(m.group(3)!);
    if (port != null && (port < 1 || port > 65535)) return null;
    return QuickTarget(host: host, username: m.group(1), port: port);
  }
}
