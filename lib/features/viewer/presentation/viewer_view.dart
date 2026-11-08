import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart' show BackendErrorKind, BackendException;
import 'package:re_editor/re_editor.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../app/theme.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/keys/key_bar_layout.dart';
import '../../../core/widgets/key_bar.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../browser/presentation/open_link.dart';
import '../../files/domain/file_listing.dart';
import '../../files/presentation/files_view.dart' show fileErrorText;
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../domain/languages.dart';
import '../domain/line_diff.dart';
import '../../workspace/data/workspace_access.dart';
import '../domain/remote_document.dart';
import '../domain/sudo_write.dart';
import '../domain/text_encoding.dart';
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
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.kind != BackendErrorKind.permissionDenied) {
        showSnack(context, fileErrorText(l10n, e));
        return;
      }
      if (widget.tab.content != null) {
        showSnack(context, l10n.cannotWriteContent);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_outline),
          title: Text(l10n.cannotWriteTitle),
          content: Text(l10n.cannotWriteBody(_doc.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.saveAsRoot)),
          ],
        ),
      );
      if (ok == true) await _saveAsRoot();
    } catch (e) {
      if (mounted) showSnack(context, fileErrorText(l10n, e));
    }
  }

  /// Saves through sudo: asks for the password when sudo needs one (checked before the file is written).
  Future<void> _saveAsRoot() async {
    final l10n = context.l10n;
    WorkspaceAccess? host;
    try {
      host = await widget.tab.openHost();
      final runner = host.runner;
      String? password;
      if (await sudoNeedsPassword(runner)) {
        String? error;
        while (true) {
          if (!mounted) return;
          password = await _askSudoPassword(error);
          if (password == null) return;
          try {
            await sudoCheck(runner, password);
            break;
          } on SudoException catch (e) {
            if (!e.wrongPassword) rethrow;
            error = l10n.sudoWrongPassword;
          }
        }
      }
      await widget.tab.save(force: true, writer: (data) => sudoWrite(runner, _doc.path, data, password: password));
      if (mounted) showSnack(context, l10n.savedAsRoot(_doc.name));
    } on SudoException catch (e) {
      if (mounted) showSnack(context, e.notAllowed ? l10n.sudoNotAllowed : l10n.errorGeneric(e.message));
    } catch (e) {
      if (mounted) showSnack(context, fileErrorText(l10n, e));
    } finally {
      host?.release();
    }
  }

  Future<String?> _askSudoPassword(String? error) {
    final l10n = context.l10n;
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsRoot),
        content: TextField(
          controller: field,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l10n.sudoPassword, errorText: error),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, field.text), child: Text(l10n.save)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    widget.tab.onSave = _save;
    widget.tab.onSaveAsRoot = _saveAsRoot;
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
    final settings = ref.watch(appSettingsProvider).value;
    final codeTheme = editorTheme(settings?.editorTheme, appDark: dark);
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
        fontFamily: settings?.editorFont ?? monoFont,
        fontSize: fontSize,
        fontHeight: settings?.editorLineHeight ?? AppSettingsState.defaultEditorLineHeight,
        // A chosen theme brings its own colours; following the app keeps the app's surface.
        backgroundColor: settings?.editorTheme == null ? scheme.surface : (codeTheme.background ?? scheme.surface),
        textColor: settings?.editorTheme == null ? scheme.onSurface : (codeTheme.foreground ?? scheme.onSurface),
        codeTheme: mode == null
            ? null
            : CodeHighlightTheme(
                languages: {language!: CodeHighlightThemeMode(mode: mode)},
                theme: codeTheme.styles,
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
    // The status bar gives its room to the keyboard (the key bar is there then).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Expanded(
          child: _CenterCursorOnKeyboard(editor: editor, enabled: editing, child: codeEditor),
        ),
        if (editing) EditorKeyBar(editor: editor),
        if (!keyboard && (settings?.editorStatusBar ?? true)) _StatusBar(tab: tab, editor: editor, language: language),
      ],
    );
  }
}

/// When the keyboard comes up over the editor, scrolls the cursor's line to the middle of what is left.
class _CenterCursorOnKeyboard extends StatefulWidget {
  const _CenterCursorOnKeyboard({required this.editor, required this.enabled, required this.child});

  final CodeLineEditingController editor;
  final bool enabled;
  final Widget child;

  @override
  State<_CenterCursorOnKeyboard> createState() => _CenterCursorOnKeyboardState();
}

