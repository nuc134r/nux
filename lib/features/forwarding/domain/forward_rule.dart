import '../../../core/db/database.dart';

enum ForwardKind {
  /// `ssh -L`: a port on this device reaches a host:port as seen from the host.
  local,

  /// `ssh -R`: a port on the host reaches a host:port as seen from this device.
  remote,

  /// `ssh -D`: a SOCKS5 proxy on this device; apps choose where to go through the host.
  dynamic;

  /// Rules made before 0.8 (`zerotierTcp`, `zerotierUdp`) are local ones (the v6 migration converts them).
  static ForwardKind parse(String s) => values.asNameMap()[s] ?? local;
}

const _loopback = {'localhost', '127.0.0.1', '::1', ''};

/// Whether [host] means "the machine itself" (where the rule's destination is the host, or this device).
bool isLoopback(String host) => _loopback.contains(host.trim().toLowerCase());

/// How a rule reaches its host.
enum ForwardRoute {
  /// Through an SSH session (TCP only).
  ssh,

  /// Straight to the host's ZeroTier address, no SSH: TCP and UDP.
  zeroTier,
}

extension ForwardRuleX on ForwardRule {
  ForwardKind get forwardKind => ForwardKind.parse(kind);

  /// Listens on every interface (other devices on the network can connect).
  bool get shared => !isLoopback(bindHost);

  /// Direct over ZeroTier when the host is on a ZeroTier network and the rule just reaches a port of
  /// the host itself; anything else (another destination, remote, SOCKS) needs SSH.
  ForwardRoute routeVia(Connection? host) =>
      host?.zerotierNetwork != null && forwardKind == ForwardKind.local && isLoopback(targetHost)
          ? ForwardRoute.zeroTier
          : ForwardRoute.ssh;

  /// `8080 → 8020`, `::1234 → otherserver:8020`, `1234 ← 8020`, `SOCKS 1080`.
  String describe() {
    final bind = shared ? '::$bindPort' : '$bindPort';
    final target = isLoopback(targetHost) ? '$targetPort' : '$targetHost:$targetPort';
    return switch (forwardKind) {
      ForwardKind.local => '$bind → $target',
      ForwardKind.remote => '$bind ← $target',
      ForwardKind.dynamic => 'SOCKS $bind',
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
    if (!(o.tcp && rule.tcp) && !(o.udp && rule.udp)) continue; // TCP and UDP ports are separate
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
