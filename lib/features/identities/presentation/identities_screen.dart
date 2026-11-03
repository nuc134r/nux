import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/widgets.dart';
import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../data/identity_repository.dart';
import '../domain/key_material.dart';
import 'key_flows.dart';

/// SSH keys: generate, import, open one for details.
class IdentitiesScreen extends ConsumerWidget {
  const IdentitiesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l10n.generateKey),
              subtitle: Text(l10n.generateKeyHint),
              onTap: () => Navigator.pop(context, 'generate'),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(l10n.importFromFile),
              subtitle: Text(l10n.importFormatsHint),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n.importFromClipboard),
              onTap: () => Navigator.pop(context, 'clipboard'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'generate':
        context.push(Routes.newKey);
      case 'file':
        await importKeyFromFile(context, ref);
      case 'clipboard':
        await importKeyFromClipboard(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final keys = ref.watch(identitiesProvider).value ?? const <Identity>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.keys),
      ),
      bottomNavigationBar: AddBar(label: l10n.addKey, onPressed: () => _add(context, ref)),
      body: keys.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.key, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(l10n.noKeysYet, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(l10n.noKeysHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final k in keys)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.key)),
                    title: Text(k.name),
                    subtitle: Text('${keyTypeLabel(k.algorithm)} ${k.bits} · ${k.fingerprint}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (k.encrypted) Tooltip(message: l10n.keyHasPassphrase, child: const Icon(Icons.lock_outline, size: 18)),
                        if (k.requireBiometric) Tooltip(message: l10n.keyNeedsUnlock, child: const Icon(Icons.fingerprint, size: 18)),
                      ],
                    ),
                    onTap: () => context.push(Routes.key(k.id)),
                  ),
              ],
            ),
    );
  }
}
