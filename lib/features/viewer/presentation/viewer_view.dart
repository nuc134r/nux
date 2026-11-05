import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:tab_switcher/tab_switcher.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart';
import '../../files/presentation/files_view.dart' show fileErrorText;
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../domain/languages.dart';
import '../domain/line_diff.dart';
import '../domain/remote_document.dart';
import 'viewer_tab.dart';

class ViewerView extends StatefulWidget {
  const ViewerView({super.key, required this.tab});

  final ViewerTab tab;

  @override
  State<ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<ViewerView> {
  RemoteDocument get _doc => widget.tab.document;

  @override
  void initState() {
    super.initState();
    if (_doc.bytes == null && !_doc.loading) WidgetsBinding.instance.addPostFrameCallback((_) => _doc.load());
  }

  /// Saves; when the file changed on the server meanwhile, asks whether to overwrite or reload.
  Future<void> _save() async {
    final l10n = context.l10n;
    try {
      await widget.tab.save();
      if (mounted) showSnack(context, l10n.savedFile(_doc.name));
    } on RemoteChangedException {
      if (!mounted) return;
      var choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.sync_problem),
          title: Text(l10n.changedOnServer),
          content: Text(l10n.changedOnServerBody(_doc.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, 'diff'), child: Text(l10n.showChanges)),
            TextButton(onPressed: () => Navigator.pop(context, 'reload'), child: Text(l10n.discardMine)),
            FilledButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: Text(l10n.overwrite)),
          ],
        ),
      );
      if (choice == 'diff' && mounted) {
        final theirs = await _doc.fetchRemoteText();
        if (!mounted) return;
        choice = await showDialog<String>(
          context: context,
          builder: (_) => Dialog.fullscreen(
            child: DiffView(oldText: theirs, newText: widget.tab.editedText ?? _doc.text),
          ),
        );
      }
      if (choice == 'overwrite') {
        await widget.tab.save(force: true);
        if (mounted) showSnack(context, l10n.savedFile(_doc.name));
      } else if (choice == 'reload') {
        await _doc.load();
      }
    } catch (e) {
      if (mounted) showSnack(context, fileErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    widget.tab.onSave = _save;
    // Live tabs stay mounted: only the tab in front handles Back.
    final active = TabSwitcher.isActive(context);
    return ListenableBuilder(
      listenable: widget.tab,
      builder: (context, child) => PopScope(
        canPop: !active || !widget.tab.handlesBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && active && widget.tab.handlesBack) widget.tab.back(context);
        },
        child: child!,
      ),
      child: _content(l10n),
    );
  }

  Widget _content(AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: widget.tab,
      builder: (context, _) {
        final doc = _doc;
        if (doc.bytes == null) {
          if (doc.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    Text(fileErrorText(l10n, doc.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: doc.load, child: Text(l10n.tryAgain)),
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            if (doc.loading) const LinearProgressIndicator(minHeight: 2),
            if (doc.truncated)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.content_cut),
                  title: Text(l10n.partiallyLoaded(formatSize(doc.bytes!.length), formatSize(doc.size))),
                  trailing: TextButton(onPressed: () => doc.load(all: true), child: Text(l10n.loadAll)),
                ),
              ),
            Expanded(
              child: switch (doc.kind) {
                FileKind.image => _ImageView(doc: doc),
                FileKind.markdown when widget.tab.rendered => PinchTextSize(
                  kind: TextSizeKind.editor,
                  child: _MarkdownView(text: doc.text),
                ),
                FileKind.binary || FileKind.archive => PinchTextSize(
                  kind: TextSizeKind.editor,
                  child: _HexView(doc: doc),
                ),
                _ => PinchTextSize(
                  kind: TextSizeKind.editor,
                  child: _CodeView(tab: widget.tab),
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _CodeView extends ConsumerWidget {
  const _CodeView({required this.tab});

  final ViewerTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = watchTextSize(ref, TextSizeKind.editor);
    final doc = tab.document;
    final text = doc.text;
    final (editor, finder) = tab.editorFor(doc.generation, text);
    if (tab.pendingLine != null) {
      tab.pendingLine = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => editor.makeCursorCenterIfInvisible());
    }
    final firstLine = text.substring(0, min(text.length, 120)).split('\n').first;
    final language = languageFor(doc.path) ?? languageFromShebang(firstLine);
    final mode = language == null || text.length > RemoteDocument.highlightLimit ? null : modeFor(language);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final editing = tab.editing;
    final codeEditor = CodeEditor(
      // Long press / selection: Cut, Copy, Paste, Select all (re_editor has no menu of its own).
      toolbarController: MobileSelectionToolbarController(
        builder: ({required context, required anchors, required controller, required onDismiss, required onRefresh}) {
          final selected = !controller.selection.isCollapsed;
          void run(void Function() action) {
            action();
            onDismiss();
          }

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: anchors,
            buttonItems: [
              if (editing && selected)
                ContextMenuButtonItem(type: ContextMenuButtonType.cut, onPressed: () => run(controller.cut)),
              if (selected)
                ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () => run(controller.copy)),
              if (editing)
                ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: () => run(controller.paste)),
              if (!controller.isAllSelected)
                ContextMenuButtonItem(
                  type: ContextMenuButtonType.selectAll,
                  onPressed: () {
                    controller.selectAll();
                    onRefresh();
                  },
                ),
            ],
          );
        },
      ),
      // Vertical only: horizontal scrolling (no wrap) keeps the default.
      scrollbarBuilder: (context, child, details) =>
          details.direction == AxisDirection.down ? Scrollbar(controller: details.controller, child: child) : child,
      controller: editor,
      findController: finder,
      readOnly: !tab.editing,
      showCursorWhenReadOnly: false,
      autofocus: tab.editing,
      wordWrap: tab.wrap,
      style: CodeEditorStyle(
        fontFamily: monoFont,
        fontSize: fontSize,
        backgroundColor: scheme.surface,
        textColor: scheme.onSurface,
        codeTheme: mode == null
            ? null
            : CodeHighlightTheme(
                languages: {language!: CodeHighlightThemeMode(mode: mode)},
                theme: dark ? atomOneDarkTheme : atomOneLightTheme,
              ),
      ),
      indicatorBuilder: (context, editingController, chunkController, notifier) => Row(
        children: [
          DefaultCodeLineNumber(controller: editingController, notifier: notifier),
          DefaultCodeChunkIndicator(width: 16, controller: chunkController, notifier: notifier),
        ],
      ),
      findBuilder: (context, controller, readOnly) => FindBar(controller: controller, editing: !readOnly),
    );
    // The same tree in both modes (the editor must not be rebuilt when editing starts).
    return Column(
      children: [
        Expanded(child: codeEditor),
        if (editing) EditorKeyBar(editor: editor),
      ],
    );
  }
}

