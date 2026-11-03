import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../identities/data/identity_repository.dart';
import '../../identities/domain/key_material.dart';
import '../data/connection_repository.dart';
import '../../zerotier/presentation/zerotier_network_field.dart';
import 'connection_actions.dart';

/// Colour tags offered for connections.
const connectionColors = [0xFFE57373, 0xFFFFB74D, 0xFFFFF176, 0xFF81C784, 0xFF4DD0E1, 0xFF64B5F6, 0xFF9575CD, 0xFFF06292];

/// Adds or edits a saved host.
class ConnectionEditorScreen extends ConsumerStatefulWidget {
  const ConnectionEditorScreen({super.key, this.connectionId});

  final String? connectionId;

  @override
  ConsumerState<ConnectionEditorScreen> createState() => _ConnectionEditorScreenState();
}

class _ConnectionEditorScreenState extends ConsumerState<ConnectionEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _group = TextEditingController();
  final _keepAlive = TextEditingController(text: '15');
  List<String> _keys = [];
  String? _jumpHostId;
  String? _zerotierNetwork;
  bool _viaZeroTier = false;
  int? _color;
  bool _savePassword = false;
  bool _hasSavedPassword = false;
  bool _loaded = false;
  bool _passwordVisible = false;
  Connection? _original;

  bool get _isNew => widget.connectionId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.connectionId;
    if (id != null) {
      final repo = ref.read(connectionRepositoryProvider);
      final c = await repo.get(id);
      if (c != null) {
        _original = c;
        _name.text = c.name;
        _host.text = c.host;
        _port.text = '${c.port}';
        _user.text = c.username;
        _group.text = c.groupName ?? '';
        _keepAlive.text = '${c.keepAliveSeconds}';
        _keys = c.identityIdList;
        _jumpHostId = c.jumpHostId;
        _zerotierNetwork = c.zerotierNetwork;
        _viaZeroTier = c.zerotierNetwork != null;
        _color = c.color;
        _savePassword = c.savePassword;
        _hasSavedPassword = c.savePassword && await repo.savedPassword(id) != null;
      }
    } else {
      // A new host offers every key by default.
      _keys = [for (final k in await ref.read(identityRepositoryProvider).all()) k.id];
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password, _group, _keepAlive]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(connectionRepositoryProvider);
    final now = DateTime.now();
    final host = _host.text.trim();
    final data = ConnectionsCompanion(
      id: _isNew ? const Value.absent() : Value(widget.connectionId!),
      name: Value(_name.text.trim().isEmpty ? host : _name.text.trim()),
      host: Value(host),
      port: Value(int.parse(_port.text.trim())),
      username: Value(_user.text.trim()),
      identityIds: Value(encodeIdentityIds(_keys)),
      jumpHostId: Value(_jumpHostId),
      zerotierNetwork: Value(_viaZeroTier ? _zerotierNetwork : null),
      groupName: Value(_group.text.trim().isEmpty ? null : _group.text.trim()),
      color: Value(_color),
      keepAliveSeconds: Value(int.tryParse(_keepAlive.text.trim()) ?? 15),
      createdAt: _isNew ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
    final id = await repo.save(data);
    if (!_savePassword) {
      await repo.setSavedPassword(id, null);
    } else if (_password.text.isNotEmpty) {
      await repo.setSavedPassword(id, _password.text);
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final identities = ref.watch(identitiesProvider).value ?? const <Identity>[];
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final groups = {for (final c in connections) ?c.groupName}.toList()..sort();
    final jumpCandidates = connections.where((c) => c.id != widget.connectionId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addHost : l10n.editHost),
        actions: [
          if (!_isNew && _original != null)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await deleteConnection(context, ref, _original!) && context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _host,
                          autofocus: _isNew,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(labelText: l10n.hostField, hintText: 'example.com'),
                          validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.portField),
                          validator: (v) {
                            final p = int.tryParse((v ?? '').trim());
                            return p == null || p < 1 || p > 65535 ? l10n.invalidPort : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _user,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: l10n.usernameField),
                    validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l10n.nameField, hintText: _host.text.trim()),
                  ),
                  SectionTitle(l10n.authentication),
                  Text(l10n.authenticationHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  if (identities.isEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.key_off_outlined),
                      title: Text(l10n.noKeysYet),
                      trailing: TextButton(onPressed: () => context.push(Routes.keys), child: Text(l10n.keys)),
                    ),
                  for (final k in identities)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _keys.contains(k.id),
                      onChanged: (v) => setState(() => v == true ? _keys.add(k.id) : _keys.remove(k.id)),
                      secondary: const Icon(Icons.key),
                      title: Text(k.name),
                      subtitle: Text('${keyTypeLabel(k.algorithm)} · ${k.fingerprint}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _savePassword,
                    onChanged: (v) => setState(() => _savePassword = v),
                    title: Text(l10n.savePassword),
                    subtitle: Text(l10n.savePasswordHint),
                  ),
                  if (_savePassword)
                    TextFormField(
                      controller: _password,
                      obscureText: !_passwordVisible,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        helperText: _hasSavedPassword ? l10n.passwordKeepHint : null,
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible ? l10n.hide : l10n.show,
                          icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      validator: (v) => _savePassword && !_hasSavedPassword && (v ?? '').isEmpty ? l10n.required : null,
                    ),
                  SectionTitle(l10n.organize),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _group.text),
                    optionsBuilder: (v) => groups.where((g) => g.toLowerCase().contains(v.text.toLowerCase())),
                    onSelected: (v) => _group.text = v,
                    fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                      controller: controller,
                      focusNode: focus,
                      onChanged: (v) => _group.text = v,
                      decoration: InputDecoration(labelText: l10n.groupField),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Swatch(
                        color: null,
                        selected: _color == null,
                        tooltip: l10n.noColor,
                        onTap: () => setState(() => _color = null),
                      ),
                      for (final c in connectionColors)
                        _Swatch(color: Color(c), selected: _color == c, onTap: () => setState(() => _color = c)),
                    ],
                  ),
                  SectionTitle(l10n.advanced),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.lan_outlined),
                    value: _viaZeroTier,
                    onChanged: (v) => setState(() => _viaZeroTier = v),
                    title: Text(l10n.reachThroughZeroTier),
                    subtitle: Text(l10n.reachThroughZeroTierHint),
                  ),
                  if (_viaZeroTier) ...[
                    ZeroTierNetworkField(initial: _zerotierNetwork, onChanged: (v) => _zerotierNetwork = v),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String?>(
                    initialValue: jumpCandidates.any((c) => c.id == _jumpHostId) ? _jumpHostId : null,
                    decoration: InputDecoration(labelText: l10n.jumpHost, helperText: l10n.jumpHostHint),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.none)),
                      for (final c in jumpCandidates) DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _jumpHostId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _keepAlive,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.keepAlive, helperText: l10n.keepAliveHint),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 0 || n > 3600 ? l10n.invalidNumber : null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _save,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap, this.tooltip});

  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color;
    final check = c == null || ThemeData.estimateBrightnessForColor(c) == Brightness.light ? Colors.black : Colors.white;
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onTap,
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
        ),
        child: selected
            ? Icon(Icons.check, size: 18, color: c == null ? scheme.primary : check)
            : (c == null ? Icon(Icons.block, size: 18, color: scheme.outline) : null),
      ),
    );
  }
}
