import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../../app/theme.dart';
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
                items: (_) => [
                  NuxMenuAction(icon: Icons.add, label: l10n.joinNetwork, onSelected: () => _join(context, service)),
                ],
              ),
            ],
          ),
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
                    onChanged: (v) async {
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
                      title: Text(nodeId, style: const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures)),
                      subtitle: Text(l10n.ztNodeIdHint),
                      trailing: IconButton(
                        tooltip: l10n.copy,
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: nodeId));
                          showSnack(context, l10n.copied);
                        },
                      ),
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
                    ListTile(
                      title: Text(l10n.ztNoNetworks),
                      subtitle: Text(l10n.ztNoNetworksHint),
                      trailing: FilledButton.tonal(onPressed: () => _join(context, service), child: Text(l10n.join)),
                    ),
                  for (final id in service.networks)
                    _NetworkTile(id: id, state: service.network(id), running: service.running, onLeave: () => service.leave(id)),
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

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({required this.id, required this.state, required this.running, required this.onLeave});

  final String id;
  final ZeroTierNetworkState? state;
  final bool running;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = state;
    final status = !running
        ? l10n.ztNetworkIdle
        : switch (s?.status) {
            ZeroTierNetworkStatus.ok when s!.addresses.isNotEmpty => s.addresses.join(', '),
            ZeroTierNetworkStatus.ok => l10n.ztWaitingAddress,
            ZeroTierNetworkStatus.accessDenied => l10n.ztAccessDenied,
            ZeroTierNetworkStatus.notFound => l10n.ztNotFound,
            _ => l10n.ztRequesting,
          };
    return ListTile(
      leading: Icon(
        Icons.hub_outlined,
        color: s?.ready ?? false ? Colors.green : (s?.status == ZeroTierNetworkStatus.accessDenied ? Theme.of(context).colorScheme.error : null),
      ),
      title: Text(s?.name ?? id, style: s?.name == null ? const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures) : null),
      subtitle: Text([if (s?.name != null) id, status].join('\n')),
      isThreeLine: s?.name != null,
      trailing: IconButton(tooltip: l10n.leave, icon: const Icon(Icons.logout), onPressed: onLeave),
    );
  }
}
