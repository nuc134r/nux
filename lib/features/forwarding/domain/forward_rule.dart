import '../../../core/db/database.dart';

enum ForwardKind {
  /// `ssh -L`: a port on this device reaches a host:port as seen from the server.
  local,

  /// `ssh -R`: a port on the server reaches a host:port as seen from this device.
  remote,

  /// `ssh -D`: a SOCKS5 proxy on this device; apps choose where to go through the server.
  dynamic,

  /// A TCP port on this device reaches a ZeroTier address (no SSH).
  zerotierTcp,

  /// A UDP port on this device reaches a ZeroTier address (no SSH).
  zerotierUdp;

  bool get overZeroTier => this == zerotierTcp || this == zerotierUdp;

  bool get udp => this == zerotierUdp;

  static ForwardKind parse(String s) => values.asNameMap()[s] ?? local;
}

extension ForwardRuleX on ForwardRule {
  ForwardKind get forwardKind => ForwardKind.parse(kind);

  /// `8080 → db.internal:5432`, `server:9000 → localhost:3000`, `SOCKS 1080`.
  String describe() {
    final bind = bindHost == '127.0.0.1' || bindHost == 'localhost' ? '$bindPort' : '$bindHost:$bindPort';
    return switch (forwardKind) {
      ForwardKind.local => '$bind → $targetHost:$targetPort',
      ForwardKind.remote => '$bind ← $targetHost:$targetPort',
      ForwardKind.dynamic => 'SOCKS $bind',
      ForwardKind.zerotierTcp => '$bind → $targetHost:$targetPort',
      ForwardKind.zerotierUdp => 'UDP $bind → $targetHost:$targetPort',
    };
  }
}

/// Well-known ports, to label rules ("5432 · PostgreSQL").
const wellKnownPorts = {
  21: 'FTP',
  22: 'SSH',
  25: 'SMTP',
  53: 'DNS',
  80: 'HTTP',
  443: 'HTTPS',
  1080: 'SOCKS',
  1433: 'SQL Server',
  1521: 'Oracle',
  2375: 'Docker',
  3000: 'Dev server',
  3306: 'MySQL',
  3389: 'RDP',
  5000: 'Dev server',
  5432: 'PostgreSQL',
  5900: 'VNC',
  5672: 'AMQP',
  6379: 'Redis',
  8000: 'HTTP',
  8080: 'HTTP',
  8443: 'HTTPS',
  9000: 'HTTP',
  9090: 'Prometheus',
  9200: 'Elasticsearch',
  11211: 'Memcached',
  27017: 'MongoDB',
};

/// A rule that would listen on the same address as [rule] on the same side, or null.
///
/// Local and dynamic rules listen on this device (all connections share it); remote rules listen on
/// their own server.
ForwardRule? conflictingRule(ForwardRule rule, Iterable<ForwardRule> others) {
  final kind = rule.forwardKind;
  final onDevice = kind != ForwardKind.remote;
  for (final o in others) {
    if (o.id == rule.id || o.bindPort != rule.bindPort) continue;
    if (o.forwardKind.udp != kind.udp) continue; // TCP and UDP ports are separate
    final otherOnDevice = o.forwardKind != ForwardKind.remote;
    if (onDevice != otherOnDevice) continue;
    if (!onDevice && o.connectionId != rule.connectionId) continue;
    if (_overlap(o.bindHost, rule.bindHost)) return o;
  }
  return null;
}

bool _overlap(String a, String b) {
  const any = {'0.0.0.0', '::', '*', ''};
  const loopback = {'127.0.0.1', 'localhost', '::1'};
  if (any.contains(a) || any.contains(b)) return true;
  if (loopback.contains(a) && loopback.contains(b)) return true;
  return a.toLowerCase() == b.toLowerCase();
}
