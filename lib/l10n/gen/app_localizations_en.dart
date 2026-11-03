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
  String get addForward => 'Add forwarding';

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
  String allRules(int count) {
    return 'All ($count)';
  }

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
  String get bookmarkFolder => 'Bookmark this folder';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get cancel => 'Cancel';

  @override
  String get change => 'Change';

  @override
  String get changedOnServer => 'Changed on the server';

  @override
  String changedOnServerBody(String name) {
    return '$name was changed on the server after you opened it. Overwrite it with your version, or discard your changes and load the new one?';
  }

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogOffline =>
      'GitHub is unreachable; showing the changelog of this version.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get clearFinished => 'Clear finished';

  @override
  String get clearSelection => 'Clear selection';

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
  String get copyPath => 'Copy path';

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
  String deleteFileTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteFilesBody =>
      'Folders are deleted with everything inside. This cannot be undone.';

  @override
  String deleteFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete $count item?',
    );
    return '$_temp0';
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
  String get devicePort => 'Port on this device';

  @override
  String get discard => 'Discard';

  @override
  String get discardChangesBody => 'The changes you made have not been saved.';

  @override
  String discardChangesTitle(String name) {
    return 'Discard changes to $name?';
  }

  @override
  String get discardMine => 'Discard mine';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get download => 'Download';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get duplicateTab => 'New terminal on this host';

  @override
  String get edit => 'Edit';

  @override
  String get editForward => 'Edit forwarding';

  @override
  String get editHost => 'Edit host';

  @override
  String get editorFontSize => 'File text size';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String explainDynamic(String port, String host) {
    return 'A SOCKS5 proxy on localhost:$port: apps that use it go out to the internet through $host.';
  }

  @override
  String explainDynamicShared(String port, String host) {
    return 'A SOCKS5 proxy on this device\'s port $port, open to your network: everything goes out through $host.';
  }

  @override
  String explainLocal(String port, String target, String host) {
    return 'Apps on this device connect to localhost:$port and reach $target as seen from $host.';
  }

  @override
  String explainLocalShared(String port, String target, String host) {
    return 'Devices on your network connect to this device\'s port $port and reach $target as seen from $host.';
  }

  @override
  String explainRemote(String host, String port, String target) {
    return 'Programs on $host connect to its port $port and reach $target as seen from this device.';
  }

  @override
  String explainZeroTierTcp(String port, String target, String network) {
    return 'Apps on this device connect to localhost:$port and reach $target in ZeroTier network $network. No SSH involved.';
  }

  @override
  String explainZeroTierUdp(String port, String target, String network) {
    return 'UDP packets sent to localhost:$port go to $target in ZeroTier network $network, and replies come back. Good for games, DNS, VoIP.';
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
  String get fileDisconnected => 'The connection was lost';

  @override
  String get fileExists => 'Something with this name already exists';

  @override
  String get fileNotFound => 'Not found';

  @override
  String get filePermissionDenied => 'Permission denied';

  @override
  String get find => 'Find';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get folderEmpty => 'This folder is empty';

  @override
  String get folderNotEmpty => 'The folder is not empty';

  @override
  String folderOnlyHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count hidden items here',
      one: 'Only $count hidden item here',
    );
    return '$_temp0';
  }

  @override
  String get folderPath => 'Folder';

  @override
  String get foldersNotDownloaded =>
      'Folders are not downloaded yet; only the files were queued';

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
  String get forwardActive => 'Active';

  @override
  String forwardActiveConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Active · $count connections so far',
      one: 'Active · $count connection so far',
    );
    return '$_temp0';
  }

  @override
  String forwardActiveTraffic(int open, String bytesIn, String bytesOut) {
    return 'Active · $open open · ↓ $bytesIn ↑ $bytesOut';
  }

  @override
  String get forwardAutoStart => 'Start when nux starts';

  @override
  String forwardBindDenied(int port) {
    return 'This device does not allow listening on port $port';
  }

  @override
  String forwardConflict(String name) {
    return 'Another rule already uses this port: $name';
  }

  @override
  String get forwardDynamic => 'SOCKS';

  @override
  String get forwardDynamicHint =>
      'A proxy on this device: apps go out to the internet through the server (ssh -D)';

  @override
  String get forwardFailed => 'Failed';

  @override
  String get forwardLocal => 'Local';

  @override
  String get forwardLocalHint =>
      'A port on this device leads to something only the server can reach, like its database (ssh -L)';

  @override
  String get forwardLowPort =>
      'Android apps can only listen on ports 1024 and above';

  @override
  String get forwardOff => 'Off';

  @override
  String forwardPortInUse(int port) {
    return 'Port $port is already in use on this device';
  }

  @override
  String forwardReconnecting(int attempt) {
    return 'Connection lost, reconnecting (attempt $attempt)…';
  }

  @override
  String get forwardRemote => 'Remote';

  @override
  String get forwardRemoteHint =>
      'A port on the server leads back to something this device can reach, like a dev server on your phone (ssh -R)';

  @override
  String get forwardRemoteRefused =>
      'The server refused to listen on that port (taken, or forwarding is turned off in its sshd_config)';

  @override
  String get forwardShared => 'Allow other devices on the network';

  @override
  String get forwardSharedHint =>
      'Listens on all interfaces instead of only this device';

  @override
  String get forwardStarting => 'Starting…';

  @override
  String forwardingActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count port forwardings active',
      one: '$count port forwarding active',
    );
    return '$_temp0';
  }

  @override
  String get forwardingBackgroundHint =>
      'Forwarding keeps running while nux is in the background; a notification shows it. Closing nux from the recent apps stops it.';

  @override
  String get forwardingChannel => 'Port forwarding';

  @override
  String forwardingTraffic(String bytesIn, String bytesOut) {
    return '↓ $bytesIn  ↑ $bytesOut';
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
  String get hideHiddenFiles => 'Hide hidden files';

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
  String get imageUnreadable => 'This image could not be decoded';

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
  String get invalidFileName => 'Names cannot contain /';

  @override
  String get invalidNetworkId => 'A network id is 16 hexadecimal digits';

  @override
  String get invalidNumber => 'Enter a number';

  @override
  String get invalidPort => '1–65535';

  @override
  String get join => 'Join';

  @override
  String get joinNetwork => 'Join a network';

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
  String get keepEditing => 'Keep editing';

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
  String get largerText => 'Larger text';

  @override
  String lastSeen(String date) {
    return 'Last seen $date';
  }

  @override
  String get later => 'Later';

  @override
  String get leave => 'Leave';

  @override
  String get licenses => 'Licenses';

  @override
  String get loadAll => 'Load all';

  @override
  String get matchCase => 'Match case';

  @override
  String get more => 'More';

  @override
  String get move => 'Move';

  @override
  String get moveTo => 'Move to…';

  @override
  String nSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String get nameField => 'Name';

  @override
  String get newFolder => 'New folder';

  @override
  String get newPassphrase => 'New passphrase';

  @override
  String get newTab => 'New tab';

  @override
  String get next => 'Next';

  @override
  String get noColor => 'No colour';

  @override
  String get noForwards => 'No port forwarding yet';

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
  String get noTransfers => 'No transfers';

  @override
  String get noWrap => 'Don\'t wrap lines';

  @override
  String get none => 'None';

  @override
  String get notNow => 'Not now';

  @override
  String get ok => 'OK';

  @override
  String get open => 'Open';

  @override
  String get openReleasePage => 'Open release page';

  @override
  String get openTerminal => 'Open terminal';

  @override
  String get organize => 'Organize';

  @override
  String get overwrite => 'Overwrite';

  @override
  String partiallyLoaded(String loaded, String total) {
    return 'Showing the first $loaded of $total';
  }

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
  String get permExecute => 'Run';

  @override
  String get permGroup => 'Group';

  @override
  String get permOthers => 'Others';

  @override
  String get permOwner => 'Owner';

  @override
  String get permRead => 'Read';

  @override
  String get permWrite => 'Write';

  @override
  String get permissions => 'Permissions';

  @override
  String permissionsOf(String name) {
    return 'Permissions of $name';
  }

  @override
  String get pinTab => 'Pin';

  @override
  String get pinnedTabs => 'Pinned';

  @override
  String get portField => 'Port';

  @override
  String get portForwarding => 'Port forwarding';

  @override
  String portForwardingOn(String name) {
    return 'Forwarding · $name';
  }

  @override
  String get predictiveBack => 'Predictive back gesture';

  @override
  String get predictiveBackHint => 'The page follows your back swipe';

  @override
  String get previous => 'Previous';

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
  String get reachThroughZeroTier => 'Reach it through ZeroTier';

  @override
  String get reachThroughZeroTierHint =>
      'For hosts with no public address: nux joins the network itself, no VPN app needed';

  @override
  String get recommended => 'recommended';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get redoEdit => 'Redo';

  @override
  String get refresh => 'Refresh';

  @override
  String get regex => 'Regular expression';

  @override
  String get reload => 'Reload';

  @override
  String get rememberUntilClosed => 'Remember until nux is closed';

  @override
  String get removeBookmark => 'Remove bookmark';

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
  String get resume => 'Resume';

  @override
  String get save => 'Save';

  @override
  String get saveAndConnect => 'Save and connect';

  @override
  String get saveAs => 'Save as…';

  @override
  String get savePassword => 'Save password';

  @override
  String get savePasswordHint => 'Kept in the device\'s secure storage';

  @override
  String savedAs(String name) {
    return 'Saved $name';
  }

  @override
  String savedFile(String name) {
    return 'Saved $name';
  }

  @override
  String get searchHosts => 'Search hosts';

  @override
  String get selectAll => 'Select all';

  @override
  String get serverPort => 'Port on the server';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get show => 'Show';

  @override
  String get showAsText => 'Show as text';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String get showRendered => 'Show formatted';

  @override
  String get showSource => 'Show source';

  @override
  String get showTabs => 'Show tabs';

  @override
  String get skipKey => 'Skip this key';

  @override
  String get smallerText => 'Smaller text';

  @override
  String get socksPortHint =>
      'Point apps\' SOCKS5 proxy setting at this port (1080 is the usual one)';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortBySize => 'Sort by size';

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
  String get stopAll => 'Stop all';

  @override
  String get stopEditing => 'Stop editing';

  @override
  String tabClosed(String title) {
    return 'Closed $title';
  }

  @override
  String get targetHost => 'Destination';

  @override
  String get targetHostLocalHint =>
      'As the server sees it: localhost is the server itself';

  @override
  String get targetHostRemoteHint =>
      'As this device sees it: localhost is this device';

  @override
  String get targetHostZeroTierHint =>
      'The ZeroTier address of the device, like 10.147.17.5';

  @override
  String get terminal => 'Terminal';

  @override
  String terminalConnecting(String address) {
    return 'Connecting to $address…';
  }

  @override
  String get terminalDisconnected => 'Disconnected';

  @override
  String get terminalFontSize => 'Terminal text size';

  @override
  String get terminalHere => 'Terminal here';

  @override
  String get terminalLineSpacing => 'Terminal line spacing';

  @override
  String get terminalPressEnter => 'Press Enter to reconnect';

  @override
  String get text => 'Text';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeHint =>
      'Also from a tab\'s ⋮ menu, or pinch the text with two fingers.';

  @override
  String get theServer => 'the server';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get throughSsh => 'SSH host';

  @override
  String get throughZeroTier => 'ZeroTier';

  @override
  String get transferCancelled =>
      'Cancelled — resume continues where it stopped';

  @override
  String get transferDownloaded => 'Downloaded';

  @override
  String get transferQueued => 'Waiting';

  @override
  String get transferUploaded => 'Uploaded';

  @override
  String get transfers => 'Transfers';

  @override
  String get tryAgain => 'Try again';

  @override
  String get undo => 'Undo';

  @override
  String get undoEdit => 'Undo';

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
  String get upload => 'Upload';

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
  String viaZeroTier(String network) {
    return 'ZeroTier $network';
  }

  @override
  String get whatsNew => 'What\'s new';

  @override
  String get wrapLines => 'Wrap lines';

  @override
  String get zerotierNetwork => 'ZeroTier network';

  @override
  String get ztAbout =>
      'nux runs its own ZeroTier node, separate from any ZeroTier app on this phone, so it needs no VPN permission. Its traffic only reaches the networks below, only for nux.';

  @override
  String get ztAccessDenied =>
      'Not authorized: allow this node in the network\'s controller';

  @override
  String get ztAutoStart => 'Start with nux';

  @override
  String get ztNetworkIdle => 'The node is off';

  @override
  String get ztNetworks => 'Networks';

  @override
  String get ztNoNetworks => 'No networks yet';

  @override
  String get ztNoNetworksHint =>
      'Join one with its 16-digit id from my.zerotier.com or your own controller';

  @override
  String get ztNode => 'ZeroTier node';

  @override
  String get ztNodeIdHint =>
      'This node\'s id: authorize it in your network\'s controller';

  @override
  String get ztNotFound => 'No such network';

  @override
  String get ztOffline => 'Started, looking for ZeroTier\'s servers…';

  @override
  String get ztOnline => 'Online';

  @override
  String get ztRequesting =>
      'Waiting for the network\'s controller (authorize this node there)';

  @override
  String get ztStarting => 'Starting…';

  @override
  String get ztStopped => 'Off';

  @override
  String get ztWaitingAddress => 'Joined, waiting for an address';
}
