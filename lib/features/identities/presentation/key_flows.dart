import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nux_backend/nux_backend.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_backend.dart';
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../ssh/presentation/dialog_prompter.dart';
import '../../ssh/domain/ssh_prompter.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../data/identity_repository.dart';
import '../domain/key_import.dart';
import '../domain/key_material.dart';

String keyImportErrorText(AppLocalizations l10n, KeyImportException e) => switch (e.error) {
  KeyImportError.needsPassphrase => l10n.keyNeedsPassphrase,
  KeyImportError.wrongPassphrase => l10n.passphraseWrong,
  KeyImportError.publicKeyOnly => l10n.keyIsPublic,
  KeyImportError.unsupported => l10n.keyUnsupported(e.detail ?? ''),
  KeyImportError.invalid => l10n.keyInvalid,
};

/// Imports a private key from a file the user picks.
Future<void> importKeyFromFile(BuildContext context, WidgetRef ref) async {
  final file = await FilePicker.pickFile();
  if (file == null || !context.mounted) return;
  final bytes = await file.xFile.readAsBytes();
  if (!context.mounted) return;
  await importKeyText(context, ref, utf8.decode(bytes, allowMalformed: true), suggestedName: file.name);
}

/// Imports a private key from the clipboard.
Future<void> importKeyFromClipboard(BuildContext context, WidgetRef ref) async {
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (!context.mounted) return;
  if (text == null || text.trim().isEmpty) return showSnack(context, context.l10n.clipboardEmpty);
  await importKeyText(context, ref, text);
}

/// Reads [text] (asking for its passphrase if needed), lets the user name it and saves it.
Future<void> importKeyText(BuildContext context, WidgetRef ref, String text, {String? suggestedName}) async {
  final l10n = context.l10n;
  KeyMaterial? key;
  String? passphrase;
  final encrypted = isKeyEncrypted(text);
  for (var retry = false; key == null; retry = true) {
    if (encrypted) {
      final answer = await showDialog<SecretAnswer>(
        context: context,
        builder: (context) => SecretDialog(
          title: l10n.importKeyPassphraseTitle,
          error: retry ? l10n.passphraseWrong : null,
          label: l10n.passphrase,
          rememberLabel: l10n.keepPassphrase,
          rememberDefault: true,
        ),
      );
      if (answer == null || !context.mounted) return;
      passphrase = answer.remember ? answer.value : null;
      try {
        key = importPrivateKey(text, passphrase: answer.value);
      } on KeyImportException catch (e) {
        if (e.error != KeyImportError.wrongPassphrase) return showSnack(context, keyImportErrorText(l10n, e));
      }
    } else {
      try {
        key = importPrivateKey(text);
      } on KeyImportException catch (e) {
        return showSnack(context, keyImportErrorText(l10n, e));
      }
    }
  }

  final repo = ref.read(identityRepositoryProvider);
  final fingerprint = sha256Fingerprint(key.publicBlob);
  final existing = (await repo.all()).where((i) => i.fingerprint == fingerprint).firstOrNull;
  if (!context.mounted) return;
  if (existing != null) {
    showSnack(context, l10n.keyAlreadyImported(existing.name));
    context.push(Routes.key(existing.id));
    return;
  }
  final name = TextEditingController(text: key.comment.isNotEmpty ? key.comment : (suggestedName ?? l10n.importedKey));
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.nameField),
          ),
          const SizedBox(height: 12),
          Text(
            '${keyTypeLabel(key!.algorithm)} ${key.bits}\n$fingerprint',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (passphrase != null) ...[
            const SizedBox(height: 8),
            Text(l10n.importKeyStaysEncrypted, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.importAction)),
      ],
    ),
  );
  final keyName = name.text.trim();
  name.dispose();
  if (ok != true) return;
  final id = await repo.add(key, name: keyName.isEmpty ? l10n.importedKey : keyName, passphrase: passphrase);
  if (context.mounted) context.pushReplacement(Routes.key(id));
}

