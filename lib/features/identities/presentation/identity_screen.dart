import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../ssh/presentation/dialog_prompter.dart';
import '../../ssh/domain/ssh_prompter.dart';
import '../data/identity_repository.dart';
import '../domain/key_import.dart';
import '../domain/key_material.dart';
import 'key_flows.dart';

/// One key: its public half (copy, share, QR, install on a server) and how the private half is protected.
class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key, required this.identityId});

  final String identityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final identity = ref.watch(identityProvider(identityId)).value;
    if (identity == null) return Scaffold(appBar: AppBar());
    final repo = ref.read(identityRepositoryProvider);
    final blob = _blob(identity.publicKey);
    final usedBy = (ref.watch(connectionsProvider).value ?? const <Connection>[])
        .where((c) => c.identityIdList.contains(identity.id))
        .toList();
    final mono = TextStyle(fontFamily: monoFont, fontSize: 12, color: theme.colorScheme.onSurface, fontFeatures: noLigatures);

    return Scaffold(
      appBar: AppBar(
        title: Text(identity.name),
        actions: [
          IconButton(
            tooltip: l10n.rename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, repo, identity),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, repo, identity, usedBy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Island(
            title: l10n.publicKey,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(identity.publicKey, style: mono),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: identity.publicKey));
                      showSnack(context, l10n.copied);
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.share),
                    onPressed: () => SharePlus.instance.share(ShareParams(text: identity.publicKey, subject: identity.name)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: Text(l10n.qrCode),
                    onPressed: () => _qr(context, identity),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: Text(l10n.installOnServer),
                subtitle: Text(l10n.installOnServerHint),
                onTap: () => installKeyOnServer(context, ref, identity),
              ),
            ],
          ),
          Island(
            title: l10n.fingerprint,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        '${keyTypeLabel(identity.algorithm)} ${identity.bits}\n${identity.fingerprint}'
                        '${blob == null ? '' : '\n${md5Fingerprint(blob)}'}',
                        style: mono,
                      ),
                    ),
                    if (blob != null) ...[
                      const SizedBox(width: 12),
                      Text(randomArt(blob), style: mono.copyWith(fontSize: 10, height: 1.1)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Island(
            title: l10n.protection,
            children: [
              ListTile(
                leading: Icon(identity.encrypted ? Icons.lock_outline : Icons.lock_open),
                title: Text(identity.encrypted ? l10n.keyHasPassphrase : l10n.keyNoPassphrase),
                subtitle: Text(l10n.keyStorageHint),
                trailing: TextButton(onPressed: () => _changePassphrase(context, ref, identity), child: Text(l10n.change)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                value: identity.requireBiometric,
                title: Text(l10n.requireUnlock),
                subtitle: Text(l10n.requireUnlockHint),
                onChanged: (v) async {
                  if (!await ref.read(sshPrompterProvider).authenticateUser(reason: identity.name)) return;
                  await repo.update(identity.id, requireBiometric: v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.output),
                title: Text(l10n.exportPrivateKey),
                subtitle: Text(l10n.exportPrivateKeyHint),
                onTap: () => exportPrivateKey(context, ref, identity),
              ),
            ],
          ),
          Island(
            title: l10n.usedBy,
            children: [
              if (usedBy.isEmpty) ListTile(title: Text(l10n.usedByNone)),
              for (final c in usedBy) ListTile(leading: const Icon(Icons.dns_outlined), title: Text(c.name), subtitle: Text(c.address)),
            ],
          ),
        ],
      ),
    );
  }

  static Uint8List? _blob(String publicLine) => PublicKeyLine.tryParse(publicLine)?.blob;

  Future<void> _qr(BuildContext context, Identity identity) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(identity.name),
          content: SizedBox(
            width: 280,
            height: 280,
            child: QrImageView(data: identity.publicKey, backgroundColor: Colors.white),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.close))],
        ),
      );

  Future<void> _rename(BuildContext context, IdentityRepository repo, Identity identity) async {
    final l10n = context.l10n;
    final text = TextEditingController(text: identity.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rename),
        content: TextField(controller: text, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: Text(l10n.save)),
        ],
      ),
    );
    text.dispose();
    if (name != null && name.trim().isNotEmpty) await repo.update(identity.id, name: name.trim());
  }

  Future<void> _delete(BuildContext context, IdentityRepository repo, Identity identity, List<Connection> usedBy) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteKeyTitle(identity.name)),
        content: Text(usedBy.isEmpty ? l10n.deleteKeyBody : l10n.deleteKeyUsed(usedBy.map((c) => c.name).join(', '))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.delete(identity.id);
    if (context.mounted) {
      showSnack(context, l10n.deleted(identity.name));
      context.pop();
    }
  }

  Future<void> _changePassphrase(BuildContext context, WidgetRef ref, Identity identity) async {
    final l10n = context.l10n;
    final repo = ref.read(identityRepositoryProvider);
    String? old;
    if (identity.encrypted) {
      final answer = await showDialog<SecretAnswer>(
        context: context,
        builder: (context) => SecretDialog(title: l10n.currentPassphrase, label: l10n.passphrase),
      );
      if (answer == null) return;
      old = answer.value;
    }
    if (!context.mounted) return;
    final next = await askNewPassphrase(context, title: l10n.newPassphrase);
    if (next == null) return;
    try {
      await repo.changePassphrase(identity.id, oldPassphrase: old, newPassphrase: next);
      ref.read(sshConnectorProvider).forgetUnlockedKeys();
      if (context.mounted) showSnack(context, next.isEmpty ? l10n.passphraseRemoved : l10n.passphraseChanged);
    } on KeyImportException catch (e) {
      if (context.mounted) showSnack(context, keyImportErrorText(l10n, e));
    }
  }
}