class _CenterCursorOnKeyboardState extends State<_CenterCursorOnKeyboard> with WidgetsBindingObserver {
  double _inset = 0;
  bool _opening = false;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // The screens above remove the keyboard from MediaQuery, so this watches the window.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    if (inset == _inset) return;
    if (_inset == 0 && inset > 0) _opening = true;
    if (inset == 0) _opening = false;
    _inset = inset;
    // The keyboard animates in: wait until its height stops changing.
    _settle?.cancel();
    if (_opening && widget.enabled) _settle = Timer(const Duration(milliseconds: 120), _center);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle?.cancel();
    super.dispose();
  }

  void _center() {
    _opening = false;
    if (!mounted) return;
    // re_editor centres only a cursor that is out of view, so this asks its render object (private, hence
    // dynamic) where the cursor is and scrolls the editor's vertical scrollable.
    RenderBox? field;
    ScrollPosition? vertical;
    void visit(Element e) {
      final render = e.renderObject;
      if (field == null && render is RenderBox && render.runtimeType.toString() == '_CodeFieldRender') field = render;
      if (vertical == null && e is StatefulElement && e.state is ScrollableState) {
        final position = (e.state as ScrollableState).position;
        if (position.axis == Axis.vertical) vertical = position;
      }
      if (field == null || vertical == null) e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final box = field, position = vertical;
    if (box == null || position == null || !box.hasSize) return;
    try {
      final offset = (box as dynamic).calculateTextPositionViewportOffset(widget.editor.selection.extent) as Offset?;
      if (offset == null) {
        widget.editor.makeCursorCenterIfInvisible();
        return;
      }
      final lineHeight = (box as dynamic).lineHeight as double;
      final target = (position.pixels + offset.dy + lineHeight / 2 - box.size.height / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      position.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } on NoSuchMethodError {
      widget.editor.makeCursorCenterIfInvisible();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Under the editor: cursor position (and selection), language, encoding and line endings. Encoding and
/// line endings open their choices.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.tab, required this.editor, required this.language});

  final ViewerTab tab;
  final CodeLineEditingController editor;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final doc = tab.document;
    final style = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget item(String text, {VoidCallback? onTap, String? tooltip}) => InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text, style: style),
        ),
      ),
    );
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        // Rounded screen corners cut into the ends of a bottom bar: keep its text clear of them.
        minimum: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 28,
          child: Row(
            children: [
              ListenableBuilder(
                listenable: editor,
                builder: (context, _) {
                  final sel = editor.selection;
                  final selected = sel.isCollapsed ? 0 : editor.selectedText.length;
                  return item(
                    selected > 0
                        ? l10n.cursorPositionSelected(sel.extentIndex + 1, sel.extentOffset + 1, selected)
                        : l10n.cursorPosition(sel.extentIndex + 1, sel.extentOffset + 1),
                    tooltip: l10n.goToLine,
                    onTap: () => tab.goToLine(context),
                  );
                },
              ),
              const Spacer(),
              if (language != null) item(language!),
              item(
                doc.encoding.label,
                tooltip: l10n.encoding,
                onTap: () => showNuxMenu(
                  context,
                  beside: true,
                  (_) => [
                    for (final e in TextEncoding.values)
                      NuxMenuAction(
                        icon: null,
                        label: e.label,
                        checked: e == doc.encoding,
                        // Read again as e (only without unsaved edits), or, while editing, save as e.
                        enabled: tab.editing || !tab.dirty,
                        onSelected: () => tab.editing ? doc.saveAs(e) : doc.reopenWith(e),
                      ),
                  ],
                ),
              ),
              item(
                doc.lineEnding.label,
                tooltip: l10n.lineEndings,
                onTap: () => showNuxMenu(
                  context,
                  beside: true,
                  (_) => [
                    for (final e in LineEnding.values)
                      NuxMenuAction(
                        icon: null,
                        label: e.label,
                        checked: e == doc.lineEnding,
                        onSelected: () {
                          doc.setLineEnding(e);
                          tab.setEditing(true);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the editor's key bar can do [token].
bool editorSupports(String token) =>
    !isSpecialKey(token) || !(const {'ESC', 'CTRL', 'ALT', 'INS'}.contains(token) || RegExp(r'^F\d+$').hasMatch(token));

/// Tab, arrows, undo and the symbols code needs, laid out by the editor keys setting.
class EditorKeyBar extends ConsumerWidget {
  const EditorKeyBar({super.key, required this.editor});

  final CodeLineEditingController editor;

  void _key(String token) {
    switch (token) {
      case 'TAB':
        editor.applyIndent();
      case 'STAB':
        editor.applyOutdent();
      case 'LEFT':
        editor.moveCursor(AxisDirection.left);
      case 'RIGHT':
        editor.moveCursor(AxisDirection.right);
      case 'UP':
        editor.moveCursor(AxisDirection.up);
      case 'DOWN':
        editor.moveCursor(AxisDirection.down);
      case 'HOME':
        editor.moveCursorToLineStart();
      case 'END':
        editor.moveCursorToLineEnd();
      case 'PGUP':
        editor.moveCursorToPageUp();
      case 'PGDN':
        editor.moveCursorToPageDown();
      case 'DEL':
        editor.deleteForward();
      case 'BKSP':
        editor.deleteBackward();
      case 'ENTER':
        editor.applyNewLine();
      case 'SPACE':
        editor.replaceSelection(' ');
      case 'UNDO':
        editor.undo();
      case 'REDO':
        editor.redo();
      default:
        editor.replaceSelection(token);
        // A pair like () or ${}: the cursor goes inside.
        if (isBracketPair(token)) editor.moveCursor(AxisDirection.left);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout =
        ref.watch(appSettingsProvider).value?.keyBar(KeyBarFor.editor) ?? keyBarLayout(KeyBarFor.editor, null, null);
    final rows = [
      for (final r in layout)
        if (r.any((k) => editorSupports(k.main)))
          [
            for (final k in r)
              if (editorSupports(k.main)) k,
          ],
    ];
    // Inside the editor's tap region: a tap here must not count as "outside" and close the keyboard.
    return CodeEditorTapRegion(
      child: KeyBar(rows: rows, onKey: _key),
    );
  }
}

/// What changed from [oldText] to [newText], as hunks of removed / added lines with a little context.
/// Closes with 'reload' (keep the old) or 'overwrite' (keep the new).
class DiffView extends ConsumerWidget {
  const DiffView({super.key, required this.oldText, required this.newText});

  final String oldText;
  final String newText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          NuxMenuButton(tooltip: l10n.more, items: (context) => diffMenuItems(context, ref)),
        ],
      ),
      body: hunks.isEmpty
          ? Center(child: Text(l10n.noDifferences))
          : PinchTextSize(
              kind: TextSizeKind.diff,
              child: DiffLinesView(lines: hunks),
            ),
    );
  }
}

/// Whether diffs show old and new side by side: the setting, else when the screen is wide.
bool diffSideBySideOn(BuildContext context, AppSettingsState? settings) =>
    settings?.diffSideBySide ?? MediaQuery.sizeOf(context).width >= 600;

/// The "Side by side" option for a diff screen's menu.
NuxMenuAction diffLayoutAction(BuildContext context, WidgetRef ref) {
  final on = diffSideBySideOn(context, ref.read(appSettingsProvider).value);
  return NuxMenuAction(
    icon: Icons.vertical_split_outlined,
    label: context.l10n.sideBySide,
    checked: on,
    onSelected: () => ref.read(settingsRepositoryProvider).set(SettingKeys.diffSideBySide, '${!on}'),
  );
}

/// A diff screen's menu entries: the layout and the text size (pinching the diff changes it too).
List<NuxMenuItem> diffMenuItems(BuildContext context, WidgetRef ref) => [
  diffLayoutAction(context, ref),
  textSizeMenuItem(TextSizeKind.diff),
];

/// Diff lines with their numbers, removed ones red and added ones green; null is a "⋯" gap between hunks.
/// Side by side (see [diffSideBySideOn]) the old lines are on the left and the new on the right.
class DiffLinesView extends ConsumerWidget {
  const DiffLinesView({super.key, required this.lines, this.shrinkWrap = false});

  final List<DiffLine?> lines;

  /// Sized to its lines and not scrolling (inside another list).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fontSize = watchTextSize(ref, TextSizeKind.diff);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: monoFont,
      fontFeatures: noLigatures,
      fontSize: fontSize,
      height: 1.4,
    );
    final numbers = mono?.copyWith(color: scheme.onSurfaceVariant);
    final split = diffSideBySideOn(context, ref.watch(appSettingsProvider).value);
    final rows = split ? sideBySide(lines) : null;
    Color background(DiffKind kind) => switch (kind) {
      DiffKind.removed => scheme.errorContainer.withValues(alpha: .5),
      DiffKind.added => Colors.green.withValues(alpha: .18),
      DiffKind.same => Colors.transparent,
    };
    Widget gap() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text('⋯', style: TextStyle(color: scheme.onSurfaceVariant)),
      ),
    );
    // One side of a side-by-side row; empty (shaded) where the line is not on that side.
    Widget half(DiffLine? line, {required bool old}) => Expanded(
      child: Container(
        color: line == null ? scheme.surfaceContainerHigh : background(line.kind),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: line == null
            ? const SizedBox.shrink()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fontSize * 2.7,
                    child: Text('${old ? line.oldLine : line.newLine}', textAlign: TextAlign.right, style: numbers),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line.text, style: mono)),
                ],
              ),
      ),
    );
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: rows?.length ?? lines.length,
      itemBuilder: (context, i) {
        if (rows != null) {
          final row = rows[i];
          if (row == null) return gap();
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                half(row.$1, old: true),
                VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
                half(row.$2, old: false),
              ],
            ),
          );
        }
        final line = lines[i];
        if (line == null) return gap();
        final sign = switch (line.kind) {
          DiffKind.removed => '-',
          DiffKind.added => '+',
          DiffKind.same => ' ',
        };
        return Container(
          color: background(line.kind),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: fontSize * 3.4,
                child: Text('${line.newLine ?? line.oldLine}', textAlign: TextAlign.right, style: numbers),
              ),
              SizedBox(
                width: fontSize * 1.5,
                child: Text(' $sign', style: mono),
              ),
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
          if (uri != null) askOpenLink(context, uri);
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
