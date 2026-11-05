import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/keys/key_bar_layout.dart';
import '../../../l10n/l10n.dart';

typedef _Pos = ({int row, int index});

/// Arranges extra keys by hand: drag a key (long press) to move it within or between rows, or onto the bin
/// to remove it; tap a key to change it; + adds a key to a row.
class KeyLayoutEditor extends StatefulWidget {
  const KeyLayoutEditor({super.key, required this.rows, required this.supports, required this.onChanged});

  final List<List<BarKey>> rows;

  /// Special keys this bar can do (offered when adding a key).
  final bool Function(String token) supports;
  final ValueChanged<List<List<BarKey>>> onChanged;

  @override
  State<KeyLayoutEditor> createState() => _KeyLayoutEditorState();
}

class _KeyLayoutEditorState extends State<KeyLayoutEditor> {
  late List<List<BarKey>> _rows = _copy(widget.rows);
  bool _dragging = false;

  static List<List<BarKey>> _copy(List<List<BarKey>> rows) => [
    for (final r in rows) [...r],
  ];

  @override
  void didUpdateWidget(KeyLayoutEditor old) {
    super.didUpdateWidget(old);
    // Changed from outside (the text): take it.
    if (formatKeyBar(widget.rows) != formatKeyBar(_rows)) _rows = _copy(widget.rows);
  }

  void _commit() {
    _rows.removeWhere((r) => r.isEmpty);
    if (_rows.isEmpty) _rows.add([]);
    setState(() {});
    widget.onChanged([
      for (final r in _rows)
        if (r.isNotEmpty) r,
    ]);
  }

  /// Moves the key at [from] to before [to] (or to the end of row [to.row] when [to.index] is past it).
  void _move(_Pos from, _Pos to) {
    final key = _rows[from.row].removeAt(from.index);
    var index = to.index;
    if (from.row == to.row && from.index < index) index--;
    _rows[to.row].insert(index.clamp(0, _rows[to.row].length), key);
    HapticFeedback.selectionClick();
    _commit();
  }

  Future<void> _edit(int row, int? index) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _KeyDialog(initial: index == null ? null : _rows[row][index], supports: widget.supports),
    );
    if (result == null) return;
    if (result.delete) {
      _rows[row].removeAt(index!);
    } else if (index == null) {
      _rows[row].add(result.key!);
    } else {
      _rows[row][index] = result.key!;
    }
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (r, row) in _rows.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, key) in row.indexed)
                  _Target(
                    onAccept: (from) => _move(from, (row: r, index: i)),
                    child: LongPressDraggable<_Pos>(
                      data: (row: r, index: i),
                      onDragStarted: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _dragging = true);
                      },
                      onDragEnd: (_) => setState(() => _dragging = false),
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.primaryContainer,
                        child: _KeyChip(barKey: key),
                      ),
                      childWhenDragging: Opacity(opacity: .3, child: _KeyChip(barKey: key)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _edit(r, i),
                        child: _KeyChip(barKey: key),
                      ),
                    ),
                  ),
                // The end of the row: drop here to put a key last, tap to add one.
                _Target(
                  onAccept: (from) => _move(from, (row: r, index: row.length)),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.addKey,
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => _edit(r, null),
                  ),
                ),
              ],
            ),
          ),
        // While dragging: the bin, and a new row to drop into.
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _dragging
              ? Row(
                  children: [
                    Expanded(
                      child: _DropZone(
                        icon: Icons.add,
                        label: l10n.newRow,
                        onAccept: (from) {
                          final key = _rows[from.row].removeAt(from.index);
                          _rows.add([key]);
                          _commit();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DropZone(
                        icon: Icons.delete_outline,
                        label: l10n.removeKey,
                        danger: true,
                        onAccept: (from) {
                          _rows[from.row].removeAt(from.index);
                          _commit();
                        },
                      ),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addRow),
                    onPressed: () => setState(() => _rows.add([])),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Highlights while a key is dragged over it.
class _Target extends StatelessWidget {
  const _Target({required this.onAccept, required this.child});

  final ValueChanged<_Pos> onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<_Pos>(
    onAcceptWithDetails: (d) => onAccept(d.data),
    builder: (context, candidates, _) => AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(left: candidates.isEmpty ? 0 : 14),
      decoration: BoxDecoration(
        border: candidates.isEmpty
            ? null
            : Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
      ),
      child: child,
    ),
  );
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.icon, required this.label, required this.onAccept, this.danger = false});

  final IconData icon;
  final String label;
  final ValueChanged<_Pos> onAccept;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.primary;
    return DragTarget<_Pos>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: candidates.isEmpty ? .08 : .25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.barKey});

  final BarKey barKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sized to the label (an aligned Container would fill the whole row of the Wrap).
    return Container(
      constraints: const BoxConstraints(minWidth: 38),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            keyLabel(barKey.main),
            style: TextStyle(fontFamily: monoFont, fontFeatures: noLigatures, color: scheme.onSurface),
          ),
          // Long-press alternates, as on the bar.
          if (barKey.alternates.isNotEmpty) ...[
            const SizedBox(width: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: scheme.outline, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditResult {
  const _EditResult.key(BarKey this.key) : delete = false;
  const _EditResult.delete() : key = null, delete = true;

  final BarKey? key;
  final bool delete;
}

/// A key: a special key or text to type, and what a long press offers.
class _KeyDialog extends StatefulWidget {
  const _KeyDialog({required this.initial, required this.supports});

  final BarKey? initial;
  final bool Function(String token) supports;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  late String? _special = widget.initial != null && isSpecialKey(widget.initial!.main) ? widget.initial!.main : null;
  late final _text = TextEditingController(
    text: widget.initial != null && !isSpecialKey(widget.initial!.main) ? widget.initial!.main : '',
  );
  late final _alternates = TextEditingController(text: widget.initial?.alternates.join(' ') ?? '');

  @override
  void dispose() {
    _text.dispose();
    _alternates.dispose();
    super.dispose();
  }

  BarKey? get _result {
    final main = _special ?? _text.text;
    if (main.isEmpty) return null;
    final alternates = [
      for (final a in _alternates.text.split(' '))
        if (a.isNotEmpty) a,
    ];
    return BarKey(main, alternates);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mono = const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures);
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addKey : l10n.editKey),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            autofocus: widget.initial == null,
            autocorrect: false,
            enableSuggestions: false,
            style: mono,
            decoration: InputDecoration(labelText: l10n.keyTypes),
            onChanged: (v) => setState(() {
              if (v.isNotEmpty) _special = null;
            }),
          ),
          const SizedBox(height: 12),
          Text(l10n.orSpecialKey, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in specialKeys.keys.where(widget.supports))
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(keyLabel(k), style: mono),
                  tooltip: k,
                  selected: _special == k,
                  onSelected: (on) => setState(() {
                    _special = on ? k : null;
                    if (on) _text.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alternates,
            autocorrect: false,
            enableSuggestions: false,
            style: mono,
            decoration: InputDecoration(labelText: l10n.keyAlternates, helperText: l10n.keyAlternatesHint),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (widget.initial != null)
          TextButton(onPressed: () => Navigator.pop(context, const _EditResult.delete()), child: Text(l10n.delete)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _result == null ? null : () => Navigator.pop(context, _EditResult.key(_result!)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
