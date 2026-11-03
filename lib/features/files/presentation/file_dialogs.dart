import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../domain/file_listing.dart';

/// Asks for a single line of text (a name or a path). [validate] returns an error or null.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? Function(String value)? validate,
  String? confirm,
  bool selectStem = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      label: label,
      initial: initial,
      validate: validate,
      confirm: confirm,
      selectStem: selectStem,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.validate,
    required this.confirm,
    required this.selectStem,
  });

  final String title;
  final String label;
  final String initial;
  final String? Function(String value)? validate;
  final String? confirm;
  final bool selectStem;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void initState() {
    super.initState();
    // Renaming "notes.txt" selects "notes", like desktop file managers.
    final dot = widget.initial.lastIndexOf('.');
    final end = widget.selectStem && dot > 0 ? dot : widget.initial.length;
    _text.selection = TextSelection(baseOffset: 0, extentOffset: end);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    final error = value.isEmpty ? context.l10n.required : widget.validate?.call(value);
    if (error != null) return setState(() => _error = error);
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        autocorrect: false,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirm ?? l10n.ok)),
      ],
    );
  }
}

/// Edits POSIX permissions as checkboxes and as an octal number, kept in sync.
Future<int?> askPermissions(BuildContext context, {required String name, required int mode}) =>
    showDialog<int>(context: context, builder: (context) => _PermissionsDialog(name: name, mode: mode));

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.name, required this.mode});

  final String name;
  final int mode;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late int _mode = widget.mode & 0x1ff;
  late final _octal = TextEditingController(text: _mode.toRadixString(8).padLeft(3, '0'));

  @override
  void dispose() {
    _octal.dispose();
    super.dispose();
  }

  void _toggle(int bit) {
    setState(() => _mode ^= 1 << bit);
    _octal.text = _mode.toRadixString(8).padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = [(l10n.permOwner, 6), (l10n.permGroup, 3), (l10n.permOthers, 0)];
    return AlertDialog(
      title: Text(l10n.permissionsOf(widget.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {0: IntrinsicColumnWidth()},
            children: [
              TableRow(children: [
                const SizedBox(),
                for (final h in [l10n.permRead, l10n.permWrite, l10n.permExecute])
                  Center(child: Text(h, style: theme.textTheme.labelSmall)),
              ]),
              for (final (label, shift) in rows)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.only(right: 8), child: Text(label)),
                  for (final b in [2, 1, 0])
                    Checkbox(value: (_mode >> (shift + b)) & 1 == 1, onChanged: (_) => _toggle(shift + b)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(permissionString(_mode), style: const TextStyle(fontFamily: monoFont)),
              const Spacer(),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _octal,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: monoFont),
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) {
                    final m = parseOctalMode(v);
                    if (m != null) setState(() => _mode = m & 0x1ff);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _mode | (widget.mode & ~0x1ff)), child: Text(l10n.save)),
      ],
    );
  }
}