/// Appends the key to `~/.ssh/authorized_keys` on a host the user picks (like `ssh-copy-id`).
/// [onProgress] gets the host while installing and null when done (the caller shows the progress);
/// the result is a snackbar, with "Use key" when the host does not use this key yet.
Future<void> installKeyOnServer(
  BuildContext context,
  WidgetRef ref,
  Identity identity, {
  void Function(Connection? installingOn)? onProgress,
}) async {
  final l10n = context.l10n;
  final connections = await ref.read(connectionRepositoryProvider).all();
  if (!context.mounted) return;
  if (connections.isEmpty) return showSnack(context, l10n.noHosts);
  final target = await showDialog<Connection>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.installOnServer),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(l10n.installOnServerHint)),
        for (final c in connections)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, c),
            child: ListTile(title: Text(c.name), subtitle: Text(c.address)),
          ),
      ],
    ),
  );
  if (target == null || !context.mounted) return;

  final line = identity.publicKey.trim();
  final q = shellQuote(line);
  final script =
      'umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && '
      '(grep -qxF $q ~/.ssh/authorized_keys && echo nux:present || (echo $q >> ~/.ssh/authorized_keys && echo nux:added))';
  final messenger = ScaffoldMessenger.of(context);
  final connectionRepo = ref.read(connectionRepositoryProvider);
  onProgress?.call(target);
  try {
    final lease = await ref.read(sshPoolProvider).acquire(target.id, ref.read(sshPrompterProvider));
    try {
      final result = await SshBackend(
        id: target.id,
        displayName: target.name,
        client: lease.client,
      ).processRunner.run(script);
      if (!result.ok) throw SshConnectException(SshFailure.other, result.stderr.trim());
      final already = result.stdout.contains('nux:present');
      final usesIt = target.identityIdList.firstOrNull == identity.id;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(already ? l10n.keyWasInstalled(target.name) : l10n.keyInstalled(target.name)),
            duration: const Duration(seconds: 8),
            action: usesIt
                ? null
                : SnackBarAction(
                    label: l10n.useKey,
                    onPressed: () async {
                      await connectionRepo.preferIdentity(target.id, identity.id);
                      messenger.showSnackBar(SnackBar(content: Text(l10n.keyNowUsed(target.name))));
                    },
                  ),
          ),
        );
    } finally {
      lease.release();
    }
  } on SshConnectException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(sshErrorText(l10n, e))));
  } finally {
    onProgress?.call(null);
  }
}

/// Exports the private key, always encrypted with a new passphrase, after a warning and a device unlock.
Future<void> exportPrivateKey(BuildContext context, WidgetRef ref, Identity identity) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
      title: Text(l10n.exportPrivateKey),
      content: Text(l10n.exportPrivateKeyWarning),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.continueAction)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (!await ref.read(sshPrompterProvider).authenticateUser(reason: identity.name)) return;
  if (!context.mounted) return;

  final repo = ref.read(identityRepositoryProvider);
  KeyMaterial? key;
  if (identity.encrypted) {
    for (var retry = false; key == null; retry = true) {
      if (!context.mounted) return;
      final answer = await showDialog<SecretAnswer>(
        context: context,
        builder: (context) => SecretDialog(
          title: l10n.unlockKey(identity.name),
          error: retry ? l10n.passphraseWrong : null,
          label: l10n.passphrase,
        ),
      );
      if (answer == null || !context.mounted) return;
      try {
        key = await repo.unlock(identity.id, passphrase: answer.value);
      } on KeyImportException catch (e) {
        if (e.error != KeyImportError.wrongPassphrase) rethrow;
      }
    }
  } else {
    key = await repo.unlock(identity.id);
  }
  if (!context.mounted) return;
  final exportPass = await askNewPassphrase(context, title: l10n.exportPassphraseTitle, required: true);
  if (exportPass == null) return;
  final pem = key.toOpenSsh(passphrase: exportPass);
  final fileName =
      'id_${keyTypeLabel(identity.algorithm).toLowerCase()}_${identity.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_')}';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode(pem)), mimeType: 'text/plain', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
}

/// Asks for a new passphrase twice. Returns '' when the user chose none (unless [required]).
Future<String?> askNewPassphrase(BuildContext context, {required String title, bool required = false}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NewPassphraseDialog(title: title, required: required),
  );
}

class _NewPassphraseDialog extends StatefulWidget {
  const _NewPassphraseDialog({required this.title, required this.required});

  final String title;
  final bool required;

  @override
  State<_NewPassphraseDialog> createState() => _NewPassphraseDialogState();
}

class _NewPassphraseDialogState extends State<_NewPassphraseDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    if (widget.required && _a.text.isEmpty) return setState(() => _error = l10n.required);
    if (_a.text != _b.text) return setState(() => _error = l10n.passphrasesDiffer);
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _a,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.newPassphrase,
              helperText: widget.required ? null : l10n.passphraseOptionalHint,
            ),
          ),
          TextField(
            controller: _b,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.repeatPassphrase, errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
