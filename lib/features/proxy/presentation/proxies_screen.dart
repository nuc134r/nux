import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../data/proxy_repository.dart';
import '../domain/socks5.dart';

/// Saved SOCKS5 proxies; each says what goes through it.
class ProxiesScreen extends ConsumerWidget {
  const ProxiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final proxies = ref.watch(proxiesProvider).value ?? const <Proxy>[];
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final zerotier = ref.watch(zeroTierServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.proxies)),
      bottomNavigationBar: AddBar(label: l10n.addProxy, onPressed: () => context.push(Routes.newProxy)),
      body: proxies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(l10n.noProxiesYet, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(l10n.noProxiesHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListenableBuilder(
              listenable: zerotier,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final p in proxies)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.alt_route)),
                      title: Text(p.name),
                      subtitle: Text(
                        [
                          'SOCKS5 · ${p.address}',
                          [
                            l10n.proxyUsedBy(connections.where((c) => c.proxyId == p.id).length),
                            if (zerotier.proxyId == p.id) 'ZeroTier',
                          ].join(' · '),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      onTap: () => context.push(Routes.proxy(p.id)),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Adds or edits a proxy, and chooses what goes through it: ZeroTier and any of the hosts.
class ProxyEditorScreen extends ConsumerStatefulWidget {
  const ProxyEditorScreen({super.key, this.proxyId});

  final String? proxyId;

  @override
  ConsumerState<ProxyEditorScreen> createState() => _ProxyEditorScreenState();
}

class _ProxyEditorScreenState extends ConsumerState<ProxyEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '1080');
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _hasSavedPassword = false;
  bool _passwordVisible = false;
  bool _loaded = false;
  bool _testing = false;
  bool _zerotier = false;

  /// Hosts that go through this proxy (edited here, saved with it).
  Set<String> _hosts = {};
  Proxy? _original;

  bool get _isNew => widget.proxyId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.proxyId;
    if (id != null) {
      final repo = ref.read(proxyRepositoryProvider);
      final p = await repo.get(id);
      if (p != null) {
        _original = p;
        _name.text = p.name;
        _host.text = p.host;
        _port.text = '${p.port}';
        _user.text = p.username;
        _hasSavedPassword = await repo.hasPassword(id);
        _hosts = {for (final c in await repo.usedBy(id)) c.id};
        _zerotier = ref.read(zeroTierServiceProvider).proxyId == id;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The proxy as typed (the saved password when none was typed).
  Future<Socks5Proxy> _typed() async {
    final user = _user.text.trim();
    var password = _password.text;
    if (password.isEmpty && _hasSavedPassword && widget.proxyId != null) {
      password = (await ref.read(proxyRepositoryProvider).resolve(widget.proxyId!))?.password ?? '';
    }
    return Socks5Proxy(
      _host.text.trim(),
      int.tryParse(_port.text.trim()) ?? 1080,
      username: user.isEmpty ? null : user,
      password: user.isEmpty ? null : password,
    );
  }

  Future<void> _test() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _testing = true);
    String message;
    try {
      final r = await socks5Check(await _typed());
      message = r.udp ? l10n.proxyWorksUdp : l10n.proxyWorksTcpOnly;
    } catch (e) {
      message = l10n.proxyFailed(proxyErrorText(e));
    }
    if (!mounted) return;
    setState(() => _testing = false);
    showSnack(context, message);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(proxyRepositoryProvider);
    final connections = ref.read(connectionRepositoryProvider);
    final zerotier = ref.read(zeroTierServiceProvider);
    final now = DateTime.now();
    final host = _host.text.trim();
    final user = _user.text.trim();
    final id = await repo.save(
      ProxiesCompanion(
        id: _isNew ? const Value.absent() : Value(widget.proxyId!),
        name: Value(_name.text.trim().isEmpty ? host : _name.text.trim()),
        host: Value(host),
        port: Value(int.parse(_port.text.trim())),
        username: Value(user),
        createdAt: _isNew ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
      ),
      // No login, no password; an empty field keeps the saved one.
      password: user.isEmpty ? '' : (_password.text.isEmpty ? null : _password.text),
    );
    for (final c in await connections.all()) {
      final wanted = _hosts.contains(c.id);
      if (wanted != (c.proxyId == id)) {
        await connections.save(ConnectionsCompanion(id: Value(c.id), proxyId: Value(wanted ? id : null)));
      }
    }
    if (_zerotier) {
      // Applies the edited address and login too.
      zerotier.proxyId == id ? await zerotier.proxyChanged(id) : await zerotier.setProxy(id);
    } else if (zerotier.proxyId == id) {
      await zerotier.setProxy(null);
    }
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final p = _original!;
    final zerotier = ref.read(zeroTierServiceProvider);
    final users = [
      for (final c in await ref.read(proxyRepositoryProvider).usedBy(p.id)) c.name,
      if (zerotier.proxyId == p.id) 'ZeroTier',
    ];
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProxyTitle(p.name)),
        content: Text(users.isEmpty ? l10n.deleteProxyBody : l10n.deleteProxyUsed(users.join(', '))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(proxyRepositoryProvider).delete(p.id);
    if (zerotier.proxyId == p.id) await zerotier.setProxy(null);
    if (!mounted) return;
    showSnack(context, l10n.deleted(p.name));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    // Hosts on a ZeroTier network go through the node; hosts behind a jump host through that host.
    final eligible = connections.where((c) => c.zerotierNetwork == null && c.jumpHostId == null).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addProxy : l10n.editProxy),
        actions: [
          NuxMenuButton(
            tooltip: l10n.more,
            items: (context) => [
              NuxMenuAction(icon: Icons.network_check, label: l10n.proxyTest, enabled: !_testing, onSelected: _test),
              if (!_isNew && _original != null) ...[
                const NuxMenuDivider(),
                NuxMenuAction(icon: Icons.delete_outline, label: l10n.delete, onSelected: _delete),
              ],
            ],
          ),
        ],
        bottom: _testing
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
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
                          decoration: InputDecoration(labelText: l10n.hostField, hintText: 'proxy.example.com'),
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
                    decoration: InputDecoration(labelText: l10n.usernameField, helperText: l10n.proxyLoginHint),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_user.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l10n.nameField, hintText: _host.text.trim()),
                  ),
                  SectionTitle(l10n.proxyUseFor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.lan_outlined),
                    value: _zerotier,
                    onChanged: (v) => setState(() => _zerotier = v),
                    title: Text(l10n.proxyForZeroTier),
                    subtitle: Text(l10n.proxyForZeroTierHint),
                  ),
                  if (eligible.isEmpty)
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.dns_outlined), title: Text(l10n.proxyNoHosts)),
                  for (final c in eligible)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _hosts.contains(c.id),
                      onChanged: (v) => setState(() => v == true ? _hosts.add(c.id) : _hosts.remove(c.id)),
                      secondary: const Icon(Icons.dns_outlined),
                      title: Text(c.name),
                      subtitle: Text(c.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  Text(l10n.proxyHostsHint, style: theme.textTheme.bodySmall),
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
