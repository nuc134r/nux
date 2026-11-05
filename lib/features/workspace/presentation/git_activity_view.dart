import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/activity/activity_center.dart';
import '../../../l10n/l10n.dart';
import '../domain/git_activity.dart';

/// Under the branch line of the workspace card: the git command running now with its progress and latest
/// line; then for a moment how it ended (a failure stays until looked at). Tap for the whole output.
class GitActivityStrip extends StatefulWidget {
  const GitActivityStrip({super.key, required this.activity});

  final GitActivity activity;

  @override
  State<GitActivityStrip> createState() => _GitActivityStripState();
}

class _GitActivityStripState extends State<GitActivityStrip> {
  /// The finished run still shown; cleared a few seconds after a success, or once a failure was opened.
  GitRun? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.activity.addListener(_changed);
  }

  @override
  void dispose() {
    widget.activity.removeListener(_changed);
    _hide?.cancel();
    super.dispose();
  }

  void _changed() {
    final last = widget.activity.last;
    if (last != null && !last.running && _shown != last) {
      _shown = last;
      _hide?.cancel();
      if (last.ok) _hide = Timer(const Duration(seconds: 6), () => mounted ? setState(() => _shown = null) : null);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = widget.activity.current ?? _shown;
    final small = theme.textTheme.bodySmall;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: run == null
          ? const SizedBox(width: double.infinity)
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (!run.running && !run.ok) setState(() => _shown = null);
                showGitOutput(context, widget.activity, run);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (run.running)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: run.progress, minHeight: 3),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (!run.running)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              run.ok ? Icons.check_circle : Icons.error,
                              size: 16,
                              color: run.ok ? Colors.green : scheme.error,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            run.command,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          run.running ? l10n.gitOutputShow : _seconds(run.duration),
                          style: small?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                    if (run.lastLine.isNotEmpty)
                      Text(
                        run.lastLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small?.copyWith(color: !run.running && !run.ok ? scheme.error : scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

String _seconds(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

/// The output of [run] (by default the latest), live while it runs, and the earlier commands to look at.
Future<void> showGitOutput(BuildContext context, GitActivity activity, [GitRun? run]) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _GitOutputSheet(activity: activity, initial: run ?? activity.last),
);

class _GitOutputSheet extends StatefulWidget {
  const _GitOutputSheet({required this.activity, required this.initial});

  final GitActivity activity;
  final GitRun? initial;

  @override
  State<_GitOutputSheet> createState() => _GitOutputSheetState();
}

class _GitOutputSheetState extends State<_GitOutputSheet> {
  late GitRun? _run = widget.initial;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest lines in view while the command runs (unless scrolled up).
  void _follow() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels < 80) _scroll.jumpTo(p.maxScrollExtent);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures, height: 1.35);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: ListenableBuilder(
        listenable: widget.activity,
        builder: (context, _) {
          final runs = widget.activity.runs.reversed.toList();
          final run = _run;
          if (run?.running ?? false) _follow();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.gitOutput, style: theme.textTheme.titleLarge)),
                    if (run != null && run.running && run.cancel != null)
                      TextButton(onPressed: () => widget.activity.cancel(run), child: Text(l10n.cancel)),
                    if (run != null)
                      IconButton(
                        tooltip: l10n.copy,
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(ClipboardData(text: '\$ ${run.command}\n${run.output}')),
                      ),
                  ],
                ),
              ),
              if (run == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.gitOutputEmpty, textAlign: TextAlign.center),
                )
              else ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('\$ ${run.command}', style: mono?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        run.running
                            ? _seconds(run.duration)
                            : run.cancelled
                            ? l10n.gitCancelled
                            : run.ok
                            ? _seconds(run.duration)
                            : l10n.gitExitCode(run.exitCode ?? -1),
                        style: mono?.copyWith(color: !run.running && !run.ok ? scheme.error : scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (run.running) LinearProgressIndicator(value: run.progress, minHeight: 2),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          run.output.trimRight().isEmpty
                              ? (run.running ? '…' : l10n.gitNoOutput)
                              : run.output.trimRight(),
                          style: mono,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // Earlier commands: tap one to see its output.
              if (runs.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(l10n.gitEarlier, style: theme.textTheme.titleSmall),
                ),
                SizedBox(
                  height: 132,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final r in runs)
                        ListTile(
                          dense: true,
                          selected: identical(r, run),
                          leading: Icon(
                            r.running ? Icons.hourglass_top : (r.ok ? Icons.check : Icons.close),
                            size: 18,
                            color: r.running ? null : (r.ok ? Colors.green : scheme.error),
                          ),
                          title: Text(r.command, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono),
                          trailing: Text(
                            TimeOfDay.fromDateTime(r.started).format(context),
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => setState(() => _run = r),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Reports [activity]'s commands to the Activity center: fetch, pull, push and clone as operations (with
/// progress and Cancel), other commands only when they fail. Returns [activity].
GitActivity reportGitActivity(GitActivity activity, ActivityCenter center, String workspace) {
  final entries = Expando<ActivityEntry>();
  final seen = Expando<bool>();
  const long = {'fetch', 'pull', 'push', 'clone'};
  activity.addListener(() {
    for (final run in activity.runs) {
      final entry = entries[run];
      if (entry != null) {
        if (run.running) {
          center.update(entry, progress: run.progress, subtitle: run.lastLine.isEmpty ? null : run.lastLine);
        } else if (entry.running) {
          final state = run.cancelled
              ? ActivityState.cancelled
              : run.ok
              ? ActivityState.done
              : ActivityState.failed;
          center.finish(entry, state, subtitle: run.lastLine, unread: state == ActivityState.failed);
        }
        continue;
      }
      if (seen[run] == true) continue;
      final verb = run.command.split(' ').skip(1).firstWhere((w) => !w.startsWith('-'), orElse: () => '');
      if (long.contains(verb)) {
        entries[run] = center.start(
          ActivitySource.git,
          run.command,
          subtitle: workspace,
          cancel: run.cancel == null ? null : () => activity.cancel(run),
          open: (context) => showGitOutput(context, activity, run),
        );
        continue;
      }
      if (run.running) continue;
      seen[run] = true;
      if (!run.ok && !run.cancelled) {
        center.event(
          ActivitySource.git,
          run.command,
          subtitle: run.lastLine,
          state: ActivityState.failed,
          open: (context) => showGitOutput(context, activity, run),
        );
      }
    }
  });
  return activity;
}
