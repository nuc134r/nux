import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../data/forward_rule_repository.dart';
import '../data/forwarding_providers.dart';
import '../domain/forward_rule.dart';

/// Ports offered as one-tap destinations.
const _services = [
  ('SSH', 22),
  ('HTTP', 80),
  ('HTTPS', 443),
  ('HTTP', 8080),
  ('RDP', 3389),
  ('VNC', 5900),
  ('SMB', 445),
  ('PostgreSQL', 5432),
  ('MySQL', 3306),
  ('Redis', 6379),
  ('MongoDB', 27017),
  ('Dev server', 3000),
  ('Minecraft', 25565),
];

/// Adds or edits a forwarding of one host (the host is fixed: forwardings belong to it).
class ForwardRuleEditor extends ConsumerStatefulWidget {
  const ForwardRuleEditor({super.key, this.ruleId, this.connectionId}) : assert(ruleId != null || connectionId != null);

  final String? ruleId;

  /// The host of a new forwarding.
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
  bool _tcp = true;
  bool _udp = false;
  bool _shared = false;
  bool _autoStart = false;
  bool _loaded = false;
  ForwardRule? _original;
  List<ForwardRule> _others = const [];

  /// The bind port was filled in by us (and follows the destination port until the user types one).
  bool _suggested = false;

