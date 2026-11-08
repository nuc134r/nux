import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart' show formatSize;
import '../domain/inspect.dart';
import 'viewer_tab.dart';

/// What the server tells about a file: an archive's files, a database's tables, or details.
class InspectView extends StatelessWidget {
  const InspectView({super.key, required this.tab, required this.type});

  final ViewerTab tab;
  final InspectType type;

  @override
  Widget build(BuildContext context) => switch (type) {
    InspectType.archive => ArchiveView(tab: tab),
    InspectType.database => DatabaseView(tab: tab),
    _ => DetailsView(tab: tab),
  };
}

/// Why a preview failed, with Show bytes and Try again.
class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.tab, required this.retry});

  final Object error;
  final ViewerTab tab;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (error) {
      MissingToolException(:final tools) => l10n.needsTool(tools.join(', ')),
      _ => l10n.errorGeneric('$error'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(onPressed: tab.showBytesInstead, child: Text(l10n.showBytes)),
                if (error is! MissingToolException) FilledButton.tonal(onPressed: retry, child: Text(l10n.tryAgain)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------

/// An archive's files as folders to walk through; a file opens (unpacked on the server), a long press
/// offers extracting it.
class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key, required this.tab});

  final ViewerTab tab;

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  String _dir = '';
  late Future<ArchiveListing> _listing = widget.tab.listing();

  @override
  void initState() {
    super.initState();
    widget.tab.onExtractAll = () async {
      final listing = await _listing;
      if (mounted) await _extract(listing, null);
    };
  }

  @override
  void dispose() {
    widget.tab.onExtractAll = null;
    super.dispose();
  }

  Future<void> _open(ArchiveListing listing, ArchiveNode node) async {
    try {
      await widget.tab.openFromArchive(listing, node);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorGeneric('$e'));
    }
  }

  Future<void> _extract(ArchiveListing listing, ArchiveNode? node) async {
    final l10n = context.l10n;
    try {
      final dest = await widget.tab.extract(listing, node);
      if (mounted) showSnack(context, l10n.extractedTo(dest));
    } catch (e) {
      if (mounted) showSnack(context, l10n.errorGeneric('$e'));
    }
  }

  Future<void> _actions(ArchiveListing listing, ArchiveNode node) async {
    final l10n = context.l10n;
    final dest = '${widget.tab.extractDestination}/';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(node.isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined),
              title: Text(node.name),
              subtitle: Text(node.path),
            ),
            const Divider(height: 1),
            if (!node.isDir)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(l10n.open),
                onTap: () => Navigator.pop(context, 'open'),
              ),
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: Text(l10n.extractTo(dest)),
              onTap: () => Navigator.pop(context, 'extract'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyPath),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        await _open(listing, node);
      case 'extract':
        await _extract(listing, node);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: node.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<ArchiveListing>(
      future: _listing,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Failure(
            error: snap.error!,
            tab: widget.tab,
            retry: () => setState(() => _listing = widget.tab.listing()),
          );
        }
        final listing = snap.data;
        if (listing == null) return const Center(child: CircularProgressIndicator());
        if (listing.entries.isEmpty) return Center(child: Text(l10n.archiveEmpty));
        final nodes = listing.children(_dir);
        return PopScope(
          // Back goes up a folder first.
          canPop: _dir.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _dir = _parent(_dir));
          },
          child: Column(
            children: [
              Material(
                color: theme.colorScheme.surfaceContainer,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                  title: Text(_dir.isEmpty ? l10n.archiveFiles(listing.fileCount) : '/$_dir'),
                  subtitle: _dir.isEmpty ? null : Text(l10n.archiveFiles(listing.fileCount)),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: nodes.length + (_dir.isEmpty ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (_dir.isNotEmpty && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('..'),
                          onTap: () => setState(() => _dir = _parent(_dir)),
                        );
                      }
                      final node = nodes[i - (_dir.isEmpty ? 0 : 1)];
                      final link = node.entry?.link;
                      return ListTile(
                        leading: Icon(node.isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined),
                        title: Text(node.name),
                        subtitle: link != null
                            ? Text('→ $link', maxLines: 1, overflow: TextOverflow.ellipsis)
                            : node.entry?.modified == null
                            ? null
                            : Text(node.entry!.modified!),
                        trailing: node.size == null || (node.isDir && node.size == 0)
                            ? null
                            : Text(formatSize(node.size!), style: theme.textTheme.bodySmall),
                        onTap: widget.tab.busy
                            ? null
                            : () => node.isDir ? setState(() => _dir = node.path) : _open(listing, node),
                        onLongPress: widget.tab.busy ? null : () => _actions(listing, node),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _parent(String dir) => dir.contains('/') ? dir.substring(0, dir.lastIndexOf('/')) : '';
}

// ---------------------------------------------------------------------------------------------------------

/// A SQLite database's tables and views; one opens as rows, 100 at a time.
class DatabaseView extends StatefulWidget {
  const DatabaseView({super.key, required this.tab});

  final ViewerTab tab;

  @override
  State<DatabaseView> createState() => _DatabaseViewState();
}

class _DatabaseViewState extends State<DatabaseView> {
  static const _page = 100;

  late Future<List<Map<String, Object?>>> _tables = _query(sqliteTablesQuery);
  final _counts = <String, int>{};
  String? _table;
  List<Map<String, Object?>> _rows = [];
  Object? _error;
  bool _loading = false;
  bool _more = false;

  Future<List<Map<String, Object?>>> _query(String sql) async =>
      parseSqliteRows(await widget.tab.runOnHost(sqliteQueryScript(widget.tab.path, sql)));

  Future<void> _count(String table) async {
    if (_counts.containsKey(table)) return;
    _counts[table] = -1;
    try {
      final n = (await _query(sqliteCountQuery(table))).firstOrNull?['n'];
      if (mounted && n is int) setState(() => _counts[table] = n);
    } catch (_) {
      // The count is a nicety; the table still opens.
    }
  }

  Future<void> _open(String table) async {
    setState(() {
      _table = table;
      _rows = [];
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final table = _table;
    if (table == null || _loading) return;
    setState(() => _loading = true);
    try {
      final rows = await _query(sqliteRowsQuery(table, limit: _page, offset: _rows.length));
      if (!mounted || _table != table) return;
      setState(() {
        _rows = [..._rows, ...rows];
        _more = rows.length == _page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = _table;
    if (table != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _table = null);
        },
        child: _rowsView(context, table),
      );
    }
    final l10n = context.l10n;
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _tables,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Failure(
            error: snap.error!,
            tab: widget.tab,
            retry: () => setState(() => _tables = _query(sqliteTablesQuery)),
          );
        }
        final tables = snap.data;
        if (tables == null) return const Center(child: CircularProgressIndicator());
        if (tables.isEmpty) return Center(child: Text(l10n.databaseEmpty));
        return ListView(
          children: [
            ListTile(dense: true, title: Text(l10n.databaseTables(tables.length))),
            for (final t in tables)
              Builder(
                builder: (context) {
                  final name = '${t['name']}';
                  _count(name);
                  final count = _counts[name];
                  return ListTile(
                    leading: Icon(t['type'] == 'view' ? Icons.visibility_outlined : Icons.table_chart_outlined),
                    title: Text(name),
                    subtitle: count == null || count < 0 ? null : Text(l10n.databaseRows(count)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(name),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _rowsView(BuildContext context, String table) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures);
    final columns = _rows.isEmpty ? const <String>[] : _rows.first.keys.toList();
    const cellWidth = 160.0;
    Widget cell(String text, {bool header = false, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        width: cellWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: header ? mono?.copyWith(fontWeight: FontWeight.bold) : mono,
        ),
      ),
    );
    return Column(
      children: [
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: ListTile(
            dense: true,
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _table = null),
            ),
            title: Text(table),
            subtitle: _counts[table] == null || _counts[table]! < 0
                ? null
                : Text(l10n.databaseShown(_rows.length, _counts[table]!)),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _error != null
              ? _Failure(error: _error!, tab: widget.tab, retry: () => _open(table))
              : _rows.isEmpty
              ? Center(child: _loading ? null : Text(l10n.databaseNoRows))
              : Scrollbar(
                  notificationPredicate: (n) => n.depth == 1,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: cellWidth * columns.length,
                      child: ListView.builder(
                        itemCount: _rows.length + 1 + (_more ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == 0) return Row(children: [for (final c in columns) cell(c, header: true)]);
                          if (i > _rows.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: TextButton(onPressed: _loading ? null : _load, child: Text(l10n.loadMoreRows)),
                              ),
                            );
                          }
                          final row = _rows[i - 1];
                          return Row(
                            children: [
                              for (final c in columns)
                                cell(
                                  row[c] == null ? 'NULL' : '${row[c]}',
                                  onTap: () => _showValue(context, c, row[c]),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showValue(BuildContext context, String column, Object? value) {
    final l10n = context.l10n;
    final text = value == null ? 'NULL' : '$value';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(column),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
            },
            child: Text(l10n.copy),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------

/// What the server says about the file, in sections: type, media streams, PDF info and text, picture
/// metadata, a program's header, libraries and readable strings.
class DetailsView extends StatefulWidget {
  const DetailsView({super.key, required this.tab});

  final ViewerTab tab;

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  late Future<List<DetailSection>> _details = widget.tab.fileDetails();

  String _title(AppLocalizations l10n, String kind) => switch (kind) {
    'file' => l10n.detailsFile,
    'media' => l10n.detailsMedia,
    'pdf' => l10n.detailsDocument,
    'pdfText' => l10n.detailsText,
    'metadata' => l10n.detailsMetadata,
    'elf' => l10n.detailsProgram,
    'libraries' => l10n.detailsLibraries,
    'strings' => l10n.detailsStrings,
    _ => kind,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures);
    return FutureBuilder<List<DetailSection>>(
      future: _details,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Failure(
            error: snap.error!,
            tab: widget.tab,
            retry: () => setState(() => _details = widget.tab.fileDetails()),
          );
        }
        final sections = snap.data;
        if (sections == null) return const Center(child: CircularProgressIndicator());
        if (sections.isEmpty) {
          return _Failure(
            error: const MissingToolException(['file', 'ffprobe', 'pdfinfo', 'exiftool', 'readelf', 'strings']),
            tab: widget.tab,
            retry: () {},
          );
        }
        // Long text (strings, a PDF's text) is shown line by line, so thousands of lines scroll smoothly.
        final children = <Widget>[];
        for (final s in sections) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                _title(l10n, s.kind),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          );
          for (final (key, value) in s.pairs) {
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            );
          }
          final text = s.text;
          if (text != null) {
            for (final line in text.split('\n')) {
              children.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(line, style: mono, softWrap: true),
                ),
              );
            }
          }
        }
        children.add(const SizedBox(height: 24));
        return Scrollbar(
          child: ListView.builder(itemCount: children.length, itemBuilder: (context, i) => children[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------

/// An SVG drawn, zoomable; source with ⋮ → Show source.
class SvgView extends StatelessWidget {
  const SvgView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 16,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SvgPicture.string(
            text,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Text(context.l10n.svgUnreadable),
          ),
        ),
      ),
    );
  }
}

/// An HTML page rendered in a web view, without scripts (they could do anything with the page) and
/// without the files it links to (only the page itself is on the phone).
class HtmlView extends StatefulWidget {
  const HtmlView({super.key, required this.text});

  final String text;

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..loadHtmlString(widget.text);
    }
  }

  @override
  void didUpdateWidget(HtmlView old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _controller?.loadHtmlString(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return Center(child: Text(context.l10n.noWebView));
    return WebViewWidget(controller: controller);
  }
}
