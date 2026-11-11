import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/presentation/connection_actions.dart';
import '../data/zerotier_service.dart';
import 'zerotier_screen.dart';

const _mono = TextStyle(fontFamily: monoFont, fontFeatures: noLigatures);

/// Rebuilds when the service changes, and every two seconds while the node runs: routes, peers and
/// paths are asked from libzt, they are not in the service's state.
class _Live extends ConsumerStatefulWidget {
  const _Live({required this.builder});

  final Widget Function(BuildContext context, ZeroTierService service) builder;

  @override
  ConsumerState<_Live> createState() => _LiveState();
}

class _LiveState extends ConsumerState<_Live> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(zeroTierServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (service.running) {
          _timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
            // Name the members as soon as they show up in traffic.
            service.learnMembers();
            setState(() {});
          });
        } else {
          _timer?.cancel();
          _timer = null;
        }
        return widget.builder(context, service);
      },
    );
  }
}

/// A label and its value; a tap copies the value.
class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.icon, this.mono = false, this.copy = false});

  final String label;
  final String value;
  final IconData? icon;
  final bool mono;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge?.merge(mono ? _mono : null)),
      onTap: copy
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              showSnack(context, context.l10n.copied);
            }
          : null,
    );
  }
}

/// A joined network: status, addresses, routes, and the rest libzt knows.
class ZeroTierNetworkScreen extends StatelessWidget {
  const ZeroTierNetworkScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _Live(
      builder: (context, service) {
        final state = service.network(id);
        final details = service.details(id);
        final running = service.running;
        return Scaffold(
          appBar: AppBar(
            title: Text(state?.name ?? id),
            actions: [
              NuxMenuButton(
                tooltip: l10n.more,
                items: (context) => [
                  NuxMenuAction(
                    icon: Icons.copy,
                    label: l10n.copy,
                    onSelected: () {
                      Clipboard.setData(ClipboardData(text: id));
                      showSnack(context, l10n.copied);
                    },
                  ),
                  NuxMenuAction(
                    icon: Icons.logout,
                    label: l10n.leave,
                    enabled: service.networks.contains(id),
                    onSelected: () async {
                      if (await confirmLeaveNetwork(context, service, id) && context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Island(
                children: [
                  ListTile(
                    leading: ztNetworkIcon(context, state),
                    title: Text(l10n.ztStatus, style: theme.textTheme.bodySmall),
                    subtitle: Text(
                      running && state?.status == ZeroTierNetworkStatus.ok && (state?.addresses.isNotEmpty ?? false)
                          ? l10n.ztOnline
                          : ztNetworkStatus(l10n, state, running: running),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  _Info(l10n.ztNetworkId, id, icon: Icons.tag, mono: true, copy: true),
                  if (details != null && details.type != ZeroTierNetworkType.unknown)
                    _Info(
                      l10n.ztType,
                      details.type == ZeroTierNetworkType.private ? l10n.ztPrivate : l10n.ztPublic,
                      icon: details.type == ZeroTierNetworkType.private ? Icons.lock_outline : Icons.public,
                    ),
                ],
              ),
              if (!running)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.ztDetailsWhenRunning, style: theme.textTheme.bodyMedium),
                )
              else ...[
                Island(
                  title: l10n.ztAddresses,
                  children: [
                    if (details == null || details.addresses.isEmpty) ListTile(title: Text(l10n.ztNoAddresses)),
                    for (final a in details?.addresses ?? const <String>[])
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(a, style: _mono),
                        onTap: () {
                          // The address alone, without the prefix length.
                          Clipboard.setData(ClipboardData(text: a.split('/').first));
                          showSnack(context, l10n.copied);
                        },
                      ),
                  ],
                ),
                Island(
                  title: l10n.ztRoutes,
                  children: [
                    if (details == null || details.routes.isEmpty) ListTile(title: Text(l10n.ztNoRoutes)),
                    for (final r in details?.routes ?? const <ZeroTierRoute>[])
                      ListTile(
                        leading: Icon(r.via == null ? Icons.lan_outlined : Icons.alt_route),
                        title: Text(r.target, style: _mono),
                        subtitle: Text(r.via == null ? l10n.ztRouteDirect : l10n.ztRouteVia(r.via!)),
                      ),
                  ],
                ),
                if (details != null && (details.mac != null || details.mtu != null))
                  Island(
                    children: [
                      if (details.mac != null)
                        _Info(l10n.ztMac, details.mac!, icon: Icons.memory, mono: true, copy: true),
                      if (details.mtu != null) _Info(l10n.ztMtu, '${details.mtu}', icon: Icons.straighten),
                      if (details.broadcast != null)
                        _Info(l10n.ztBroadcast, details.broadcast! ? l10n.ztOn : l10n.ztOff, icon: Icons.cell_tower),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// This node: id, status, port, and the peers it talks to (direct or relayed).
class ZeroTierNodeScreen extends ConsumerWidget {
  const ZeroTierNodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    return _Live(
      builder: (context, service) {
        // Hosts reached over ZeroTier, by the member's ZeroTier address.
        final hosts = <String, List<Connection>>{};
        for (final c in connections) {
          final network = c.zerotierNetwork;
          final address = network == null ? null : service.memberAddress(network, c.host);
          if (address != null) (hosts[address] ??= []).add(c);
        }
        final running = service.running;
        final state = service.state;
        final online = running && (state?.online ?? false);
        final status = !running
            ? (service.starting ? l10n.ztStarting : l10n.ztStopped)
            : online
            ? l10n.ztOnline
            : l10n.ztOffline;
        final nodeId = running ? state?.nodeId : null;
        final port = service.port;
        final guard = service.guardStats();
        final peers = [...service.peers()]
          ..sort((a, b) {
            // Roots first, then hosts by name, then the other members.
            final role = b.role.index.compareTo(a.role.index);
            if (role != 0) return role;
            final na = hosts[a.address]?.first.name, nb = hosts[b.address]?.first.name;
            if ((na == null) != (nb == null)) return na == null ? 1 : -1;
            return na != null ? na.toLowerCase().compareTo(nb!.toLowerCase()) : a.address.compareTo(b.address);
          });
        return Scaffold(
          appBar: AppBar(title: Text(l10n.ztNodeDetails)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Island(
                children: [
                  ListTile(
                    leading: Icon(Icons.lan_outlined, color: online ? Colors.green : null),
                    title: Text(l10n.ztStatus, style: theme.textTheme.bodySmall),
                    subtitle: Text(status, style: theme.textTheme.bodyLarge),
                  ),
                  if (nodeId != null) _Info(l10n.ztNodeId, nodeId, icon: Icons.badge_outlined, mono: true, copy: true),
                  if (port != null) _Info(l10n.ztPort, '$port', icon: Icons.settings_ethernet),
                  if (guard != null)
                    _Info(
                      l10n.ztMemoryGuard,
                      l10n.ztMemoryGuardStats(guard.live, guard.mappedBytes >> 20),
                      icon: Icons.shield_outlined,
                    ),
                ],
              ),
              if (!running)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.ztDetailsWhenRunning, style: theme.textTheme.bodyMedium),
                )
              else
                Island(
                  title: l10n.ztPeers,
                  children: [
                    if (peers.isEmpty) ListTile(title: Text(l10n.ztNoPeers)),
                    for (final p in peers) _PeerTile(p, hosts: hosts[p.address] ?? const []),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PeerTile extends ConsumerWidget {
  const _PeerTile(this.peer, {required this.hosts});

  final ZeroTierPeer peer;

  /// Saved hosts on this member (several when they differ by user or port).
  final List<Connection> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = peer;
    final role = switch (p.role) {
      ZeroTierPeerRole.planet => l10n.ztPeerPlanet,
      ZeroTierPeerRole.moon => l10n.ztPeerMoon,
      _ => l10n.ztPeerLeaf,
    };
    final preferred = p.paths.where((x) => x.preferred).firstOrNull ?? p.paths.firstOrNull;
    final facts = [
      role,
      if (p.latency != null) l10n.ztLatency(p.latency!),
      if (p.version != null) l10n.ztVersion(p.version!),
    ].join(' · ');
    final path = preferred == null ? l10n.ztPeerRelayed : l10n.ztPeerDirect(preferred.address);
    final color = hosts.map((c) => c.color).nonNulls.firstOrNull;
    void copy() {
      Clipboard.setData(ClipboardData(text: p.address));
      showSnack(context, l10n.copied);
    }

    return ListTile(
      leading: Icon(
        p.role == ZeroTierPeerRole.leaf ? (hosts.isEmpty ? Icons.devices_other : Icons.computer) : Icons.dns_outlined,
        color: p.direct ? Colors.green : null,
      ),
      title: hosts.isEmpty
          ? Text(p.address, style: _mono)
          : Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(color: Color(color), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(hosts.map((c) => c.name).toSet().join(', '), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
      subtitle: Text(hosts.isEmpty ? '$facts\n$path' : '${p.address} · $facts\n$path'),
      isThreeLine: true,
      // A host opens a terminal on it (a menu when there are several); other peers copy their address.
      onTap: hosts.isEmpty
          ? copy
          : () => showNuxMenu(
              context,
              beside: true,
              (_) => [
                for (final c in hosts)
                  NuxMenuAction(
                    icon: Icons.terminal,
                    label: hosts.length == 1 ? l10n.openTerminal : '${l10n.openTerminal}: ${c.name}',
                    onSelected: () {
                      openTerminal(ref, c.id);
                      context.go(Routes.home);
                    },
                  ),
                NuxMenuAction(icon: Icons.copy, label: l10n.ztCopyAddress, onSelected: copy),
              ],
            ),
    );
  }
}
