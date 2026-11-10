import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart' show AddBar;
import '../../../l10n/l10n.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/snippets.dart';

String snippetPresetName(AppLocalizations l10n, String id) => switch (id) {
  'disk' => l10n.snippetDisk,
  'dirs' => l10n.snippetDirs,
  'files' => l10n.snippetFiles,
  'mem' => l10n.snippetMem,
  'cpu' => l10n.snippetCpu,
  'free' => l10n.snippetFree,
  'uptime' => l10n.snippetUptime,
  'ports' => l10n.snippetPorts,
  'log' => l10n.snippetLog,
  'failed' => l10n.snippetFailed,
  'docker' => l10n.snippetDocker,
  'ip' => l10n.snippetIp,
  _ => id,
};

/// The saved snippets, or the presets (in the app's language) while none are saved.
List<Snippet> snippetsOf(AppLocalizations l10n, AppSettingsState? settings) =>
    decodeSnippets(settings?.values[SettingKeys.terminalSnippets]) ??
    [for (final (id, command) in snippetPresets) Snippet(snippetPresetName(l10n, id), command)];

Future<void> _save(WidgetRef ref, List<Snippet> snippets) =>
    ref.read(settingsRepositoryProvider).set(SettingKeys.terminalSnippets, encodeSnippets(snippets));

/// The snippets as a sheet over a terminal: a tap runs one ([send] with Enter), a long press types it
/// without running, for editing first.
Future<void> showSnippetsSheet(BuildContext context, {required void Function(String text) send}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        final snippets = snippetsOf(l10n, ref.watch(appSettingsProvider).value);
        void pick(Snippet s, {required bool run}) {
          Navigator.pop(context);
          send(run ? '${s.command}\r' : s.command);
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .9,
          builder: (context, scroll) => SafeArea(
            child: ListView(
              controller: scroll,
              children: [
                ListTile(
                  title: Text(l10n.snippets, style: theme.textTheme.titleMedium),
                  subtitle: Text(l10n.snippetsHint),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push(Routes.snippets);
                    },
                    child: Text(l10n.edit),
                  ),
                ),
                if (snippets.isEmpty) ListTile(title: Text(l10n.snippetsEmpty)),
                for (final s in snippets)
                  ListTile(
                    leading: const Icon(Icons.play_arrow_outlined),
                    title: Text(s.name),
                    subtitle: Text(
                      s.command,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures),
                    ),
                    onTap: () => pick(s, run: true),
                    onLongPress: () => pick(s, run: false),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Settings → Snippets: add, edit, reorder (drag), delete, or go back to the presets.
class SnippetsScreen extends ConsumerWidget {
  const SnippetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final snippets = snippetsOf(l10n, settings);
    final custom = settings?.values[SettingKeys.terminalSnippets] != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snippets),
        actions: [
          NuxMenuButton(
            tooltip: l10n.more,
            items: (context) => [
              NuxMenuAction(
                icon: Icons.restore,
                label: l10n.resetSnippets,
                enabled: custom,
                onSelected: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.resetSnippets),
                      content: Text(l10n.resetSnippetsQuestion),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.resetSnippets)),
                      ],
                    ),
                  );
                  if (ok == true) await ref.read(settingsRepositoryProvider).set(SettingKeys.terminalSnippets, null);
                },
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AddBar(
        label: l10n.addSnippet,
        onPressed: () async {
          final added = await _editSnippet(context, null);
          if (added != null) await _save(ref, [...snippets, added]);
        },
      ),
      body: snippets.isEmpty
          ? Center(child: Text(l10n.snippetsEmpty))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: snippets.length,
              onReorderItem: (from, to) {
                final list = [...snippets];
                list.insert(to, list.removeAt(from));
                _save(ref, list);
              },
              itemBuilder: (context, i) {
                final s = snippets[i];
                return ListTile(
                  key: ValueKey('$i ${s.name}'),
                  title: Text(s.name),
                  subtitle: Text(
                    s.command,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures),
                  ),
                  onTap: () async {
                    final edited = await _editSnippet(context, s);
                    if (edited == null) return;
                    final list = [...snippets];
                    if (identical(edited, _deleted)) {
                      list.removeAt(i);
                    } else {
                      list[i] = edited;
                    }
                    await _save(ref, list);
                  },
                );
              },
            ),
    );
  }
}

/// Returned by the editor when the snippet was deleted.
const _deleted = Snippet('', '');

/// Name and command; null when cancelled, [_deleted] when deleted.
Future<Snippet?> _editSnippet(BuildContext context, Snippet? snippet) {
  final l10n = context.l10n;
  final name = TextEditingController(text: snippet?.name);
  final command = TextEditingController(text: snippet?.command);
  return showDialog<Snippet>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final valid = command.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(snippet == null ? l10n.addSnippet : l10n.editSnippet),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: snippet == null,
                  decoration: InputDecoration(labelText: l10n.snippetName),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: command,
                  minLines: 2,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures),
                  decoration: InputDecoration(labelText: l10n.snippetCommand),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            if (snippet != null)
              TextButton(onPressed: () => Navigator.pop(context, _deleted), child: Text(l10n.delete)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: valid
                  ? () {
                      final c = command.text.trimRight();
                      final n = name.text.trim();
                      Navigator.pop(context, Snippet(n.isEmpty ? c.split('\n').first : n, c));
                    }
                  : null,
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}
