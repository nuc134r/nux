import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../widgets/nux_menu.dart';
import 'activity_center.dart';

IconData _icon(ActivitySource s) => switch (s) {
  ActivitySource.git => Icons.call_split,
  ActivitySource.transfer => Icons.swap_vert,
  ActivitySource.forwarding => Icons.alt_route,
  ActivitySource.update => Icons.system_update_alt,
  ActivitySource.ssh => Icons.terminal,
  ActivitySource.other => Icons.notifications_none,
};

/// On the tab count: a small spinner while something runs, a dot when something new happened (red when
/// something failed).
class ActivityBadge extends ConsumerWidget {
  const ActivityBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(activityCenterProvider);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        if (center.running.isNotEmpty) {
          return SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
          );
        }
        if (center.unread == 0) return const SizedBox.shrink();
        final failed = center.entries.take(center.unread).any((e) => e.state == ActivityState.failed);
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: failed ? scheme.error : scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 1.5),
          ),
        );
      },
    );
  }
}

/// "Activity" for a ⋮ menu, with what runs or is new as its hint.
NuxMenuAction activityMenuItem(BuildContext context, ActivityCenter center) {
  final l10n = context.l10n;
  final running = center.running.length;
  return NuxMenuAction(
    icon: Icons.notifications_outlined,
    label: l10n.activity,
    hint: running > 0
        ? l10n.activityRunning(running)
        : center.unread > 0
        ? l10n.activityNew(center.unread)
        : null,
    onSelected: () => showActivity(context),
  );
}

/// The Activity sheet: what runs now (with progress and Cancel), then what happened, newest first.
Future<void> showActivity(BuildContext context) {
  final center = ProviderScope.containerOf(context, listen: false).read(activityCenterProvider);
  center.markRead();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ActivitySheet(center: center),
  ).whenComplete(center.markRead);
}

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({required this.center});

  final ActivityCenter center;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListenableBuilder(
        listenable: center,
        builder: (context, _) {
          final running = center.running;
          final done = center.entries.where((e) => !e.running).toList();
          Widget header(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.activity, style: theme.textTheme.titleLarge)),
                    if (done.isNotEmpty) TextButton(onPressed: center.clear, child: Text(l10n.clear)),
                  ],
                ),
              ),
              Expanded(
                child: running.isEmpty && done.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.activityEmpty, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          if (running.isNotEmpty) ...[
                            header(l10n.activityNow),
                            for (final e in running) _EntryTile(entry: e, center: center),
                          ],
                          if (done.isNotEmpty) ...[
                            header(l10n.activityEarlier),
                            for (final e in done) _EntryTile(entry: e, center: center),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.center});

  final ActivityEntry entry;
  final ActivityCenter center;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final (badge, color) = switch (e.state) {
      ActivityState.failed => (Icons.error, scheme.error),
      ActivityState.done => (Icons.check_circle, Colors.green),
      ActivityState.cancelled => (Icons.cancel, scheme.onSurfaceVariant),
      _ => (null, null),
    };
    final open = e.open;
    return ListTile(
      onTap: open == null ? null : () => open(context),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_icon(e.source), color: scheme.onSurfaceVariant),
          if (badge != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, shape: BoxShape.circle),
                child: Icon(badge, size: 14, color: color),
              ),
            ),
        ],
      ),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.subtitle case final s? when s.isNotEmpty)
            Text(
              s,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: e.state == ActivityState.failed ? scheme.error : null),
            ),
          if (e.running)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(value: e.progress, minHeight: 3),
            ),
        ],
      ),
      trailing: e.running && e.cancel != null
          ? IconButton(tooltip: l10n.cancel, icon: const Icon(Icons.close), onPressed: e.cancel)
          : e.state == ActivityState.failed && e.retry != null
          ? TextButton(onPressed: e.retry, child: Text(l10n.tryAgain))
          : e.running
          ? null
          : Text(TimeOfDay.fromDateTime(e.ended ?? e.started).format(context), style: theme.textTheme.bodySmall),
    );
  }
}
