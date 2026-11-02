import '../../../l10n/l10n.dart';
import '../data/ssh_connector.dart';

/// What went wrong, in words for people.
String sshErrorText(AppLocalizations l10n, SshConnectException e) {
  final text = switch (e.failure) {
    SshFailure.unreachable => l10n.sshUnreachable(e.message),
    SshFailure.hostKeyRejected => l10n.sshHostKeyRejected,
    SshFailure.authFailed => l10n.sshAuthFailed,
    SshFailure.cancelled => l10n.sshCancelled,
    SshFailure.notFound => l10n.sshConnectionMissing,
    SshFailure.other => l10n.sshOtherError(e.message),
  };
  return e.via == null ? text : l10n.sshVia(text, e.via!);
}
