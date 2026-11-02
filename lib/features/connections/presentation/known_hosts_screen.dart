import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/known_hosts_repository.dart';

/// Server keys the user trusted. Forgetting one means the next connection asks again.
class KnownHostsScreen extends ConsumerWidget {
  const KnownHostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hosts = ref.watch(knownHostsProvider).value ?? const <KnownHost>[];
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.knownHosts)),
      body: hosts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.knownHostsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(l10n.knownHostsHint, style: Theme.of(context).textTheme.bodySmall),
                ),
                for (final h in hosts)
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(h.port == 22 ? h.host : '${h.host}:${h.port}'),
                    subtitle: Text(
                      '${h.keyType}\n${h.fingerprint}\n${l10n.lastSeen(h.lastSeenAt == null ? '—' : date.format(h.lastSeenAt!))}',
                      style: const TextStyle(fontFamily: monoFont, fontSize: 12, fontFeatures: noLigatures),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: l10n.forget,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.forgetHostTitle(h.host)),
                            content: Text(l10n.forgetHostBody),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.forget)),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(knownHostsRepositoryProvider).delete(h.id);
                          if (context.mounted) showSnack(context, l10n.forgotten(h.host));
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