  bool get _isNew => widget.ruleId == null;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.connectionId;
    _load();
    for (final c in [_bindPort, _targetHost, _targetPort, _label]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _load() async {
    final repo = ref.read(forwardRuleRepositoryProvider);
    _others = await repo.all();
    final id = widget.ruleId;
    if (id != null) {
      final r = await repo.get(id);
      if (r != null) {
        _original = r;
        _connectionId = r.connectionId;
        _kind = r.forwardKind;
        _label.text = r.label;
        _bindPort.text = '${r.bindPort}';
        _targetHost.text = r.targetHost.isEmpty ? 'localhost' : r.targetHost;
        _targetPort.text = r.targetPort == 0 ? '' : '${r.targetPort}';
        _shared = r.shared;
        _tcp = r.tcp;
        _udp = r.udp;
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

  ForwardRule _draft({int? bindPort}) => ForwardRule(
    id: widget.ruleId ?? '',
    createdAt: DateTime(2000),
    updatedAt: DateTime(2000),
    connectionId: _connectionId,
    kind: _kind.name,
    label: _label.text.trim(),
    bindHost: _shared ? '0.0.0.0' : '127.0.0.1',
    bindPort: bindPort ?? int.tryParse(_bindPort.text.trim()) ?? 0,
    targetHost: _kind == ForwardKind.dynamic ? '' : _targetHost.text.trim(),
    targetPort: _kind == ForwardKind.dynamic ? 0 : int.tryParse(_targetPort.text.trim()) ?? 0,
    tcp: _tcp || !_udpAllowed,
    udp: _udp && _udpAllowed,
    autoStart: _autoStart,
    sortOrder: _original?.sortOrder ?? 0,
  );

  /// UDP goes straight over ZeroTier, so only to a port of a ZeroTier host itself.
  bool get _udpAllowed => _host?.zerotierNetwork != null && _kind == ForwardKind.local && isLoopback(_targetHost.text);

  Connection? get _host {
    final id = _connectionId;
    return id == null ? null : ref.read(connectionProvider(id)).value;
  }

  /// A listening port for [target]: the same one (or +10000 below 1024, which Android does not allow),
  /// moved up past ports other forwardings use.
  void _suggestBindPort(int? target) {
    if (target == null || !(_suggested || _bindPort.text.isEmpty)) return;
    var port = target < 1024 && _kind != ForwardKind.remote ? target + 10000 : target;
    while (port < 65535 && conflictingRule(_draft(bindPort: port), _others) != null) {
      port++;
    }
    _bindPort.text = '$port';
    _suggested = true;
  }

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
    final conflict = conflictingRule(draft, _others);
    if (conflict != null) {
      showSnack(context, l10n.forwardConflict(conflict.label.isNotEmpty ? conflict.label : conflict.describe()));
      return;
    }
    final repo = ref.read(forwardRuleRepositoryProvider);
    final id = await repo.save(
      ForwardRulesCompanion(
        id: _isNew ? const Value.absent() : Value(widget.ruleId!),
        connectionId: Value(draft.connectionId),
        zerotierNetwork: const Value(null),
        kind: Value(draft.kind),
        label: Value(draft.label),
        bindHost: Value(draft.bindHost),
        bindPort: Value(draft.bindPort),
        targetHost: Value(draft.targetHost),
        targetPort: Value(draft.targetPort),
        tcp: Value(draft.tcp),
        udp: Value(draft.udp),
        autoStart: Value(draft.autoStart),
        createdAt: _isNew ? Value(DateTime.now()) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final saved = await repo.get(id);
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

  /// The rule in one line: `localhost:15432 → Build server → db:5432`.
  String _summary(String host) {
    final d = _draft();
    final bind = '${d.shared ? '::' : 'localhost:'}${d.bindPort == 0 ? '…' : d.bindPort}';
    final target = '${isLoopback(d.targetHost) ? 'localhost' : d.targetHost}:${d.targetPort == 0 ? '…' : d.targetPort}';
    return switch (_kind) {
      ForwardKind.local => '$bind → $host → $target',
      ForwardKind.remote => '$host:${d.bindPort == 0 ? '…' : d.bindPort} → $target',
      ForwardKind.dynamic => 'SOCKS $bind → $host',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final host = _connectionId == null ? null : ref.watch(connectionProvider(_connectionId!)).value;
    final hostName = host?.name ?? l10n.theServer;
    final onZeroTier = host?.zerotierNetwork != null;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final targetPort = int.tryParse(_targetPort.text.trim());
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _isNew ? l10n.addForward : (_original?.label.isNotEmpty ?? false ? _original!.label : l10n.editForward),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          subtitle: Text(hostName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          if (!_isNew)
            NuxMenuButton(
              tooltip: l10n.more,
              items: (_) => [NuxMenuAction(icon: Icons.delete_outline, label: l10n.delete, onSelected: _delete)],
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SegmentedButton<ForwardKind>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ForwardKind.local, label: Text(l10n.forwardHereToThere)),
                      ButtonSegment(value: ForwardKind.remote, label: Text(l10n.forwardThereToHere)),
                      ButtonSegment(value: ForwardKind.dynamic, label: Text(l10n.forwardDynamic)),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.single),
                  ),
                  if (onZeroTier && _kind == ForwardKind.local) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('TCP'),
                          selected: _tcp || !_udpAllowed,
                          onSelected: _udpAllowed ? (v) => setState(() => _tcp = v) : null,
                        ),
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('UDP'),
                          selected: _udp && _udpAllowed,
                          onSelected: _udpAllowed ? (v) => setState(() => _udp = v) : null,
                        ),
                      ],
                    ),
                    if (!_udpAllowed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.udpNeedsHostItself(hostName), style: theme.textTheme.bodySmall),
                      )
                    else if (!_tcp && !_udp)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.pickProtocol, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                      ),
                  ],
                  const SizedBox(height: 20),
                  if (_kind != ForwardKind.dynamic) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _targetHost,
                            autocorrect: false,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: _kind == ForwardKind.remote
                                  ? l10n.destinationHere
                                  : l10n.destinationFrom(hostName),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 96,
                          child: TextFormField(
                            controller: _targetPort,
                            keyboardType: TextInputType.number,
                            inputFormatters: digits,
                            decoration: InputDecoration(labelText: l10n.portField),
                            validator: _portError,
                            onChanged: (v) => _suggestBindPort(int.tryParse(v)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // One scrolling row of compact chips, not a block of them.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (name, port) in _services)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                showCheckmark: false,
                                label: Text('$name $port'),
                                selected: targetPort == port,
                                onSelected: (_) {
                                  _targetPort.text = '$port';
                                  _suggestBindPort(port);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextFormField(
                    controller: _bindPort,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: _kind == ForwardKind.remote ? l10n.portOnHost(hostName) : l10n.portHere,
                      helperText: _kind == ForwardKind.dynamic
                          ? l10n.socksPortHint
                          : _suggested
                          ? l10n.portSuggested
                          : null,
                      helperMaxLines: 2,
                    ),
                    validator: (v) => _portError(v, local: _kind != ForwardKind.remote),
                    onChanged: (_) => _suggested = false,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _summary(hostName),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _label,
                    decoration: InputDecoration(
                      labelText: l10n.nameOptional,
                      hintText: wellKnownPorts[targetPort] ?? _draft().describe(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_kind != ForwardKind.remote)
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(l10n.otherDevices),
                          tooltip: l10n.forwardSharedHint,
                          selected: _shared,
                          onSelected: (v) => setState(() => _shared = v),
                        ),
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(l10n.startWithNux),
                        selected: _autoStart,
                        onSelected: (v) => setState(() => _autoStart = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: onZeroTier && _udpAllowed && !_tcp && !_udp ? null : _save,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ),
    );
  }
}
