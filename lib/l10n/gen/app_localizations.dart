import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @addForward.
  ///
  /// In en, this message translates to:
  /// **'Add forwarding'**
  String get addForward;

  /// No description provided for @addHost.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get addHost;

  /// No description provided for @addKey.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get addKey;

  /// No description provided for @addressVia.
  ///
  /// In en, this message translates to:
  /// **'{address} via {jump}'**
  String addressVia(String address, String jump);

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @algEcdsa.
  ///
  /// In en, this message translates to:
  /// **'NIST curves. Use when a server or policy requires ECDSA.'**
  String get algEcdsa;

  /// No description provided for @algEd25519.
  ///
  /// In en, this message translates to:
  /// **'Small, fast and secure. Supported by every server from the last decade.'**
  String get algEd25519;

  /// No description provided for @algRsa.
  ///
  /// In en, this message translates to:
  /// **'For old servers. Generating takes a while on a phone.'**
  String get algRsa;

  /// No description provided for @allRules.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String allRules(int count);

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'nux'**
  String get appTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authentication;

  /// No description provided for @authenticationHint.
  ///
  /// In en, this message translates to:
  /// **'nux offers the checked keys in order, then the password, then asks the server what else it wants.'**
  String get authenticationHint;

  /// No description provided for @backgroundChannel.
  ///
  /// In en, this message translates to:
  /// **'Background connections'**
  String get backgroundChannel;

  /// No description provided for @backgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Stays connected while nux is in the background'**
  String get backgroundHint;

  /// No description provided for @batteryLabel.
  ///
  /// In en, this message translates to:
  /// **'Battery optimisation'**
  String get batteryLabel;

  /// No description provided for @batteryOff.
  ///
  /// In en, this message translates to:
  /// **'Optimised: some phones stop background connections anyway'**
  String get batteryOff;

  /// No description provided for @batteryOn.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted: Android leaves background connections running'**
  String get batteryOn;

  /// No description provided for @bookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this folder'**
  String get bookmarkFolder;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @bytesCount.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes'**
  String bytesCount(String bytes);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changedOnServer.
  ///
  /// In en, this message translates to:
  /// **'Changed on the server'**
  String get changedOnServer;

  /// No description provided for @changedOnServerBody.
  ///
  /// In en, this message translates to:
  /// **'{name} was changed on the server after you opened it. Overwrite it with your version, or discard your changes and load the new one?'**
  String changedOnServerBody(String name);

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @changelogOffline.
  ///
  /// In en, this message translates to:
  /// **'GitHub is unreachable; showing the changelog of this version.'**
  String get changelogOffline;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @clearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get clearFinished;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeOtherTabs.
  ///
  /// In en, this message translates to:
  /// **'Close other tabs'**
  String get closeOtherTabs;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get closeTab;

  /// No description provided for @closeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Close workspace'**
  String get closeWorkspace;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy everything'**
  String get copyAll;

  /// No description provided for @copyOf.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String copyOf(String name);

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @currentPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Current passphrase'**
  String get currentPassphrase;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String daysAgo(int count);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConnectionBody.
  ///
  /// In en, this message translates to:
  /// **'Its saved password is deleted too. Trusted host keys and SSH keys stay.'**
  String get deleteConnectionBody;

  /// No description provided for @deleteConnectionJumpers.
  ///
  /// In en, this message translates to:
  /// **'These hosts connect through it and will connect directly: {names}'**
  String deleteConnectionJumpers(String names);

  /// No description provided for @deleteConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteConnectionTitle(String name);

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteFileTitle(String name);

  /// No description provided for @deleteFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Folders are deleted with everything inside. This cannot be undone.'**
  String get deleteFilesBody;

  /// No description provided for @deleteFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete {count} item?} other{Delete {count} items?}}'**
  String deleteFilesTitle(int count);

  /// No description provided for @deleteKeyBody.
  ///
  /// In en, this message translates to:
  /// **'The private key is erased from this device. Unless you have a copy, it cannot be recovered.'**
  String get deleteKeyBody;

  /// No description provided for @deleteKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete key {name}?'**
  String deleteKeyTitle(String name);

  /// No description provided for @deleteKeyUsed.
  ///
  /// In en, this message translates to:
  /// **'The private key is erased from this device and removed from these hosts: {names}. Unless you have a copy, it cannot be recovered.'**
  String deleteKeyUsed(String names);

  /// No description provided for @deleteWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace'**
  String get deleteWorkspace;

  /// No description provided for @deleteWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'Its tabs are closed. Files on the host are not touched.'**
  String get deleteWorkspaceBody;

  /// No description provided for @deleteWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteWorkspaceTitle(String name);

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String deleted(String name);

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @destinationFrom.
  ///
  /// In en, this message translates to:
  /// **'Destination (from {host})'**
  String destinationFrom(String host);

  /// No description provided for @destinationHere.
  ///
  /// In en, this message translates to:
  /// **'Destination (on this device)'**
  String get destinationHere;

  /// No description provided for @detachedHead.
  ///
  /// In en, this message translates to:
  /// **'detached HEAD'**
  String get detachedHead;

  /// No description provided for @devicePort.
  ///
  /// In en, this message translates to:
  /// **'Port on this device'**
  String get devicePort;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'The changes you made have not been saved.'**
  String get discardChangesBody;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes to {name}?'**
  String discardChangesTitle(String name);

  /// No description provided for @discardMine.
  ///
  /// In en, this message translates to:
  /// **'Discard mine'**
  String get discardMine;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll;

  /// No description provided for @doneEditing.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get doneEditing;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @duplicateTab.
  ///
  /// In en, this message translates to:
  /// **'New terminal on this host'**
  String get duplicateTab;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editForward.
  ///
  /// In en, this message translates to:
  /// **'Edit forwarding'**
  String get editForward;

  /// No description provided for @editHost.
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get editHost;

  /// No description provided for @editorFontSize.
  ///
  /// In en, this message translates to:
  /// **'File text size'**
  String get editorFontSize;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get emptyFolder;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errorGeneric(String error);

  /// No description provided for @explainDynamic.
  ///
  /// In en, this message translates to:
  /// **'A SOCKS5 proxy on localhost:{port}: apps that use it go out to the internet through {host}.'**
  String explainDynamic(String port, String host);

  /// No description provided for @explainDynamicShared.
  ///
  /// In en, this message translates to:
  /// **'A SOCKS5 proxy on this device\'s port {port}, open to your network: everything goes out through {host}.'**
  String explainDynamicShared(String port, String host);

  /// No description provided for @explainLocal.
  ///
  /// In en, this message translates to:
  /// **'Apps on this device connect to localhost:{port} and reach {target} as seen from {host}.'**
  String explainLocal(String port, String target, String host);

  /// No description provided for @explainLocalShared.
  ///
  /// In en, this message translates to:
  /// **'Devices on your network connect to this device\'s port {port} and reach {target} as seen from {host}.'**
  String explainLocalShared(String port, String target, String host);

  /// No description provided for @explainRemote.
  ///
  /// In en, this message translates to:
  /// **'Programs on {host} connect to its port {port} and reach {target} as seen from this device.'**
  String explainRemote(String host, String port, String target);

  /// No description provided for @explainZeroTierTcp.
  ///
  /// In en, this message translates to:
  /// **'Apps on this device connect to localhost:{port} and reach {target} in ZeroTier network {network}. No SSH involved.'**
  String explainZeroTierTcp(String port, String target, String network);

  /// No description provided for @explainZeroTierUdp.
  ///
  /// In en, this message translates to:
  /// **'UDP packets sent to localhost:{port} go to {target} in ZeroTier network {network}, and replies come back. Good for games, DNS, VoIP.'**
  String explainZeroTierUdp(String port, String target, String network);

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @exportPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Passphrase for the exported key'**
  String get exportPassphraseTitle;

  /// No description provided for @exportPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Export private key'**
  String get exportPrivateKey;

  /// No description provided for @exportPrivateKeyHint.
  ///
  /// In en, this message translates to:
  /// **'As an encrypted OpenSSH file'**
  String get exportPrivateKeyHint;

  /// No description provided for @exportPrivateKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this file and its passphrase can sign in wherever this key is accepted. Export only to move the key to a device you trust. You will choose a passphrase for the file next.'**
  String get exportPrivateKeyWarning;

  /// No description provided for @fileDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The connection was lost'**
  String get fileDisconnected;

  /// No description provided for @fileExists.
  ///
  /// In en, this message translates to:
  /// **'Something with this name already exists'**
  String get fileExists;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get fileNotFound;

  /// No description provided for @filePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get filePermissionDenied;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get folderEmpty;

  /// No description provided for @folderField.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderField;

  /// No description provided for @folderNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'The folder is not empty'**
  String get folderNotEmpty;

  /// No description provided for @folderOnlyHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Only {count} hidden item here} other{Only {count} hidden items here}}'**
  String folderOnlyHidden(int count);

  /// No description provided for @folderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderPath;

  /// No description provided for @foldersNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Folders are not downloaded yet; only the files were queued'**
  String get foldersNotDownloaded;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @forgetHostBody.
  ///
  /// In en, this message translates to:
  /// **'The next connection will show the server\'s key and ask you to trust it again.'**
  String get forgetHostBody;

  /// No description provided for @forgetHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget the key of {host}?'**
  String forgetHostTitle(String host);

  /// No description provided for @forgotten.
  ///
  /// In en, this message translates to:
  /// **'Forgot {host}'**
  String forgotten(String host);

  /// No description provided for @forwardActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get forwardActive;

  /// No description provided for @forwardActiveConnections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Active · {count} connection so far} other{Active · {count} connections so far}}'**
  String forwardActiveConnections(int count);

  /// No description provided for @forwardActiveTraffic.
  ///
  /// In en, this message translates to:
  /// **'Active · {open} open · ↓ {bytesIn} ↑ {bytesOut}'**
  String forwardActiveTraffic(int open, String bytesIn, String bytesOut);

  /// No description provided for @forwardAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start when nux starts'**
  String get forwardAutoStart;

  /// No description provided for @forwardBindDenied.
  ///
  /// In en, this message translates to:
  /// **'This device does not allow listening on port {port}'**
  String forwardBindDenied(int port);

  /// No description provided for @forwardConflict.
  ///
  /// In en, this message translates to:
  /// **'Another forwarding already uses this port: {name}'**
  String forwardConflict(String name);

  /// No description provided for @forwardConnections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} connection} other{{count} connections}}'**
  String forwardConnections(int count);

  /// No description provided for @forwardDynamic.
  ///
  /// In en, this message translates to:
  /// **'SOCKS'**
  String get forwardDynamic;

  /// No description provided for @forwardDynamicHint.
  ///
  /// In en, this message translates to:
  /// **'A proxy on this device: apps go out to the internet through the server (ssh -D)'**
  String get forwardDynamicHint;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get forwardFailed;

  /// No description provided for @forwardHereToThere.
  ///
  /// In en, this message translates to:
  /// **'Here → there'**
  String get forwardHereToThere;

  /// No description provided for @forwardLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get forwardLocal;

  /// No description provided for @forwardLocalHint.
  ///
  /// In en, this message translates to:
  /// **'A port on this device leads to something only the server can reach, like its database (ssh -L)'**
  String get forwardLocalHint;

  /// No description provided for @forwardLowPort.
  ///
  /// In en, this message translates to:
  /// **'Android apps can only listen on ports 1024 and above'**
  String get forwardLowPort;

  /// No description provided for @forwardOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get forwardOff;

  /// No description provided for @forwardPortInUse.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is already in use on this device'**
  String forwardPortInUse(int port);

  /// No description provided for @forwardReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, reconnecting (attempt {attempt})…'**
  String forwardReconnecting(int attempt);

  /// No description provided for @forwardRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get forwardRemote;

  /// No description provided for @forwardRemoteHint.
  ///
  /// In en, this message translates to:
  /// **'A port on the server leads back to something this device can reach, like a dev server on your phone (ssh -R)'**
  String get forwardRemoteHint;

  /// No description provided for @forwardRemoteRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused to listen on that port (taken, or forwarding is turned off in its sshd_config)'**
  String get forwardRemoteRefused;

  /// No description provided for @forwardShared.
  ///
  /// In en, this message translates to:
  /// **'Allow other devices on the network'**
  String get forwardShared;

  /// No description provided for @forwardSharedHint.
  ///
  /// In en, this message translates to:
  /// **'Listens on all interfaces instead of only this device'**
  String get forwardSharedHint;

  /// No description provided for @forwardStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get forwardStarting;

  /// No description provided for @forwardThereToHere.
  ///
  /// In en, this message translates to:
  /// **'There → here'**
  String get forwardThereToHere;

  /// No description provided for @forwardingActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} port forwarding active} other{{count} port forwardings active}}'**
  String forwardingActive(int count);

  /// No description provided for @forwardingBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Forwarding keeps running while nux is in the background; a notification shows it. Closing nux from the recent apps stops it.'**
  String get forwardingBackgroundHint;

  /// No description provided for @forwardingChannel.
  ///
  /// In en, this message translates to:
  /// **'Port forwarding'**
  String get forwardingChannel;

  /// No description provided for @forwardingTraffic.
  ///
  /// In en, this message translates to:
  /// **'↓ {bytesIn}  ↑ {bytesOut}'**
  String forwardingTraffic(String bytesIn, String bytesOut);

  /// No description provided for @forwardings.
  ///
  /// In en, this message translates to:
  /// **'Forwardings'**
  String get forwardings;

  /// No description provided for @forwardingsOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} forwarding on} other{{count} forwardings on}}'**
  String forwardingsOn(int count);

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @generateKey.
  ///
  /// In en, this message translates to:
  /// **'Generate a key'**
  String get generateKey;

  /// No description provided for @generateKeyHint.
  ///
  /// In en, this message translates to:
  /// **'A new key pair made on this device'**
  String get generateKeyHint;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @generatingRsa.
  ///
  /// In en, this message translates to:
  /// **'Generating an RSA key. This can take a minute on a phone.'**
  String get generatingRsa;

  /// No description provided for @groupField.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupField;

  /// No description provided for @hiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Hidden files'**
  String get hiddenFiles;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @hideHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get hideHiddenFiles;

  /// No description provided for @homeEarly.
  ///
  /// In en, this message translates to:
  /// **'SSH, SFTP, port forwarding and a code editor are on their way. This early build sets up updates, so new features reach you as they land.'**
  String get homeEarly;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to nux'**
  String get homeWelcome;

  /// No description provided for @hostField.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostField;

  /// No description provided for @hostKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'{host} presented a different key than before. If the server was not reinstalled or reconfigured, someone may be intercepting the connection. Do not trust the new key unless you know why it changed.'**
  String hostKeyChangedBody(String host);

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'The server\'s key changed!'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyCompareHint.
  ///
  /// In en, this message translates to:
  /// **'On the server: ssh-keygen -lf /etc/ssh/ssh_host_*_key.pub'**
  String get hostKeyCompareHint;

  /// No description provided for @hostKeyNewTypeBody.
  ///
  /// In en, this message translates to:
  /// **'{host} presented a key of a type you have not trusted for it before. This is usually harmless (for example after a server upgrade), but check the fingerprint.'**
  String hostKeyNewTypeBody(String host);

  /// No description provided for @hostKeyNewTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'New key type'**
  String get hostKeyNewTypeTitle;

  /// No description provided for @hostKeyPresented.
  ///
  /// In en, this message translates to:
  /// **'Presented key'**
  String get hostKeyPresented;

  /// No description provided for @hostKeyTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get hostKeyTrust;

  /// No description provided for @hostKeyTrustNew.
  ///
  /// In en, this message translates to:
  /// **'Trust the new key'**
  String get hostKeyTrustNew;

  /// No description provided for @hostKeyTrustedBefore.
  ///
  /// In en, this message translates to:
  /// **'Trusted before'**
  String get hostKeyTrustedBefore;

  /// No description provided for @hostKeyUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This is the first connection to {host}. Check that the fingerprint below matches the server\'s before trusting it.'**
  String hostKeyUnknownBody(String host);

  /// No description provided for @hostKeyUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'New server'**
  String get hostKeyUnknownTitle;

  /// No description provided for @hosts.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get hosts;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String hoursAgo(int count);

  /// No description provided for @imageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This image could not be decoded'**
  String get imageUnreadable;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @importFormatsHint.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH, PEM, PKCS#8 or PuTTY (.ppk)'**
  String get importFormatsHint;

  /// No description provided for @importFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get importFromClipboard;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from a file'**
  String get importFromFile;

  /// No description provided for @importKey.
  ///
  /// In en, this message translates to:
  /// **'Import a key'**
  String get importKey;

  /// No description provided for @importKeyPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'This key has a passphrase'**
  String get importKeyPassphraseTitle;

  /// No description provided for @importKeyStaysEncrypted.
  ///
  /// In en, this message translates to:
  /// **'nux will store it encrypted with the same passphrase.'**
  String get importKeyStaysEncrypted;

  /// No description provided for @importedKey.
  ///
  /// In en, this message translates to:
  /// **'Imported key'**
  String get importedKey;

  /// No description provided for @installOnServer.
  ///
  /// In en, this message translates to:
  /// **'Install on a server'**
  String get installOnServer;

  /// No description provided for @installOnServerHint.
  ///
  /// In en, this message translates to:
  /// **'Adds the public key to ~/.ssh/authorized_keys over an existing login (like ssh-copy-id)'**
  String get installOnServerHint;

  /// No description provided for @installingKey.
  ///
  /// In en, this message translates to:
  /// **'Installing the key on {name}…'**
  String installingKey(String name);

  /// No description provided for @invalidFileName.
  ///
  /// In en, this message translates to:
  /// **'Names cannot contain /'**
  String get invalidFileName;

  /// No description provided for @invalidNetworkId.
  ///
  /// In en, this message translates to:
  /// **'A network id is 16 hexadecimal digits'**
  String get invalidNetworkId;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get invalidNumber;

  /// No description provided for @invalidPort.
  ///
  /// In en, this message translates to:
  /// **'1–65535'**
  String get invalidPort;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @joinNetwork.
  ///
  /// In en, this message translates to:
  /// **'Join a network'**
  String get joinNetwork;

  /// No description provided for @jumpHost.
  ///
  /// In en, this message translates to:
  /// **'Jump host'**
  String get jumpHost;

  /// No description provided for @jumpHostHint.
  ///
  /// In en, this message translates to:
  /// **'Connect through another saved host (like ProxyJump)'**
  String get jumpHostHint;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @keepAlive.
  ///
  /// In en, this message translates to:
  /// **'Keep-alive, seconds'**
  String get keepAlive;

  /// No description provided for @keepAliveHint.
  ///
  /// In en, this message translates to:
  /// **'Pings the server so idle connections are not dropped. 0 turns it off.'**
  String get keepAliveHint;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @keepPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Keep the key protected with this passphrase'**
  String get keepPassphrase;

  /// No description provided for @keyAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'This key is already here as {name}'**
  String keyAlreadyImported(String name);

  /// No description provided for @keyComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get keyComment;

  /// No description provided for @keyCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Shown at the end of the public key; helps you recognise it on servers'**
  String get keyCommentHint;

  /// No description provided for @keyHasPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Protected with a passphrase'**
  String get keyHasPassphrase;

  /// No description provided for @keyInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed on {name}'**
  String keyInstalled(String name);

  /// No description provided for @keyInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a private key nux can read'**
  String get keyInvalid;

  /// No description provided for @keyIsPublic.
  ///
  /// In en, this message translates to:
  /// **'This is a public key. Import the private key (the file without .pub).'**
  String get keyIsPublic;

  /// No description provided for @keyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Phone'**
  String get keyNameHint;

  /// No description provided for @keyNeedsPassphrase.
  ///
  /// In en, this message translates to:
  /// **'This key needs its passphrase'**
  String get keyNeedsPassphrase;

  /// No description provided for @keyNeedsUnlock.
  ///
  /// In en, this message translates to:
  /// **'Device unlock required'**
  String get keyNeedsUnlock;

  /// No description provided for @keyNoPassphrase.
  ///
  /// In en, this message translates to:
  /// **'No passphrase'**
  String get keyNoPassphrase;

  /// No description provided for @keyNowUsed.
  ///
  /// In en, this message translates to:
  /// **'{name} now signs in with this key first'**
  String keyNowUsed(String name);

  /// No description provided for @keyStorageHint.
  ///
  /// In en, this message translates to:
  /// **'The private key is kept in the device\'s secure storage'**
  String get keyStorageHint;

  /// No description provided for @keyType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get keyType;

  /// No description provided for @keyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported key: {detail}'**
  String keyUnsupported(String detail);

  /// No description provided for @keyWasInstalled.
  ///
  /// In en, this message translates to:
  /// **'{name} already accepts this key'**
  String keyWasInstalled(String name);

  /// No description provided for @keys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get keys;

  /// No description provided for @knownHosts.
  ///
  /// In en, this message translates to:
  /// **'Known hosts'**
  String get knownHosts;

  /// No description provided for @knownHostsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trusted servers yet. A server\'s key is saved here when you trust it on the first connection.'**
  String get knownHostsEmpty;

  /// No description provided for @knownHostsHint.
  ///
  /// In en, this message translates to:
  /// **'Keys of servers you trusted. nux warns when a server presents a different key.'**
  String get knownHostsHint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @largerText.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get largerText;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {date}'**
  String lastSeen(String date);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveNetworkBody.
  ///
  /// In en, this message translates to:
  /// **'Hosts and forwardings that use this network will not connect until you join it again.'**
  String get leaveNetworkBody;

  /// No description provided for @leaveNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String leaveNetworkTitle(String name);

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @linkTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Points to'**
  String get linkTargetLabel;

  /// No description provided for @loadAll.
  ///
  /// In en, this message translates to:
  /// **'Load all'**
  String get loadAll;

  /// No description provided for @logEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log is empty'**
  String get logEmpty;

  /// No description provided for @matchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @modifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modifiedLabel;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveTo;

  /// No description provided for @nSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} selected} other{{count} selected}}'**
  String nSelected(int count);

  /// No description provided for @nameField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameField;

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newPassphrase.
  ///
  /// In en, this message translates to:
  /// **'New passphrase'**
  String get newPassphrase;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @newWorkspace.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspace;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// No description provided for @noColor.
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get noColor;

  /// No description provided for @noForwards.
  ///
  /// In en, this message translates to:
  /// **'No port forwarding yet'**
  String get noForwards;

  /// No description provided for @noHosts.
  ///
  /// In en, this message translates to:
  /// **'No hosts yet'**
  String get noHosts;

  /// No description provided for @noHostsHint.
  ///
  /// In en, this message translates to:
  /// **'Add a server to connect to, or type user@host to connect right away.'**
  String get noHostsHint;

  /// No description provided for @noKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Keys let you sign in without a password. Generate one here, or import a key you already use.'**
  String get noKeysHint;

  /// No description provided for @noKeysYet.
  ///
  /// In en, this message translates to:
  /// **'No keys yet'**
  String get noKeysYet;

  /// No description provided for @noPreview.
  ///
  /// In en, this message translates to:
  /// **'No preview'**
  String get noPreview;

  /// No description provided for @noTabs.
  ///
  /// In en, this message translates to:
  /// **'No open tabs'**
  String get noTabs;

  /// No description provided for @noTabsHint.
  ///
  /// In en, this message translates to:
  /// **'Open the hosts list or connect to a server.'**
  String get noTabsHint;

  /// No description provided for @noTransfers.
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get noTransfers;

  /// No description provided for @noWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get noWorkspace;

  /// No description provided for @noWorkspaceHint.
  ///
  /// In en, this message translates to:
  /// **'A workspace is a folder on a host with its own tabs, project tree and git status. Open one from a file browser (⋮ → Open as workspace) or add it here.'**
  String get noWorkspaceHint;

  /// No description provided for @noWrap.
  ///
  /// In en, this message translates to:
  /// **'Don\'t wrap lines'**
  String get noWrap;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @notGitRepo.
  ///
  /// In en, this message translates to:
  /// **'Not a git repository'**
  String get notGitRepo;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Turn them on in Android settings: Apps → nux → Notifications'**
  String get notificationsBlocked;

  /// No description provided for @notificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsLabel;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Off: background connections run without their notification'**
  String get notificationsOff;

  /// No description provided for @notificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Allowed: the notification shows what keeps running'**
  String get notificationsOn;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openAsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open as workspace'**
  String get openAsWorkspace;

  /// No description provided for @openInFileBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in file browser'**
  String get openInFileBrowser;

  /// No description provided for @openLinkQuestion.
  ///
  /// In en, this message translates to:
  /// **'Open this link?'**
  String get openLinkQuestion;

  /// No description provided for @openReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get openReleasePage;

  /// No description provided for @openTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open terminal'**
  String get openTerminal;

  /// No description provided for @openTerminalHere.
  ///
  /// In en, this message translates to:
  /// **'Open terminal here'**
  String get openTerminalHere;

  /// No description provided for @organize.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get organize;

  /// No description provided for @otherDevices.
  ///
  /// In en, this message translates to:
  /// **'Connections from LAN'**
  String get otherDevices;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @ownerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ownerLabel;

  /// No description provided for @partiallyLoaded.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {loaded} of {total}'**
  String partiallyLoaded(String loaded, String total);

  /// No description provided for @passphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get passphrase;

  /// No description provided for @passphraseChanged.
  ///
  /// In en, this message translates to:
  /// **'Passphrase changed'**
  String get passphraseChanged;

  /// No description provided for @passphraseOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Asked when the key is used.'**
  String get passphraseOptionalHint;

  /// No description provided for @passphraseRemoved.
  ///
  /// In en, this message translates to:
  /// **'Passphrase removed'**
  String get passphraseRemoved;

  /// No description provided for @passphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase'**
  String get passphraseWrong;

  /// No description provided for @passphrasesDiffer.
  ///
  /// In en, this message translates to:
  /// **'The passphrases differ'**
  String get passphrasesDiffer;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordFor.
  ///
  /// In en, this message translates to:
  /// **'Password for {address}'**
  String passwordFor(String address);

  /// No description provided for @passwordKeepHint.
  ///
  /// In en, this message translates to:
  /// **'A password is saved. Leave empty to keep it.'**
  String get passwordKeepHint;

  /// No description provided for @passwordWrong.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept the password'**
  String get passwordWrong;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @permExecute.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get permExecute;

  /// No description provided for @permGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get permGroup;

  /// No description provided for @permOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get permOthers;

  /// No description provided for @permOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get permOwner;

  /// No description provided for @permRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get permRead;

  /// No description provided for @permWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get permWrite;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permissionsOf.
  ///
  /// In en, this message translates to:
  /// **'Permissions of {name}'**
  String permissionsOf(String name);

  /// No description provided for @pickProtocol.
  ///
  /// In en, this message translates to:
  /// **'Pick TCP, UDP or both'**
  String get pickProtocol;

  /// No description provided for @pinTab.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinTab;

  /// No description provided for @pingFailed.
  ///
  /// In en, this message translates to:
  /// **'no reply'**
  String get pingFailed;

  /// No description provided for @pingMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String pingMs(int ms);

  /// No description provided for @pinnedTabs.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedTabs;

  /// No description provided for @portField.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portField;

  /// No description provided for @portForwarding.
  ///
  /// In en, this message translates to:
  /// **'Port forwarding'**
  String get portForwarding;

  /// No description provided for @portForwardingOn.
  ///
  /// In en, this message translates to:
  /// **'Forwarding · {name}'**
  String portForwardingOn(String name);

  /// No description provided for @portHere.
  ///
  /// In en, this message translates to:
  /// **'Port here'**
  String get portHere;

  /// No description provided for @portOnHost.
  ///
  /// In en, this message translates to:
  /// **'Port on {host}'**
  String portOnHost(String host);

  /// No description provided for @portSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: not used by other forwardings'**
  String get portSuggested;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @protection.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get protection;

  /// No description provided for @publicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrCode;

  /// No description provided for @quickConnect.
  ///
  /// In en, this message translates to:
  /// **'Quick connect'**
  String get quickConnect;

  /// No description provided for @quickConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Saved to hosts, offering all your keys'**
  String get quickConnectHint;

  /// No description provided for @reachThroughZeroTier.
  ///
  /// In en, this message translates to:
  /// **'Reach it through ZeroTier'**
  String get reachThroughZeroTier;

  /// No description provided for @reachThroughZeroTierHint.
  ///
  /// In en, this message translates to:
  /// **'For hosts with no public address: nux joins the network itself, no VPN app needed'**
  String get reachThroughZeroTierHint;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get recommended;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @redoEdit.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redoEdit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @regex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get regex;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @rememberUntilClosed.
  ///
  /// In en, this message translates to:
  /// **'Remember until nux is closed'**
  String get rememberUntilClosed;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @repeatPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get repeatPassphrase;

  /// No description provided for @requireUnlock.
  ///
  /// In en, this message translates to:
  /// **'Require device unlock'**
  String get requireUnlock;

  /// No description provided for @requireUnlockHint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint, face or screen lock before each use'**
  String get requireUnlockHint;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Save and connect'**
  String get saveAndConnect;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveAs;

  /// No description provided for @savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePassword;

  /// No description provided for @savePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Kept in the device\'s secure storage'**
  String get savePasswordHint;

  /// No description provided for @savedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String savedAs(String name);

  /// No description provided for @savedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String savedFile(String name);

  /// No description provided for @searchHosts.
  ///
  /// In en, this message translates to:
  /// **'Search hosts'**
  String get searchHosts;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @serverPort.
  ///
  /// In en, this message translates to:
  /// **'Port on the server'**
  String get serverPort;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareLog.
  ///
  /// In en, this message translates to:
  /// **'Share log'**
  String get shareLog;

  /// No description provided for @shareLogHint.
  ///
  /// In en, this message translates to:
  /// **'What nux did since it started, with hosts and addresses hidden'**
  String get shareLogHint;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @showAsText.
  ///
  /// In en, this message translates to:
  /// **'Show as text'**
  String get showAsText;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @showRendered.
  ///
  /// In en, this message translates to:
  /// **'Show formatted'**
  String get showRendered;

  /// No description provided for @showSource.
  ///
  /// In en, this message translates to:
  /// **'Show source'**
  String get showSource;

  /// No description provided for @showTabs.
  ///
  /// In en, this message translates to:
  /// **'Show tabs'**
  String get showTabs;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// No description provided for @skipKey.
  ///
  /// In en, this message translates to:
  /// **'Skip this key'**
  String get skipKey;

  /// No description provided for @smallerText.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get smallerText;

  /// No description provided for @socksPortHint.
  ///
  /// In en, this message translates to:
  /// **'Point apps\' SOCKS5 proxy setting at this port (1080 is the usual one)'**
  String get socksPortHint;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get sortByDate;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get sortByName;

  /// No description provided for @sortBySize.
  ///
  /// In en, this message translates to:
  /// **'Sort by size'**
  String get sortBySize;

  /// No description provided for @sortMenu.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortMenu;

  /// No description provided for @sortModified.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get sortModified;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @ssh.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get ssh;

  /// No description provided for @sshAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'The server refused the keys and password offered'**
  String get sshAuthFailed;

  /// No description provided for @sshCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sshCancelled;

  /// No description provided for @sshConnectionMissing.
  ///
  /// In en, this message translates to:
  /// **'This host was deleted'**
  String get sshConnectionMissing;

  /// No description provided for @sshConnectionsOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 SSH connection} other{{count} SSH connections}}'**
  String sshConnectionsOpen(int count);

  /// No description provided for @sshHostKeyRejected.
  ///
  /// In en, this message translates to:
  /// **'The server\'s key was not trusted'**
  String get sshHostKeyRejected;

  /// No description provided for @sshOtherError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {detail}'**
  String sshOtherError(String detail);

  /// No description provided for @sshUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server: {detail}'**
  String sshUnreachable(String detail);

  /// No description provided for @sshVia.
  ///
  /// In en, this message translates to:
  /// **'{error} (through {via})'**
  String sshVia(String error, String via);

  /// No description provided for @startWithNux.
  ///
  /// In en, this message translates to:
  /// **'Auto start'**
  String get startWithNux;

  /// No description provided for @stopAll.
  ///
  /// In en, this message translates to:
  /// **'Stop all'**
  String get stopAll;

  /// No description provided for @stopEditing.
  ///
  /// In en, this message translates to:
  /// **'Stop editing'**
  String get stopEditing;

  /// No description provided for @switchWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get switchWorkspace;

  /// No description provided for @tabClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed {title}'**
  String tabClosed(String title);

  /// No description provided for @targetHost.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get targetHost;

  /// No description provided for @targetHostLocalHint.
  ///
  /// In en, this message translates to:
  /// **'As the server sees it: localhost is the server itself'**
  String get targetHostLocalHint;

  /// No description provided for @targetHostRemoteHint.
  ///
  /// In en, this message translates to:
  /// **'As this device sees it: localhost is this device'**
  String get targetHostRemoteHint;

  /// No description provided for @targetHostZeroTierHint.
  ///
  /// In en, this message translates to:
  /// **'The ZeroTier address of the device, like 10.147.17.5'**
  String get targetHostZeroTierHint;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {address}…'**
  String terminalConnecting(String address);

  /// No description provided for @terminalDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get terminalDisconnected;

  /// No description provided for @terminalFontSize.
  ///
  /// In en, this message translates to:
  /// **'Terminal text size'**
  String get terminalFontSize;

  /// No description provided for @terminalHere.
  ///
  /// In en, this message translates to:
  /// **'Terminal here'**
  String get terminalHere;

  /// No description provided for @terminalLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Terminal line spacing'**
  String get terminalLineSpacing;

  /// No description provided for @terminalPressEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to reconnect'**
  String get terminalPressEnter;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Also from a tab\'s ⋮ menu, or pinch the text with two fingers.'**
  String get textSizeHint;

  /// No description provided for @theServer.
  ///
  /// In en, this message translates to:
  /// **'the server'**
  String get theServer;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @throughSsh.
  ///
  /// In en, this message translates to:
  /// **'SSH host'**
  String get throughSsh;

  /// No description provided for @throughZeroTier.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier'**
  String get throughZeroTier;

  /// No description provided for @transferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — resume continues where it stopped'**
  String get transferCancelled;

  /// No description provided for @transferDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get transferDownloaded;

  /// No description provided for @transferQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get transferQueued;

  /// No description provided for @transferUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get transferUploaded;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @transfersActive.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String transfersActive(int count);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @udpNeedsHostItself.
  ///
  /// In en, this message translates to:
  /// **'UDP goes straight over ZeroTier, so only to a port of {host} itself'**
  String udpNeedsHostItself(String host);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @undoEdit.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoEdit;

  /// No description provided for @unlockKey.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}'**
  String unlockKey(String name);

  /// No description provided for @unlockKeyReason.
  ///
  /// In en, this message translates to:
  /// **'Use the key {name}'**
  String unlockKeyReason(String name);

  /// No description provided for @unpinTab.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinTab;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version'**
  String get upToDate;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'nux {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Opening the installer…'**
  String get updateInstalling;

  /// No description provided for @updatePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow nux to install apps, then try again'**
  String get updatePermission;

  /// No description provided for @updateTo.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateTo(String version);

  /// No description provided for @updatesAuto.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get updatesAuto;

  /// No description provided for @updatesBeta.
  ///
  /// In en, this message translates to:
  /// **'Beta versions'**
  String get updatesBeta;

  /// No description provided for @updatesBetaHint.
  ///
  /// In en, this message translates to:
  /// **'Also offer pre-releases. They may be unstable.'**
  String get updatesBetaHint;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @useKey.
  ///
  /// In en, this message translates to:
  /// **'Use this key'**
  String get useKey;

  /// No description provided for @useKeyFor.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {name} with this key from now on?'**
  String useKeyFor(String name);

  /// No description provided for @usedBy.
  ///
  /// In en, this message translates to:
  /// **'Used by'**
  String get usedBy;

  /// No description provided for @usedByNone.
  ///
  /// In en, this message translates to:
  /// **'No host uses this key yet'**
  String get usedByNone;

  /// No description provided for @usernameField.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameField;

  /// No description provided for @versionControl.
  ///
  /// In en, this message translates to:
  /// **'Version control'**
  String get versionControl;

  /// No description provided for @viaZeroTier.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier {network}'**
  String viaZeroTier(String network);

  /// No description provided for @viewMenu.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMenu;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whatsNew;

  /// No description provided for @workspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspaces;

  /// No description provided for @wrapLines.
  ///
  /// In en, this message translates to:
  /// **'Wrap lines'**
  String get wrapLines;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// No description provided for @zerotierNetwork.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier network'**
  String get zerotierNetwork;

  /// No description provided for @ztAbout.
  ///
  /// In en, this message translates to:
  /// **'nux runs its own ZeroTier node, separate from any ZeroTier app on this phone, so it needs no VPN permission. Its traffic only reaches the networks below, only for nux.'**
  String get ztAbout;

  /// No description provided for @ztAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Not authorized: allow this node in the network\'s controller'**
  String get ztAccessDenied;

  /// No description provided for @ztAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start with nux'**
  String get ztAutoStart;

  /// No description provided for @ztNetworkIdle.
  ///
  /// In en, this message translates to:
  /// **'The node is off'**
  String get ztNetworkIdle;

  /// No description provided for @ztNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get ztNetworks;

  /// No description provided for @ztNoNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks yet'**
  String get ztNoNetworks;

  /// No description provided for @ztNoNetworksHint.
  ///
  /// In en, this message translates to:
  /// **'Join one with its 16-digit id from my.zerotier.com or your own controller'**
  String get ztNoNetworksHint;

  /// No description provided for @ztNode.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier node'**
  String get ztNode;

  /// No description provided for @ztNodeIdHint.
  ///
  /// In en, this message translates to:
  /// **'This node\'s id: authorize it in your network\'s controller'**
  String get ztNodeIdHint;

  /// No description provided for @ztNotFound.
  ///
  /// In en, this message translates to:
  /// **'No such network'**
  String get ztNotFound;

  /// No description provided for @ztOffline.
  ///
  /// In en, this message translates to:
  /// **'Started, looking for ZeroTier\'s servers…'**
  String get ztOffline;

  /// No description provided for @ztOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get ztOnline;

  /// No description provided for @ztRequesting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the network\'s controller (authorize this node there)'**
  String get ztRequesting;

  /// No description provided for @ztStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get ztStarting;

  /// No description provided for @ztStopped.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get ztStopped;

  /// No description provided for @ztWaitingAddress.
  ///
  /// In en, this message translates to:
  /// **'Joined, waiting for an address'**
  String get ztWaitingAddress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