/// Keys a phone keyboard lacks for code, under the editor while editing: indent, cursor, undo, symbols.
class EditorKeyBar extends StatelessWidget {
  const EditorKeyBar({super.key, required this.editor});

  final CodeLineEditingController editor;

  static const _symbols = [
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    '<',
    '>',
    ';',
    ':',
    '=',
    '"',
    "'",
    '`',
    '/',
    '\\',
    '|',
    '&',
    '!',
    '?',
    '-',
    '_',
    '+',
    '*',
    '#',
    r'$',
    '%',
    '@',
    '~',
    '^',
    '.',
    ',',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget key(Widget child, VoidCallback onTap, {String? tooltip}) => Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        // Never takes focus: the editor keeps it (and the keyboard stays up).
        canRequestFocus: false,
        child: SizedBox(width: 42, height: 48, child: Center(child: child)),
      ),
    );
    Widget icon(IconData i, VoidCallback onTap, String tooltip) =>
        key(Icon(i, size: 20, color: scheme.onSurfaceVariant), onTap, tooltip: tooltip);
    // Inside the editor's tap region: a tap here must not count as "outside" and close the keyboard.
    return CodeEditorTapRegion(
      child: Material(
        color: scheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                icon(Icons.keyboard_tab, editor.applyIndent, 'Tab'),
                icon(Icons.format_indent_decrease, editor.applyOutdent, l10n.outdent),
                icon(Icons.keyboard_arrow_left, () => editor.moveCursor(AxisDirection.left), '←'),
                icon(Icons.keyboard_arrow_up, () => editor.moveCursor(AxisDirection.up), '↑'),
                icon(Icons.keyboard_arrow_down, () => editor.moveCursor(AxisDirection.down), '↓'),
                icon(Icons.keyboard_arrow_right, () => editor.moveCursor(AxisDirection.right), '→'),
                icon(Icons.first_page, editor.moveCursorToLineStart, 'Home'),
                icon(Icons.last_page, editor.moveCursorToLineEnd, 'End'),
                icon(Icons.undo, editor.undo, l10n.undoEdit),
                icon(Icons.redo, editor.redo, l10n.redoEdit),
                VerticalDivider(width: 9, indent: 8, endIndent: 8, color: scheme.outlineVariant),
                for (final s in _symbols)
                  key(
                    Text(
                      s,
                      style: TextStyle(fontFamily: monoFont, fontSize: 17, color: scheme.onSurface),
                    ),
                    () => editor.replaceSelection(s),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What changed from [oldText] to [newText], as hunks of removed / added lines with a little context.
/// Closes with 'reload' (keep the old) or 'overwrite' (keep the new).
class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.oldText, required this.newText});

  final String oldText;
  final String newText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hunks = diffHunks(diffLines(oldText, newText));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serverVsYours),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'reload'), child: Text(l10n.discardMine)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: Text(l10n.overwrite)),
          ),
        ],
      ),
      body: hunks.isEmpty ? Center(child: Text(l10n.noDifferences)) : DiffLinesView(lines: hunks),
    );
  }
}

