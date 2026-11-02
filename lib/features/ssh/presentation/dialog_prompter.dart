import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../connections/domain/host_key_check.dart';
import '../domain/ssh_prompter.dart';

/// Answers the SSH layer's questions with dialogs over whatever screen is showing.
class DialogSshPrompter implements SshPrompter {
  DialogSshPrompter(this._navigator, {LocalAuthentication? localAuth}) : _auth = localAuth ?? LocalAuthentication();

  final GlobalKey<NavigatorState> _navigator;
  final LocalAuthentication _auth;

  BuildContext? get _context => _navigator.currentContext;

  @override
  Future<bool> confirmHostKey(HostKeyQuestion q) async {
    final context = _context;
    if (context == null) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => HostKeyDialog(question: q),
        ) ??
        false;
  }

  @override
  Future<SecretAnswer?> password({required String connectionName, required String address, required bool retry}) async {
    final context = _context;
    if (context == null) return null;
    final l10n = context.l10n;
    return showDialog<SecretAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SecretDialog(
        title: l10n.passwordFor(address),
        error: retry ? l10n.passwordWrong : null,
        label: l10n.password,
        rememberLabel: l10n.savePassword,
        rememberDefault: false,
      ),
    );
  }

  @override
  Future<SecretAnswer?> passphrase({required String identityName, required bool retry}) async {
    final context = _context;
    if (context == null) return null;
    final l10n = context.l10n;
    return showDialog<SecretAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SecretDialog(
        title: l10n.unlockKey(identityName),
        error: retry ? l10n.passphraseWrong : null,
        label: l10n.passphrase,
        rememberLabel: l10n.rememberUntilClosed,
        rememberDefault: true,
        skipLabel: l10n.skipKey,
      ),
    );
  }

  @override
  Future<List<String>?> keyboardInteractive({
    required String address,
    required String name,
    required String instruction,
    required List<KeyboardInteractivePrompt> prompts,
  }) async {
    final context = _context;
    if (context == null) return null;
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _KeyboardInteractiveDialog(address: address, name: name, instruction: instruction, prompts: prompts),
    );
  }

  @override
  Future<bool> authenticateUser({required String reason}) async {
    final context = _context;
    final text = context == null ? reason : context.l10n.unlockKeyReason(reason);
    try {
      if (!await _auth.isDeviceSupported()) return true; // no lock screen at all: nothing to check
      return await _auth.authenticate(localizedReason: text, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

class HostKeyDialog extends StatelessWidget {
  const HostKeyDialog({super.key, required this.question});

  final HostKeyQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = question;
    final where = q.port == 22 ? q.host : '${q.host}:${q.port}';
    final changed = q.status == HostKeyStatus.changed;
    final mono = TextStyle(fontFamily: monoFont, fontSize: 13, color: theme.colorScheme.onSurface, fontFeatures: noLigatures);
    return AlertDialog(
      icon: Icon(changed ? Icons.gpp_bad : Icons.verified_user_outlined, color: changed ? theme.colorScheme.error : null),
      title: Text(switch (q.status) {
        HostKeyStatus.changed => l10n.hostKeyChangedTitle,
        HostKeyStatus.newKeyType => l10n.hostKeyNewTypeTitle,
        _ => l10n.hostKeyUnknownTitle,
      }),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (q.status) {
              HostKeyStatus.changed => l10n.hostKeyChangedBody(where),
              HostKeyStatus.newKeyType => l10n.hostKeyNewTypeBody(where),
              _ => l10n.hostKeyUnknownBody(where),
            }),
            const SizedBox(height: 12),
            Text(l10n.hostKeyPresented, style: theme.textTheme.labelMedium),
            SelectableText('${q.keyType}\n${q.fingerprint}', style: mono),
            if (q.knownFingerprints.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.hostKeyTrustedBefore, style: theme.textTheme.labelMedium),
              SelectableText(q.knownFingerprints.join('\n'), style: mono),
            ],
            const SizedBox(height: 12),
            Text(l10n.hostKeyCompareHint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        if (changed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.hostKeyTrustNew),
          )
        else
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.hostKeyTrust)),
      ],
    );
  }
}

/// Asks for a password or passphrase, with a "remember" checkbox.
class SecretDialog extends StatefulWidget {
  const SecretDialog({
    super.key,
    required this.title,
    required this.label,
    this.rememberLabel,
    this.rememberDefault = false,
    this.error,
    this.skipLabel,
    this.confirmLabel,
  });

  final String title;
  final String label;
  /// The "remember" checkbox's text; no checkbox when null.
  final String? rememberLabel;
  final bool rememberDefault;
  final String? error;

  /// Shown instead of "Cancel" when skipping is possible (e.g. try the next key).
  final String? skipLabel;
  final String? confirmLabel;

  @override
  State<SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<SecretDialog> {
  final _text = TextEditingController();
  late bool _remember = widget.rememberDefault;
  bool _visible = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, SecretAnswer(_text.text, remember: _remember));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: widget.error,
              suffixIcon: IconButton(
                tooltip: _visible ? l10n.hide : l10n.show,
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          if (widget.rememberLabel case final label?)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text(label),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.skipLabel ?? l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel ?? l10n.ok)),
      ],
    );
  }
}

class _KeyboardInteractiveDialog extends StatefulWidget {
  const _KeyboardInteractiveDialog({required this.address, required this.name, required this.instruction, required this.prompts});

  final String address;
  final String name;
  final String instruction;
  final List<KeyboardInteractivePrompt> prompts;

  @override
  State<_KeyboardInteractiveDialog> createState() => _KeyboardInteractiveDialogState();
}

class _KeyboardInteractiveDialogState extends State<_KeyboardInteractiveDialog> {
  late final _fields = [for (final _ in widget.prompts) TextEditingController()];

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() => Navigator.pop(context, [for (final f in _fields) f.text]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.name.isEmpty ? widget.address : widget.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.instruction.isNotEmpty) Text(widget.instruction),
            for (final (i, p) in widget.prompts.indexed)
              TextField(
                controller: _fields[i],
                autofocus: i == 0,
                obscureText: !p.echo,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: p.text.trim()),
                onSubmitted: i == widget.prompts.length - 1 ? (_) => _submit() : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
