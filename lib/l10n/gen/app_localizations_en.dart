// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get addHost => 'Add host';

  @override
  String get addKey => 'Add key';

  @override
  String addressVia(String address, String jump) {
    return '$address via $jump';
  }

  @override
  String get advanced => 'Advanced';

  @override
  String get algEcdsa =>
      'NIST curves. Use when a server or policy requires ECDSA.';

  @override
  String get algEd25519 =>
      'Small, fast and secure. Supported by every server from the last decade.';

  @override
  String get algRsa => 'For old servers. Generating takes a while on a phone.';

  @override
  String get appTitle => 'nux';

  @override
  String get appVersion => 'App version';

  @override
  String get appearance => 'Appearance';

  @override
  String get authentication => 'Sign in';

  @override
  String get authenticationHint =>
      'nux offers the checked keys in order, then the password, then asks the server what else it wants.';

  @override
  String get cancel => 'Cancel';

  @override
  String get change => 'Change';

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogOffline =>
      'GitHub is unreachable; showing the changelog of this version.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get close => 'Close';

  @override
  String get closeOtherTabs => 'Close other tabs';

  @override
  String get closeTab => 'Close tab';

  @override
  String get connect => 'Connect';

  @override
  String get continueAction => 'Continue';

  @override
  String get copied => 'Copied';

  @override
  String get copy => 'Copy';

  @override
  String get copyAll => 'Copy everything';

  @override
  String copyOf(String name) {
    return '$name (copy)';
  }

  @override
  String get currentPassphrase => 'Current passphrase';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConnectionBody =>
      'Its saved password is deleted too. Trusted host keys and SSH keys stay.';

  @override
  String deleteConnectionJumpers(String names) {
    return 'These hosts connect through it and will connect directly: $names';
  }

  @override
  String deleteConnectionTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteKeyBody =>
      'The private key is erased from this device. Unless you have a copy, it cannot be recovered.';

  @override
  String deleteKeyTitle(String name) {
    return 'Delete key $name?';
  }

  @override
  String deleteKeyUsed(String names) {
    return 'The private key is erased from this device and removed from these hosts: $names. Unless you have a copy, it cannot be recovered.';
  }

  @override
  String deleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get duplicateTab => 'New terminal on this host';

  @override
  String get edit => 'Edit';

  @override
  String get editHost => 'Edit host';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get exportPassphraseTitle => 'Passphrase for the exported key';

  @override
  String get exportPrivateKey => 'Export private key';

  @override
  String get exportPrivateKeyHint => 'As an encrypted OpenSSH file';

  @override
  String get exportPrivateKeyWarning =>
      'Anyone with this file and its passphrase can sign in wherever this key is accepted. Export only to move the key to a device you trust. You will choose a passphrase for the file next.';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get fontSize => 'Font size';

  @override
  String get forget => 'Forget';

  @override
  String get forgetHostBody =>
      'The next connection will show the server\'s key and ask you to trust it again.';

  @override
  String forgetHostTitle(String host) {
    return 'Forget the key of $host?';
  }

  @override
  String forgotten(String host) {
    return 'Forgot $host';
  }

  @override
  String get generate => 'Generate';

  @override
  String get generateKey => 'Generate a key';

  @override
  String get generateKeyHint => 'A new key pair made on this device';

  @override
  String get generating => 'Generating…';

  @override
  String get generatingRsa =>
      'Generating an RSA key. This can take a minute on a phone.';

  @override
  String get groupField => 'Group';

  @override
  String get hide => 'Hide';

  @override
  String get homeEarly =>
      'SSH, SFTP, port forwarding and a code editor are on their way. This early build sets up updates, so new features reach you as they land.';

  @override
  String get homeWelcome => 'Welcome to nux';

  @override
  String get hostField => 'Host';

  @override
  String hostKeyChangedBody(String host) {
    return '$host presented a different key than before. If the server was not reinstalled or reconfigured, someone may be intercepting the connection. Do not trust the new key unless you know why it changed.';
  }

  @override
  String get hostKeyChangedTitle => 'The server\'s key changed!';

  @override
  String get hostKeyCompareHint =>
      'On the server: ssh-keygen -lf /etc/ssh/ssh_host_*_key.pub';

  @override
  String hostKeyNewTypeBody(String host) {
    return '$host presented a key of a type you have not trusted for it before. This is usually harmless (for example after a server upgrade), but check the fingerprint.';
  }

  @override
  String get hostKeyNewTypeTitle => 'New key type';

  @override
  String get hostKeyPresented => 'Presented key';

  @override
  String get hostKeyTrust => 'Trust';

  @override
  String get hostKeyTrustNew => 'Trust the new key';

  @override
  String get hostKeyTrustedBefore => 'Trusted before';

  @override
  String hostKeyUnknownBody(String host) {
    return 'This is the first connection to $host. Check that the fingerprint below matches the server\'s before trusting it.';
  }

  @override
  String get hostKeyUnknownTitle => 'New server';

  @override
  String get hosts => 'Hosts';

  @override
  String get importAction => 'Import';

  @override
  String get importFormatsHint => 'OpenSSH, PEM, PKCS#8 or PuTTY (.ppk)';

  @override
  String get importFromClipboard => 'Paste from clipboard';

  @override
  String get importFromFile => 'Import from a file';

  @override
  String get importKey => 'Import a key';

  @override
  String get importKeyPassphraseTitle => 'This key has a passphrase';

  @override
  String get importKeyStaysEncrypted =>
      'nux will store it encrypted with the same passphrase.';

  @override
  String get importedKey => 'Imported key';

  @override
  String get installOnServer => 'Install on a server';

  @override
  String get installOnServerHint =>
      'Adds the public key to ~/.ssh/authorized_keys over an existing login (like ssh-copy-id)';

  @override
  String installingKey(String name) {
    return 'Installing the key on $name…';
  }

  @override
  String get invalidNumber => 'Enter a number';

  @override
  String get invalidPort => '1–65535';

  @override
  String get jumpHost => 'Jump host';

  @override
  String get jumpHostHint =>
      'Connect through another saved host (like ProxyJump)';

  @override
  String get keepAlive => 'Keep-alive, seconds';

  @override
  String get keepAliveHint =>
      'Pings the server so idle connections are not dropped. 0 turns it off.';

  @override
  String get keepPassphrase => 'Keep the key protected with this passphrase';

  @override
  String keyAlreadyImported(String name) {
    return 'This key is already here as $name';
  }

  @override
  String get keyComment => 'Comment';

  @override
  String get keyCommentHint =>
      'Shown at the end of the public key; helps you recognise it on servers';

  @override
  String get keyHasPassphrase => 'Protected with a passphrase';

  @override
  String keyInstalled(String name) {
    return 'Installed on $name';
  }

  @override
  String get keyInvalid => 'This is not a private key nux can read';

  @override
  String get keyIsPublic =>
      'This is a public key. Import the private key (the file without .pub).';

  @override
  String get keyNameHint => 'e.g. Phone';

  @override
  String get keyNeedsPassphrase => 'This key needs its passphrase';

  @override
  String get keyNeedsUnlock => 'Device unlock required';

  @override
  String get keyNoPassphrase => 'No passphrase';

  @override
  String keyNowUsed(String name) {
    return '$name now signs in with this key first';
  }

  @override
  String get keyStorageHint =>
      'The private key is kept in the device\'s secure storage';

  @override
  String get keyType => 'Type';

  @override
  String keyUnsupported(String detail) {
    return 'Unsupported key: $detail';
  }

  @override
  String keyWasInstalled(String name) {
    return '$name already accepts this key';
  }

  @override
  String get keys => 'Keys';

  @override
  String get knownHosts => 'Known hosts';

  @override
  String get knownHostsEmpty =>
      'No trusted servers yet. A server\'s key is saved here when you trust it on the first connection.';

  @override
  String get knownHostsHint =>
      'Keys of servers you trusted. nux warns when a server presents a different key.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String lastSeen(String date) {
    return 'Last seen $date';
  }

  @override
  String get later => 'Later';

  @override
  String get licenses => 'Licenses';

  @override
  String get more => 'More';

  @override
  String get nameField => 'Name';

  @override
  String get newPassphrase => 'New passphrase';

  @override
  String get newTab => 'New tab';

  @override
  String get noColor => 'No colour';

  @override
  String get noHosts => 'No hosts yet';

  @override
  String get noHostsHint =>
      'Add a server to connect to, or type user@host to connect right away.';

  @override
  String get noKeysHint =>
      'Keys let you sign in without a password. Generate one here, or import a key you already use.';

  @override
  String get noKeysYet => 'No keys yet';

  @override
  String get noPreview => 'No preview';

  @override
  String get noTabs => 'No open tabs';

  @override
  String get noTabsHint => 'Open the hosts list or connect to a server.';

  @override
  String get none => 'None';

  @override
  String get notNow => 'Not now';

  @override
  String get ok => 'OK';

  @override
  String get openReleasePage => 'Open release page';

  @override
  String get openTerminal => 'Open terminal';

  @override
  String get organize => 'Organize';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get passphraseChanged => 'Passphrase changed';

  @override
  String get passphraseOptionalHint => 'Optional. Asked when the key is used.';

  @override
  String get passphraseRemoved => 'Passphrase removed';

  @override
  String get passphraseWrong => 'Wrong passphrase';

  @override
  String get passphrasesDiffer => 'The passphrases differ';

  @override
  String get password => 'Password';

  @override
  String passwordFor(String address) {
    return 'Password for $address';
  }

  @override
  String get passwordKeepHint => 'A password is saved. Leave empty to keep it.';

  @override
  String get passwordWrong => 'The server did not accept the password';

  @override
  String get paste => 'Paste';

  @override
  String get pinTab => 'Pin';

  @override
  String get pinnedTabs => 'Pinned';

  @override
  String get portField => 'Port';

  @override
  String get predictiveBack => 'Predictive back gesture';

  @override
  String get predictiveBackHint => 'The page follows your back swipe';

  @override
  String get protection => 'Protection';

  @override
  String get publicKey => 'Public key';

  @override
  String get qrCode => 'QR code';

  @override
  String get quickConnect => 'Quick connect';

  @override
  String get quickConnectHint => 'Saved to hosts, offering all your keys';

  @override
  String get recommended => 'recommended';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get rememberUntilClosed => 'Remember until nux is closed';

  @override
  String get rename => 'Rename';

  @override
  String get repeatPassphrase => 'Repeat passphrase';

  @override
  String get requireUnlock => 'Require device unlock';

  @override
  String get requireUnlockHint =>
      'Fingerprint, face or screen lock before each use';

  @override
  String get required => 'Required';

  @override
  String get save => 'Save';

  @override
  String get saveAndConnect => 'Save and connect';

  @override
  String get savePassword => 'Save password';

  @override
  String get savePasswordHint => 'Kept in the device\'s secure storage';

  @override
  String get searchHosts => 'Search hosts';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get show => 'Show';

  @override
  String get showTabs => 'Show tabs';

  @override
  String get skipKey => 'Skip this key';

  @override
  String get sourceCode => 'Source code';

  @override
  String get ssh => 'SSH';

  @override
  String get sshAuthFailed =>
      'The server refused the keys and password offered';

  @override
  String get sshCancelled => 'Cancelled';

  @override
  String get sshConnectionMissing => 'This host was deleted';

  @override
  String get sshHostKeyRejected => 'The server\'s key was not trusted';

  @override
  String sshOtherError(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String sshUnreachable(String detail) {
    return 'Could not reach the server: $detail';
  }

  @override
  String sshVia(String error, String via) {
    return '$error (through $via)';
  }

  @override
  String tabClosed(String title) {
    return 'Closed $title';
  }

  @override
  String get terminal => 'Terminal';

  @override
  String terminalConnecting(String address) {
    return 'Connecting to $address…';
  }

  @override
  String get terminalDisconnected => 'Disconnected';

  @override
  String get terminalPressEnter => 'Press Enter to reconnect';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get undo => 'Undo';

  @override
  String unlockKey(String name) {
    return 'Unlock $name';
  }

  @override
  String unlockKeyReason(String name) {
    return 'Use the key $name';
  }

  @override
  String get unpinTab => 'Unpin';

  @override
  String get upToDate => 'You have the latest version';

  @override
  String get update => 'Update';

  @override
  String updateAvailable(String version) {
    return 'nux $version is available';
  }

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String updateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get updateInstalling => 'Opening the installer…';

  @override
  String get updatePermission => 'Allow nux to install apps, then try again';

  @override
  String updateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get updatesAuto => 'Check for updates automatically';

  @override
  String get updatesBeta => 'Beta versions';

  @override
  String get updatesBetaHint =>
      'Also offer pre-releases. They may be unstable.';

  @override
  String get useKey => 'Use this key';

  @override
  String useKeyFor(String name) {
    return 'Sign in to $name with this key from now on?';
  }

  @override
  String get usedBy => 'Used by';

  @override
  String get usedByNone => 'No host uses this key yet';

  @override
  String get usernameField => 'Username';

  @override
  String get whatsNew => 'What\'s new';
}
