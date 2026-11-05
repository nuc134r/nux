import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/log/log.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart' show formatSize;
import 'settings_screen.dart' show shareLog;

enum _Level { all, warnings, errors }

/// The app log: how much space it takes, the latest lines (from earlier launches too), Share and Clear.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  _Level _level = _Level.all;

  /// Lines shown: the newest ones.
  static const _shown = 1500;

  Future<void> _clear() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearLogTitle),
        content: Text(l10n.clearLogBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.clear)),
        ],
      ),
    );
    if (ok == true) ref.read(logProvider).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(logProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.logTitle)),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          // An entry starts with its time; continuation lines (stack traces) belong to the one above.
          final entries = <String>[];
          for (final line in log.read().split('\n')) {
            if (line.isEmpty) continue;
            if (entries.isEmpty || RegExp(r'^(\d{4}-\d\d-\d\dT|--- )').hasMatch(line)) {
              entries.add(line);
            } else {
              entries[entries.length - 1] += '\n$line';
            }
          }
          bool keep(String e) => switch (_level) {
            _Level.all => true,
            _Level.warnings => e.contains(' WARNING [') || e.contains(' ERROR ['),
            _Level.errors => e.contains(' ERROR ['),
          };
          final shown = entries.where(keep).toList().reversed.take(_shown).toList();
          final mono = theme.textTheme.bodySmall?.copyWith(
            fontFamily: monoFont,
            fontFeatures: noLigatures,
            height: 1.35,
          );
          return Column(
            children: [
              Island(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: Text(
                      log.maxBytesOnDisk == 0
                          ? l10n.logInMemory
                          : l10n.logSize(formatSize(log.bytesOnDisk), formatSize(log.maxBytesOnDisk)),
                    ),
                    subtitle: Text(l10n.logHint),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            icon: const Icon(Icons.share_outlined),
                            label: Text(l10n.shareLog),
                            onPressed: () => shareLog(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.clearLog),
                            onPressed: entries.isEmpty ? null : _clear,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<_Level>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: _Level.all, label: Text(l10n.logAll)),
                    ButtonSegment(value: _Level.warnings, label: Text(l10n.logWarnings)),
                    ButtonSegment(value: _Level.errors, label: Text(l10n.logErrors)),
                  ],
                  selected: {_level},
                  onSelectionChanged: (v) => setState(() => _level = v.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: shown.isEmpty
                    ? Center(child: Text(l10n.logEmpty))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
                        itemBuilder: (context, i) {
                          final e = shown[i];
                          final color = e.contains(' ERROR [')
                              ? scheme.error
                              : e.contains(' WARNING [')
                              ? Colors.amber.shade800
                              : e.startsWith('---')
                              ? scheme.primary
                              : scheme.onSurface;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SelectableText(e, style: mono?.copyWith(color: color)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
