import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../identities/data/identity_repository.dart';
import '../../workspace/data/tab_factory.dart';
import '../../workspace/data/workspace.dart';
import '../data/connection_repository.dart';
import '../domain/host_key_check.dart';

/// Opens a terminal tab on [connectionId].
void openTerminal(WidgetRef ref, String connectionId) =>
    ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).terminal(connectionId));

/// Opens a file browser tab on [connectionId] (in the home folder).
void openFiles(WidgetRef ref, String connectionId) =>
    ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).files(connectionId));

/// Asks for `user@host:port`, saves it as a connection (offering every key) and opens a terminal.
Future<void> quickConnect(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final text = TextEditingController();
  final target = await showDialog<QuickTarget>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final parsed = QuickTarget.tryParse(text.text);
        void submit() {
          if (parsed?.username != null) Navigator.pop(context, parsed);
        }

        return AlertDialog(
          title: Text(l10n.quickConnect),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: text,
                autofocus: true,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(hintText: 'user@host:22', helperText: l10n.quickConnectHint),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            FilledButton(onPressed: parsed?.username == null ? null : submit, child: Text(l10n.connect)),
          ],
        );
      },
    ),
  );
  text.dispose();
  if (target == null) return;
  final keys = await ref.read(identityRepositoryProvider).all();
  final now = DateTime.now();
  final id = await ref.read(connectionRepositoryProvider).save(ConnectionsCompanion.insert(
        name: target.host,
        host: target.host,
        port: Value(target.port ?? 22),
        username: target.username!,
        identityIds: Value(encodeIdentityIds([for (final k in keys) k.id])),
        createdAt: now,
        updatedAt: now,
      ));
  openTerminal(ref, id);
}

/// Deletes a connection after confirmation (mentions connections that jump through it).
Future<bool> deleteConnection(BuildContext context, WidgetRef ref, Connection c) async {
  final l10n = context.l10n;
  final repo = ref.read(connectionRepositoryProvider);
  final jumpers = await repo.jumpingThrough(c.id);
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteConnectionTitle(c.name)),
      content: Text(jumpers.isEmpty ? l10n.deleteConnectionBody : l10n.deleteConnectionJumpers(jumpers.map((j) => j.name).join(', '))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
      ],
    ),
  );
  if (ok != true) return false;
  await repo.delete(c.id);
  if (context.mounted) showSnack(context, l10n.deleted(c.name));
  return true;
}

/// Copies a connection (without its saved password) and opens the copy in the editor.
Future<void> duplicateConnection(BuildContext context, WidgetRef ref, Connection c) async {
  final l10n = context.l10n;
  final now = DateTime.now();
  final id = await ref.read(connectionRepositoryProvider).save(c
      .toCompanion(true)
      .copyWith(
        id: const Value.absent(),
        name: Value(l10n.copyOf(c.name)),
        savePassword: const Value(false),
        lastUsedAt: const Value(null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
  if (context.mounted) context.push(Routes.connection(id));
}
