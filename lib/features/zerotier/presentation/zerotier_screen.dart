import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/zerotier_service.dart';

/// The ZeroTier node: on/off, its id (to authorize it), and the joined networks.
class ZeroTierScreen extends ConsumerWidget {
  const ZeroTierScreen({super.key});

  Future<void> _join(BuildContext context, ZeroTierService service) async {
    final l10n = context.l10n;
    final text = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.joinNetwork),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 16,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.zerotierNetwork, hintText: '8056c2e21c000001'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: Text(l10n.join)),
        ],
      ),
    );
    text.dispose();
    if (id == null) return;
    final parsed = parseNetworkId(id);
    if (parsed == null) {
      if (context.mounted) showSnack(context, l10n.invalidNetworkId);
      return;
    }
    await service.join(id.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final service = ref.watch(zeroTierServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        final nodeId = state?.nodeId;
        final status = !service.running
            ? (service.starting ? l10n.ztStarting : l10n.ztStopped)
            : (state?.online ?? false)
            ? l10n.ztOnline
            : l10n.ztOffline;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ZeroTier'),
            actions: [
              NuxMenuButton(
                tooltip: l10n.more,
                items: (context) => [
                  NuxMenuAction(
                    icon: Icons.info_outline,
                    label: l10n.ztNodeDetails,
                    onSelected: () => context.push(Routes.zerotierNode),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: AddBar(label: l10n.joinNetwork, onPressed: () => _join(context, service)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Island(
                children: [
                  SwitchListTile(
                    secondary: Icon(Icons.lan_outlined, color: (state?.online ?? false) ? Colors.green : null),
                    title: Text(l10n.ztNode),
                    subtitle: Text(status),
                    value: service.running || service.starting,
                    // Off while the node starts or stops: libzt takes one change at a time.
                    onChanged: service.busy
                        ? null
                        : (v) async {
                            try {
                              v ? await service.start() : await service.stop();
                            } catch (e) {
                              if (context.mounted) showSnack(context, l10n.errorGeneric('$e'));
                            }
                          },
                  ),
                  if (nodeId != null)
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(
                        nodeId,
                        style: const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures),
                      ),
                      subtitle: Text(l10n.ztNodeIdHint),
                      onTap: () => context.push(Routes.zerotierNode),
                      titleAlignment: ListTileTitleAlignment.center,
                      // Copying the id is in the details (a tap on it there).
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.power_settings_new),
                    title: Text(l10n.ztAutoStart),
                    value: service.autoStart,
                    onChanged: service.setAutoStart,
                  ),
                ],
              ),
              Island(
                title: l10n.ztNetworks,
                children: [
                  if (service.networks.isEmpty)
                    ListTile(title: Text(l10n.ztNoNetworks), subtitle: Text(l10n.ztNoNetworksHint)),
                  for (final id in service.networks)
                    _NetworkTile(
                      id: id,
                      state: service.network(id),
                      running: service.running,
                      onTap: () => context.push(Routes.zerotierNetwork(id)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.ztAbout, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What a network's row says: its addresses once it is ready, else what it waits for.
String ztNetworkStatus(AppLocalizations l10n, ZeroTierNetworkState? s, {required bool running}) => !running
    ? l10n.ztNetworkIdle
    : switch (s?.status) {
        ZeroTierNetworkStatus.ok when s!.addresses.isNotEmpty => s.addresses.join(', '),
        ZeroTierNetworkStatus.ok => l10n.ztWaitingAddress,
        ZeroTierNetworkStatus.accessDenied => l10n.ztAccessDenied,
        ZeroTierNetworkStatus.notFound => l10n.ztNotFound,
        _ => l10n.ztRequesting,
      };

Icon ztNetworkIcon(BuildContext context, ZeroTierNetworkState? s) => Icon(
  Icons.hub_outlined,
  color: s?.ready ?? false
      ? Colors.green
      : (s?.status == ZeroTierNetworkStatus.accessDenied ? Theme.of(context).colorScheme.error : null),
);

/// Asks, then leaves; true when it left.
Future<bool> confirmLeaveNetwork(BuildContext context, ZeroTierService service, String id) async {
  final l10n = context.l10n;
  final name = service.network(id)?.name;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.leaveNetworkTitle(name ?? id)),
      content: Text(l10n.leaveNetworkBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.leave)),
      ],
    ),
  );
  if (ok != true) return false;
  await service.leave(id);
  return true;
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.id,
    required this.state,
    required this.running,
    required this.onTap,
  });

  final String id;
  final ZeroTierNetworkState? state;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = state;
    final status = ztNetworkStatus(l10n, s, running: running);
    return ListTile(
      onTap: onTap,
      leading: ztNetworkIcon(context, s),
      title: Text(
        s?.name ?? id,
        style: s?.name == null ? const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures) : null,
      ),
      subtitle: Text([if (s?.name != null) id, status].join('\n')),
      isThreeLine: s?.name != null,
      // Three-line tiles put the icons at the top by default; the status may also wrap.
      titleAlignment: ListTileTitleAlignment.center,
      // Copy and Leave are in the network's details.
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
