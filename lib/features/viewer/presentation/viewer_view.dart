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
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.sync_problem),
          title: Text(l10n.changedOnServer),
          content: Text(l10n.changedOnServerBody(_doc.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, 'reload'), child: Text(l10n.discardMine)),
            FilledButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: Text(l10n.overwrite)),
          ],
        ),
      );
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
    final firstLine = text.substring(0, min(text.length, 120)).split('\n').first;
    final language = languageFor(doc.path) ?? languageFromShebang(firstLine);
    final mode = language == null || text.length > RemoteDocument.highlightLimit ? null : modeFor(language);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return CodeEditor(
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
      findBuilder: (context, controller, readOnly) => FindBar(controller: controller),
    );
  }
}

/// Search box over the code (re_editor's find, without replace in the viewer).
class FindBar extends StatelessWidget implements PreferredSizeWidget {
  const FindBar({super.key, required this.controller});

  final CodeFindController controller;

  @override
  Size get preferredSize => Size(double.infinity, controller.value == null ? 0 : 52);

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
    return Material(
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
            IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: controller.close),
          ],
        ),
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
