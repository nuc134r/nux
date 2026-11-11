import 'package:flutter/material.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// How ZeroTier reaches a peer: directly (at which public address) or relayed through a root server,
/// with libzt's latency. For a host's menu.
class ZeroTierPathBadge extends StatelessWidget {
  const ZeroTierPathBadge({super.key, required this.peer});

  final ZeroTierPeer peer;

  /// `192.0.2.7/9993` → `192.0.2.7:9993`, `2001:db8::1/9993` → `[2001:db8::1]:9993`.
  static String endpoint(String path) {
    final i = path.lastIndexOf('/');
    if (i < 0) return path;
    final ip = path.substring(0, i), port = path.substring(i + 1);
    return ip.contains(':') ? '[$ip]:$port' : '$ip:$port';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final path = peer.paths.where((p) => p.preferred).firstOrNull ?? peer.paths.firstOrNull;
    final direct = path != null;
    final color = direct ? Colors.green : scheme.tertiary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(direct ? Icons.swap_horiz : Icons.cloud_sync_outlined, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    direct ? l10n.ztBadgeDirect : l10n.ztBadgeRelayed,
                    style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (direct)
            Text(
              endpoint(path.address),
              style: theme.textTheme.labelSmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures),
            ),
          if (peer.latency != null)
            Text(
              l10n.ztLatency(peer.latency!),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