/// Diff lines with their numbers, removed ones red and added ones green; null is a "⋯" gap between hunks.
class DiffLinesView extends StatelessWidget {
  const DiffLinesView({super.key, required this.lines, this.shrinkWrap = false});

  final List<DiffLine?> lines;

  /// Sized to its lines and not scrolling (inside another list).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures, height: 1.4);
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        if (line == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text('⋯', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          );
        }
        final (bg, sign) = switch (line.kind) {
          DiffKind.removed => (scheme.errorContainer.withValues(alpha: .5), '-'),
          DiffKind.added => (Colors.green.withValues(alpha: .18), '+'),
          DiffKind.same => (Colors.transparent, ' '),
        };
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '${line.newLine ?? line.oldLine}',
                  textAlign: TextAlign.right,
                  style: mono?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              SizedBox(width: 18, child: Text(' $sign', style: mono)),
              Expanded(child: Text(line.text, style: mono)),
            ],
          ),
        );
      },
    );
  }
}

class FindBar extends StatelessWidget implements PreferredSizeWidget {
  const FindBar({super.key, required this.controller, this.editing = false});

  final CodeFindController controller;

  /// Replace is offered only while editing.
  final bool editing;

  bool get _replacing => editing && (controller.value?.replaceMode ?? false);

  @override
  Size get preferredSize => Size(double.infinity, controller.value == null ? 0 : (_replacing ? 104 : 52));

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final result = value.result;
    final count = result == null
        ? ''
        : result.matches.isEmpty
        ? '0/0'
        : '${result.index + 1}/${result.matches.length}';
    final bar = Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                autofocus: true,
                decoration: InputDecoration(isDense: true, hintText: l10n.find, suffixText: count),
                onSubmitted: (_) => controller.nextMatch(),
              ),
            ),
            IconButton(
              tooltip: l10n.matchCase,
              isSelected: value.option.caseSensitive,
              icon: const Icon(Icons.text_fields),
              onPressed: controller.toggleCaseSensitive,
            ),
            IconButton(
              tooltip: l10n.regex,
              isSelected: value.option.regex,
              icon: const Icon(Icons.data_object),
              onPressed: controller.toggleRegex,
            ),
            IconButton(
              tooltip: l10n.previous,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: controller.previousMatch,
            ),
            IconButton(
              tooltip: l10n.next,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: controller.nextMatch,
            ),
            if (editing)
              IconButton(
                tooltip: l10n.replace,
                isSelected: _replacing,
                icon: const Icon(Icons.find_replace),
                onPressed: controller.toggleMode,
              ),
            IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: controller.close),
          ],
        ),
      ),
    );
    if (!_replacing) return bar;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.replaceInputController,
                    focusNode: controller.replaceInputFocusNode,
                    decoration: InputDecoration(isDense: true, hintText: l10n.replaceWith),
                    onSubmitted: (_) => controller.replaceMatch(),
                  ),
                ),
                TextButton(onPressed: controller.replaceMatch, child: Text(l10n.replace)),
                TextButton(onPressed: controller.replaceAllMatches, child: Text(l10n.replaceAll)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownView extends ConsumerWidget {
  const _MarkdownView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = watchTextSize(ref, TextSizeKind.editor);
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return Scrollbar(
      child: Markdown(
        data: text,
        selectable: true,
        onTapLink: (text, href, title) {
          final uri = href == null ? null : Uri.tryParse(href);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: base.copyWith(
          code: TextStyle(fontFamily: monoFont, fontSize: fontSize),
          // fromTheme uses primaryColor, which is nearly the background in dark Material 3.
          checkbox: base.checkbox?.copyWith(color: Theme.of(context).colorScheme.primary),
          textScaler: TextScaler.linear(fontSize / TextSizeKind.editor.defaultSize),
        ),
      ),
    );
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.doc});

  final RemoteDocument doc;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: Image.memory(
          doc.bytes!,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => Text(context.l10n.imageUnreadable),
        ),
      ),
    );
  }
}

class _HexView extends ConsumerWidget {
  const _HexView({required this.doc});

  final RemoteDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = watchTextSize(ref, TextSizeKind.editor);
    final bytes = doc.bytes!;
    final lines = (bytes.length / 16).ceil();
    // Rows are wider than a phone: the vertical bar sits outside the horizontal scroller (it follows the
    // nested list's notifications) so it stays on screen.
    return Scrollbar(
      notificationPredicate: (n) => n.depth == 1,
      interactive: false,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: fontSize * 52,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lines,
              itemExtent: fontSize * 1.5,
              itemBuilder: (context, i) => Text(
                hexLine(bytes, i * 16),
                style: TextStyle(fontFamily: monoFont, fontSize: fontSize - 1, fontFeatures: noLigatures),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
