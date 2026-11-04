import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../app/theme.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../data/tab_factory.dart';
import '../data/workspace.dart';
import '../data/workspace_access.dart';
import '../domain/workspace_search.dart';
import 'workspace_drawer.dart';

/// Finds a file of the workspace by a few letters of its name and opens it.
Future<void> showQuickOpen(BuildContext context, Workspace ws) => showDialog<void>(
  context: context,
  builder: (_) => Dialog.fullscreen(child: _QuickOpen(ws)),
);

/// Searches the text of the workspace's files and opens a result at its line.
Future<void> showSearchInFiles(BuildContext context, Workspace ws) => showDialog<void>(
  context: context,
  builder: (_) => Dialog.fullscreen(child: _SearchInFiles(ws)),
);

void _open(BuildContext context, WidgetRef ref, Workspace ws, String relative, {int? line}) {
  ref.read(workspaceDrawerStateProvider).lastOpened[ws.id] = posix.join(ws.rootPath, relative);
  Navigator.of(context).pop();
  ref
      .read(workspaceProvider)
      .open(ref.read(tabFactoryProvider).viewer(ws.connectionId, posix.join(ws.rootPath, relative), line: line));
}

/// Runs [command] on the workspace's host.
Future<CommandResult> _run(WidgetRef ref, Workspace ws, String command) async {
  final access = await ref.read(workspaceOpenerProvider)(ws.connectionId);
  try {
    return await access.runner.run(command);
  } finally {
    access.release();
  }
}

/// The search field in the app bar, with Back.
class _SearchBar extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBar({required this.controller, required this.hint, this.onSubmitted, this.busy = false});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final bool busy;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: TextField(
        controller: controller,
        autofocus: true,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: busy ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
      ),
    );
  }
}

class _QuickOpen extends ConsumerStatefulWidget {
  const _QuickOpen(this.ws);

  final Workspace ws;

  @override
  ConsumerState<_QuickOpen> createState() => _QuickOpenState();
}

/// The file list of each workspace from the last Quick open: shown at once next time while a fresh one
/// loads (listing a big project over SSH takes a while).
final _fileListCache = <String, List<String>>{};

/// Above this many files, matching runs in a background isolate so typing stays smooth.
const _isolateAbove = 4000;

List<String> _filterJob((String, List<String>) job) => fuzzyFilter(job.$1, job.$2);

class _QuickOpenState extends ConsumerState<_QuickOpen> {
  final _query = TextEditingController();
  List<String>? _files;
  List<String> _matches = const [];
  Object? _error;
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _files = _fileListCache[widget.ws.id];
    if (_files != null) _filter();
    _query.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 90), _filter);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _run(ref, widget.ws, listFilesCommand(widget.ws.rootPath));
      // Splitting tens of thousands of lines is done off the UI thread too.
      final files = result.stdout.length > 200000 ? await compute(parseFileList, result) : parseFileList(result);
      _fileListCache[widget.ws.id] = files;
      if (!mounted) return;
      _files = files;
      await _filter();
    } catch (e) {
      if (mounted && _files == null) setState(() => _error = e);
    }
  }

  /// Matches the query against the files (in an isolate for big projects); stale results are dropped.
  Future<void> _filter() async {
    final files = _files;
    if (files == null) return;
    final generation = ++_generation;
    final query = _query.text;
    final matches = query.trim().isEmpty
        ? files.take(100).toList()
        : files.length > _isolateAbove
        ? await compute(_filterJob, (query, files))
        : fuzzyFilter(query, files);
    if (mounted && generation == _generation) setState(() => _matches = matches);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final files = _files;
    final matches = _matches;
    return Scaffold(
      appBar: _SearchBar(
        controller: _query,
        hint: l10n.quickOpenHint,
        busy: files == null && _error == null,
        onSubmitted: (_) {
          if (matches.isNotEmpty) _open(context, ref, widget.ws, matches.first);
        },
      ),
      body: _error != null
          ? _Message(l10n.errorGeneric('$_error'), error: true)
          : files != null && matches.isEmpty
          ? _Message(l10n.nothingFound)
          : ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final path = matches[i];
                final dir = posix.dirname(path);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(posix.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: dir == '.'
                      ? null
                      : Text(
                          dir,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                  onTap: () => _open(context, ref, widget.ws, path),
                );
              },
            ),
    );
  }
}

class _SearchInFiles extends ConsumerStatefulWidget {
  const _SearchInFiles(this.ws);

  final Workspace ws;

  @override
  ConsumerState<_SearchInFiles> createState() => _SearchInFilesState();
}

class _SearchInFilesState extends ConsumerState<_SearchInFiles> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<SearchHit>? _hits;
  String _searched = '';
  bool _busy = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      _debounce?.cancel();
      if (_query.text.trim().length >= 2) _debounce = Timer(const Duration(milliseconds: 450), _search);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text;
    if (q.trim().isEmpty || q == _searched) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hits = parseSearch(await _run(ref, widget.ws, searchCommand(widget.ws.rootPath, q)));
      if (!mounted || generation != _generation) return;
      setState(() {
        _hits = hits;
        _searched = q;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hits = _hits;
    // Results grouped by file, in the order they came.
    final rows = <Object>[];
    String? file;
    var files = 0;
    for (final h in hits ?? const <SearchHit>[]) {
      if (h.path != file) {
        file = h.path;
        files++;
        rows.add(h.path);
      }
      rows.add(h);
    }
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures);
    return Scaffold(
      appBar: _SearchBar(
        controller: _query,
        hint: l10n.searchInFilesHint,
        busy: _busy,
        onSubmitted: (_) {
          _searched = '';
          _search();
        },
      ),
      body: _error != null
          ? _Message(l10n.errorGeneric('$_error'), error: true)
          : hits == null
          ? const SizedBox.shrink()
          : hits.isEmpty
          ? _Message(l10n.nothingFound)
          : ListView.builder(
              itemCount: rows.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      l10n.searchMatches(hits.length, l10n.filesCount(files)),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                final row = rows[i - 1];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: posix.basename(row), style: theme.textTheme.titleSmall),
                          if (posix.dirname(row) != '.')
                            TextSpan(
                              text: '  ${posix.dirname(row)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                final h = row as SearchHit;
                return InkWell(
                  onTap: () => _open(context, ref, widget.ws, h.path, line: h.line),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text('${h.line}', style: mono?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: Text.rich(
                            _highlight(h.text.trimLeft(), _searched, mono, scheme),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// [text] with each occurrence of [query] marked (case-insensitively when the query is lower case).
TextSpan _highlight(String text, String query, TextStyle? style, ColorScheme scheme) {
  if (query.isEmpty) return TextSpan(text: text, style: style);
  final ignoreCase = query == query.toLowerCase();
  final hay = ignoreCase ? text.toLowerCase() : text;
  final spans = <TextSpan>[];
  var from = 0;
  while (true) {
    final at = hay.indexOf(query, from);
    if (at < 0) break;
    spans
      ..add(TextSpan(text: text.substring(from, at)))
      ..add(
        TextSpan(
          text: text.substring(at, at + query.length),
          style: TextStyle(backgroundColor: scheme.primaryContainer, color: scheme.onPrimaryContainer),
        ),
      );
    from = at + query.length;
  }
  spans.add(TextSpan(text: text.substring(from)));
  return TextSpan(style: style, children: spans);
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: error ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
    ),
  );
}
