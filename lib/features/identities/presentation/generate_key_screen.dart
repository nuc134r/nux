import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../ssh/data/ssh_providers.dart';
import '../data/device_name.dart';
import '../data/identity_repository.dart';
import '../domain/key_generator.dart';
import '../domain/key_material.dart';

class GenerateKeyScreen extends ConsumerStatefulWidget {
  const GenerateKeyScreen({super.key});

  @override
  ConsumerState<GenerateKeyScreen> createState() => _GenerateKeyScreenState();
}

class _GenerateKeyScreenState extends ConsumerState<GenerateKeyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _comment = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  KeyAlgorithm _algorithm = KeyAlgorithm.ed25519;
  bool _biometric = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(deviceNameProvider.future).then((device) {
      if (mounted && _comment.text.isEmpty) _comment.text = 'nux@$device';
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _comment, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    if (_biometric && !await ref.read(sshPrompterProvider).authenticateUser(reason: _name.text)) return;
    setState(() => _busy = true);
    try {
      final key = await generateKey(_algorithm, comment: _comment.text.trim());
      final id = await ref.read(identityRepositoryProvider).add(
            key,
            name: _name.text.trim().isEmpty ? keyTypeLabel(key.algorithm) : _name.text.trim(),
            passphrase: _pass.text,
            requireBiometric: _biometric,
          );
      if (mounted) context.pushReplacement(Routes.key(id));
    } catch (e) {
      if (mounted) showSnack(context, l10n.errorGeneric('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String describe(KeyAlgorithm a) => switch (a) {
          KeyAlgorithm.ed25519 => l10n.algEd25519,
          KeyAlgorithm.ecdsaP256 || KeyAlgorithm.ecdsaP384 || KeyAlgorithm.ecdsaP521 => l10n.algEcdsa,
          KeyAlgorithm.rsa3072 || KeyAlgorithm.rsa4096 => l10n.algRsa,
        };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.generateKey)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.nameField, hintText: l10n.keyNameHint),
            ),
            SectionTitle(l10n.keyType),
            RadioGroup<KeyAlgorithm>(
              groupValue: _algorithm,
              onChanged: (v) => setState(() => _algorithm = v ?? _algorithm),
              child: Column(
                children: [
                  for (final a in KeyAlgorithm.values)
                    RadioListTile<KeyAlgorithm>(
                      contentPadding: EdgeInsets.zero,
                      value: a,
                      title: Text('${keyTypeLabel(a.sshName)} ${a.bits}${a == KeyAlgorithm.ed25519 ? ' · ${l10n.recommended}' : ''}'),
                      subtitle: Text(describe(a)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _comment,
              decoration: InputDecoration(labelText: l10n.keyComment, helperText: l10n.keyCommentHint, helperMaxLines: 3),
            ),
            SectionTitle(l10n.protection),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.passphrase, helperText: l10n.passphraseOptionalHint),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass2,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.repeatPassphrase),
              validator: (v) => v != _pass.text ? l10n.passphrasesDiffer : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _biometric,
              onChanged: (v) => setState(() => _biometric = v),
              title: Text(l10n.requireUnlock),
              subtitle: Text(l10n.requireUnlockHint),
            ),
            const SizedBox(height: 16),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_algorithm.sshName == 'ssh-rsa' ? l10n.generatingRsa : l10n.generating, style: theme.textTheme.bodySmall),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(icon: const Icon(Icons.auto_awesome), label: Text(l10n.generate), onPressed: _generate),
              ),
          ],
        ),
      ),
    );
  }
}
