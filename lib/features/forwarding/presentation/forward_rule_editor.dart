import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../data/forward_rule_repository.dart';
import '../data/forwarding_providers.dart';
import '../domain/forward_rule.dart';
import 'forwarding_widgets.dart';

/// Adds or edits a forwarding rule, explaining in plain words what it will do.
class ForwardRuleEditor extends ConsumerStatefulWidget {
  const ForwardRuleEditor({super.key, this.ruleId, this.connectionId});

  final String? ruleId;

  /// Preselected host for a new rule.
  final String? connectionId;

  @override
  ConsumerState<ForwardRuleEditor> createState() => _ForwardRuleEditorState();
}

class _ForwardRuleEditorState extends ConsumerState<ForwardRuleEditor> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _bindPort = TextEditingController();
  final _targetHost = TextEditingController(text: 'localhost');
  final _targetPort = TextEditingController();
  ForwardKind _kind = ForwardKind.local;
  String? _connectionId;
  bool _shared = false;
  bool _autoStart = false;
  bool _loaded = false;
  ForwardRule? _original;

  bool get _isNew => widget.ruleId == null;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.connectionId;
    _load();
    for (final c in [_bindPort, _targetHost, _targetPort]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _load() async {
    final id = widget.ruleId;
    if (id != null) {
      final r = await ref.read(forwardRuleRepositoryProvider).get(id);
      if (r != null) {
        _original = r;
        _connectionId = r.connectionId;
        _kind = r.forwardKind;
        _label.text = r.label;
        _bindPort.text = '${r.bindPort}';
        _targetHost.text = r.targetHost.isEmpty ? 'localhost' : r.targetHost;
        _targetPort.text = r.targetPort == 0 ? '' : '${r.targetPort}';
        _shared = r.bindHost != '127.0.0.1' && r.bindHost != 'localhost';
        _autoStart = r.autoStart;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_label, _bindPort, _targetHost, _targetPort]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _bindHost => _shared ? '0.0.0.0' : '127.0.0.1';

  ForwardRule _draft() => ForwardRule(
        id: widget.ruleId ?? '',
        createdAt: DateTime(2000),
        updatedAt: DateTime(2000),
        connectionId: _connectionId ?? '',
        kind: _kind.name,
        label: _label.text.trim(),
        bindHost: _bindHost,
        bindPort: int.tryParse(_bindPort.text.trim()) ?? 0,
        targetHost: _kind == ForwardKind.dynamic ? '' : _targetHost.text.trim(),
        targetPort: _kind == ForwardKind.dynamic ? 0 : int.tryParse(_targetPort.text.trim()) ?? 0,
        autoStart: _autoStart,
        sortOrder: _original?.sortOrder ?? 0,
      );

  String? _portError(String? v, {bool local = false}) {
    final l10n = context.l10n;
    final p = int.tryParse((v ?? '').trim());
    if (p == null || p < 1 || p > 65535) return l10n.invalidPort;
    if (local && p < 1024 && Platform.isAndroid) return l10n.forwardLowPort;
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    final draft = _draft();
    final others = await ref.read(forwardRuleRepositoryProvider).all();
    final conflict = conflictingRule(draft, others);
    if (conflict != null) {
      if (mounted) showSnack(context, l10n.forwardConflict(conflict.label.isNotEmpty ? conflict.label : conflict.describe()));
      return;
    }
    final id = await ref.read(forwardRuleRepositoryProvider).save(ForwardRulesCompanion(
          id: _isNew ? const Value.absent() : Value(widget.ruleId!),
          connectionId: Value(draft.connectionId),
          kind: Value(draft.kind),
          label: Value(draft.label),
          bindHost: Value(draft.bindHost),
          bindPort: Value(draft.bindPort),
          targetHost: Value(draft.targetHost),
          targetPort: Value(draft.targetPort),
          autoStart: Value(draft.autoStart),
          createdAt: _isNew ? Value(DateTime.now()) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ));
    final saved = await ref.read(forwardRuleRepositoryProvider).get(id);
    if (saved != null) await ref.read(forwardingManagerProvider).restartIfOn(saved);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final rule = _original;
    if (rule == null) return;
    await ref.read(forwardingManagerProvider).stop(rule.id);
    await ref.read(forwardRuleRepositoryProvider).delete(rule.id);
    if (mounted) {
      showSnack(context, l10n.deleted(rule.label.isNotEmpty ? rule.label : rule.describe()));
      context.pop();
    }
  }

  /// The rule in a sentence, updated as the fields change.
  String _explain(AppLocalizations l10n, String host) {
    final bind = _bindPort.text.trim().isEmpty ? '…' : _bindPort.text.trim();
    final target = '${_targetHost.text.trim().isEmpty ? '…' : _targetHost.text.trim()}:${_targetPort.text.trim().isEmpty ? '…' : _targetPort.text.trim()}';
    return switch (_kind) {
      ForwardKind.local => _shared ? l10n.explainLocalShared(bind, target, host) : l10n.explainLocal(bind, target, host),
      ForwardKind.remote => l10n.explainRemote(host, bind, target),
      ForwardKind.dynamic => _shared ? l10n.explainDynamicShared(bind, host) : l10n.explainDynamic(bind, host),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final host = connections.where((c) => c.id == _connectionId).firstOrNull;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addForward : l10n.editForward),
        actions: [
          if (!_isNew) IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: connections.any((c) => c.id == _connectionId) ? _connectionId : null,
                    decoration: InputDecoration(labelText: l10n.hostField),
                    items: [for (final c in connections) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (v) => setState(() => _connectionId = v),
                    validator: (v) => v == null ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ForwardKind>(
                    segments: [
                      for (final k in ForwardKind.values)
                        ButtonSegment(value: k, icon: Icon(forwardIcon(k)), label: Text(forwardKindLabel(l10n, k))),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.single),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_explain(l10n, host?.name ?? l10n.theServer), style: theme.textTheme.bodyMedium),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bindPort,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: _kind == ForwardKind.remote ? l10n.serverPort : l10n.devicePort,
                      helperText: _kind == ForwardKind.dynamic ? l10n.socksPortHint : null,
                    ),
                    validator: (v) => _portError(v, local: _kind != ForwardKind.remote),
                  ),
                  if (_kind != ForwardKind.dynamic) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _targetHost,
                            autocorrect: false,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: l10n.targetHost,
                              helperText: _kind == ForwardKind.local ? l10n.targetHostLocalHint : l10n.targetHostRemoteHint,
                              helperMaxLines: 2,
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 104,
                          child: TextFormField(
                            controller: _targetPort,
                            keyboardType: TextInputType.number,
                            inputFormatters: digits,
                            decoration: InputDecoration(labelText: l10n.portField),
                            validator: _portError,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _label,
                    decoration: InputDecoration(labelText: l10n.nameField, hintText: _draft().describe()),
                  ),
                  if (_kind != ForwardKind.remote)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _shared,
                      onChanged: (v) => setState(() => _shared = v),
                      title: Text(l10n.forwardShared),
                      subtitle: Text(l10n.forwardSharedHint),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoStart,
                    onChanged: (v) => setState(() => _autoStart = v),
                    title: Text(l10n.forwardAutoStart),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _save, child: Text(l10n.save)),
                  ),
                ],
              ),
            ),
    );
  }
}
