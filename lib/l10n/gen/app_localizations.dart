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

  /// No description provided for @abortOperation.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get abortOperation;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @activityAppCrashed.
  ///
  /// In en, this message translates to:
  /// **'nux closed unexpectedly last time'**
  String get activityAppCrashed;

  /// No description provided for @activityDisconnected.
  ///
  /// In en, this message translates to:
  /// **'{host}: connection lost'**
  String activityDisconnected(String host);

  /// No description provided for @activityDownload.
  ///
  /// In en, this message translates to:
  /// **'Download {name}'**
  String activityDownload(String name);

  /// No description provided for @activityEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get activityEarlier;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Git commands, transfers, forwardings, updates and messages show up here.'**
  String get activityEmpty;

  /// No description provided for @activityForwardBackShort.
  ///
  /// In en, this message translates to:
  /// **'Works again'**
  String get activityForwardBackShort;

  /// No description provided for @activityForwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Forwarding {name} stopped'**
  String activityForwardFailed(String name);

  /// No description provided for @activityForwardStopped.
  ///
  /// In en, this message translates to:
  /// **'Forwarding {name} turned off'**
  String activityForwardStopped(String name);

  /// No description provided for @activityForwarding.
  ///
  /// In en, this message translates to:
  /// **'Forwarding {name}'**
  String activityForwarding(String name);

  /// No description provided for @activityNew.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String activityNew(int count);

  /// No description provided for @activityNow.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get activityNow;

  /// No description provided for @activityRunning.
  ///
  /// In en, this message translates to:
  /// **'{count} running'**
  String activityRunning(int count);

  /// No description provided for @activityUpdate.
  ///
  /// In en, this message translates to:
  /// **'nux {version} is available'**
  String activityUpdate(String version);

  /// No description provided for @activityUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload {name}'**
  String activityUpload(String name);

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

  /// No description provided for @addPortForwarding.
  ///
  /// In en, this message translates to:
  /// **'Add port forwarding'**
  String get addPortForwarding;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get addRow;

  /// No description provided for @addSnippet.
  ///
  /// In en, this message translates to:
  /// **'Add snippet'**
  String get addSnippet;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'Address or search'**
  String get addressHint;

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

  /// No description provided for @allBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get allBranches;

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

  /// No description provided for @amend.
  ///
  /// In en, this message translates to:
  /// **'Amend'**
  String get amend;

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

  /// No description provided for @archiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'The archive is empty'**
  String get archiveEmpty;

  /// No description provided for @archiveFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String archiveFiles(int count);

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

  /// No description provided for @backgroundAllSet.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get backgroundAllSet;

  /// No description provided for @backgroundAllSetHint.
  ///
  /// In en, this message translates to:
  /// **'Connections keep running in the background and show their notification. No action needed.'**
  String get backgroundAllSetHint;

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

  /// No description provided for @backupSettings.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupSettings;

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

  /// No description provided for @binaryOrEmptyDiff.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show (binary file or only mode changes)'**
  String get binaryOrEmptyDiff;

  /// No description provided for @blame.
  ///
  /// In en, this message translates to:
  /// **'Blame'**
  String get blame;

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

  /// No description provided for @branchName.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get branchName;

  /// No description provided for @branchNotMerged.
  ///
  /// In en, this message translates to:
  /// **'{branch} has commits that are on no other branch. Delete it anyway? They will be lost.'**
  String branchNotMerged(String branch);

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browser;

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

  /// No description provided for @cannotCarryBody.
  ///
  /// In en, this message translates to:
  /// **'{branch} changes some of the same files. Stash your changes and switch?'**
  String cannotCarryBody(String branch);

  /// No description provided for @cannotCarryTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t carry the changes over'**
  String get cannotCarryTitle;

  /// No description provided for @cannotWriteBody.
  ///
  /// In en, this message translates to:
  /// **'Your user may not write {name}. Save it as root with sudo? The file keeps its owner and permissions.'**
  String cannotWriteBody(String name);

  /// No description provided for @cannotWriteContent.
  ///
  /// In en, this message translates to:
  /// **'The app that opened this file does not let nux change it. Share it to save a copy elsewhere.'**
  String get cannotWriteContent;

  /// No description provided for @cannotWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'No permission to write'**
  String get cannotWriteTitle;

  /// No description provided for @carryThem.
  ///
  /// In en, this message translates to:
  /// **'Carry over'**
  String get carryThem;

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

  /// No description provided for @changesSection.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changesSection;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get clearFinished;

  /// No description provided for @clearLog.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get clearLog;

  /// No description provided for @clearLogBody.
  ///
  /// In en, this message translates to:
  /// **'Everything logged so far, from earlier launches too, is deleted.'**
  String get clearLogBody;

  /// No description provided for @clearLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the log?'**
  String get clearLogTitle;

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

  /// No description provided for @closeAllTabs.
  ///
  /// In en, this message translates to:
  /// **'Close all tabs'**
  String get closeAllTabs;

  /// No description provided for @closeAllTabsBody.
  ///
  /// In en, this message translates to:
  /// **'Terminals disconnect. Pinned tabs stay; tabs with unsaved changes ask first.'**
  String get closeAllTabsBody;

  /// No description provided for @closeAllTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Close {count} tab?} other{Close all {count} tabs?}}'**
  String closeAllTabsTitle(int count);

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

  /// No description provided for @colors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colors;

  /// No description provided for @commit.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get commit;

  /// No description provided for @commitDetails.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get commitDetails;

  /// No description provided for @commitMessage.
  ///
  /// In en, this message translates to:
  /// **'Commit message'**
  String get commitMessage;

  /// No description provided for @committed.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get committed;

  /// No description provided for @conflictBlock.
  ///
  /// In en, this message translates to:
  /// **'Conflict {index} of {count}'**
  String conflictBlock(int index, int count);

  /// No description provided for @conflictsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No conflicts left} one{{count} conflict to resolve} other{{count} conflicts to resolve}}'**
  String conflictsLeft(int count);

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

  /// No description provided for @continueOperation.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueOperation;

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

  /// No description provided for @copyHash.
  ///
  /// In en, this message translates to:
  /// **'Copy hash'**
  String get copyHash;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

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

  /// No description provided for @currentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get currentWorkspace;

  /// No description provided for @cursorPosition.
  ///
  /// In en, this message translates to:
  /// **'Ln {line}, Col {column}'**
  String cursorPosition(int line, int column);

  /// No description provided for @cursorPositionSelected.
  ///
  /// In en, this message translates to:
  /// **'Ln {line}, Col {column} ({count} selected)'**
  String cursorPositionSelected(int line, int column, int count);

  /// No description provided for @customizeKeys.
  ///
  /// In en, this message translates to:
  /// **'Customize…'**
  String get customizeKeys;

  /// No description provided for @databaseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tables'**
  String get databaseEmpty;

  /// No description provided for @databaseNoRows.
  ///
  /// In en, this message translates to:
  /// **'No rows'**
  String get databaseNoRows;

  /// No description provided for @databaseRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String databaseRows(int count);

  /// No description provided for @databaseShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {count} rows'**
  String databaseShown(int shown, int count);

  /// No description provided for @databaseTables.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 table or view} other{{count} tables and views}}'**
  String databaseTables(int count);

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

  /// No description provided for @deleteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get deleteAnyway;

  /// No description provided for @deleteBranch.
  ///
  /// In en, this message translates to:
  /// **'Delete branch'**
  String get deleteBranch;

  /// No description provided for @deleteBranchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {branch}?'**
  String deleteBranchTitle(String branch);

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

  /// No description provided for @deleteUntrackedBody.
  ///
  /// In en, this message translates to:
  /// **'The file is not in git yet, so it is deleted.'**
  String get deleteUntrackedBody;

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

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @detailsDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get detailsDocument;

  /// No description provided for @detailsFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get detailsFile;

  /// No description provided for @detailsLibraries.
  ///
  /// In en, this message translates to:
  /// **'Libraries'**
  String get detailsLibraries;

  /// No description provided for @detailsMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get detailsMedia;

  /// No description provided for @detailsMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get detailsMetadata;

  /// No description provided for @detailsProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get detailsProgram;

  /// No description provided for @detailsStrings.
  ///
  /// In en, this message translates to:
  /// **'Readable text in the file'**
  String get detailsStrings;

  /// No description provided for @detailsText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get detailsText;

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

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'The changes you made have not been saved.'**
  String get discardChangesBody;

  /// No description provided for @discardChangesGitBody.
  ///
  /// In en, this message translates to:
  /// **'What you changed since the last commit is lost. This cannot be undone.'**
  String get discardChangesGitBody;

  /// No description provided for @discardChangesGitTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes to {name}?'**
  String discardChangesGitTitle(String name);

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

  /// No description provided for @divergedBody.
  ///
  /// In en, this message translates to:
  /// **'Both this branch and the server have new commits. Rebase puts yours on top of theirs (a straight history); merge joins them with a merge commit.'**
  String get divergedBody;

  /// No description provided for @divergedTitle.
  ///
  /// In en, this message translates to:
  /// **'Branches have diverged'**
  String get divergedTitle;

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

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

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

  /// No description provided for @editAsText.
  ///
  /// In en, this message translates to:
  /// **'Edit as text'**
  String get editAsText;

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

  /// No description provided for @editKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get editKey;

  /// No description provided for @editSnippet.
  ///
  /// In en, this message translates to:
  /// **'Edit snippet'**
  String get editSnippet;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @editorFontSize.
  ///
  /// In en, this message translates to:
  /// **'File text size'**
  String get editorFontSize;

  /// No description provided for @editorKeys.
  ///
  /// In en, this message translates to:
  /// **'Editor keys'**
  String get editorKeys;

  /// No description provided for @editorLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Editor line spacing'**
  String get editorLineSpacing;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get emptyFolder;

  /// No description provided for @encoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get encoding;

  /// No description provided for @equivalentCommand.
  ///
  /// In en, this message translates to:
  /// **'The same in a terminal'**
  String get equivalentCommand;

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

  /// No description provided for @exportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export settings'**
  String get exportSettings;

  /// No description provided for @exportSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'A file with your settings (no hosts, keys or passwords)'**
  String get exportSettingsHint;

  /// No description provided for @extraKeys.
  ///
  /// In en, this message translates to:
  /// **'Extra keys'**
  String get extraKeys;

  /// No description provided for @extractTo.
  ///
  /// In en, this message translates to:
  /// **'Extract to {folder}'**
  String extractTo(String folder);

  /// No description provided for @extractedTo.
  ///
  /// In en, this message translates to:
  /// **'Extracted to {folder}'**
  String extractedTo(String folder);

  /// No description provided for @fetch.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get fetch;

  /// No description provided for @fetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get fetched;

  /// No description provided for @fileDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get fileDetails;

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

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file} other{{count} files}}'**
  String filesCount(int count);

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

  /// No description provided for @followApp.
  ///
  /// In en, this message translates to:
  /// **'Like the app'**
  String get followApp;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @forcePush.
  ///
  /// In en, this message translates to:
  /// **'Force (with lease)'**
  String get forcePush;

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

  /// No description provided for @gitCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get gitCancelled;

  /// No description provided for @gitCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get gitCommand;

  /// No description provided for @gitEarlier.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get gitEarlier;

  /// No description provided for @gitExitCode.
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String gitExitCode(int code);

  /// No description provided for @gitFailed.
  ///
  /// In en, this message translates to:
  /// **'git {command}: {message}'**
  String gitFailed(String command, String message);

  /// No description provided for @gitNoOutput.
  ///
  /// In en, this message translates to:
  /// **'(no output)'**
  String get gitNoOutput;

  /// No description provided for @gitOutput.
  ///
  /// In en, this message translates to:
  /// **'Git output'**
  String get gitOutput;

  /// No description provided for @gitOutputEmpty.
  ///
  /// In en, this message translates to:
  /// **'No git commands yet'**
  String get gitOutputEmpty;

  /// No description provided for @gitOutputShow.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get gitOutputShow;

  /// No description provided for @gitSignInBody.
  ///
  /// In en, this message translates to:
  /// **'The remote asks for a username and password. On GitHub, GitLab and similar, use an access token as the password.'**
  String get gitSignInBody;

  /// No description provided for @gitSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {remote}'**
  String gitSignInTitle(String remote);

  /// No description provided for @gitSignInWrong.
  ///
  /// In en, this message translates to:
  /// **'The remote did not accept these. Try again.'**
  String get gitSignInWrong;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get goBack;

  /// No description provided for @goForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get goForward;

  /// No description provided for @goToLine.
  ///
  /// In en, this message translates to:
  /// **'Go to line'**
  String get goToLine;

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

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

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

  /// No description provided for @keepBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get keepBoth;

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

  /// No description provided for @keepTheirs.
  ///
  /// In en, this message translates to:
  /// **'Theirs'**
  String get keepTheirs;

  /// No description provided for @keepYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get keepYours;

  /// No description provided for @keyAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'This key is already here as {name}'**
  String keyAlreadyImported(String name);

  /// No description provided for @keyAlternates.
  ///
  /// In en, this message translates to:
  /// **'On long press'**
  String get keyAlternates;

  /// No description provided for @keyAlternatesHint.
  ///
  /// In en, this message translates to:
  /// **'Separated by spaces, e.g. () (( ['**
  String get keyAlternatesHint;

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

  /// No description provided for @keyEditorHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a key to change it, hold and drag to move it (or onto Remove). + adds a key to the row.'**
  String get keyEditorHint;

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

  /// No description provided for @keyTypes.
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get keyTypes;

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

  /// No description provided for @keysCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get keysCustom;

  /// No description provided for @keysCustomHelp.
  ///
  /// In en, this message translates to:
  /// **'One row per line, keys separated by spaces. Long-press alternates follow a key after commas: (,(),(( is ( with () and ((. A backslash makes the next character plain: \\, \\\\ \\(space). Hold a key with alternates to pick one; hold other keys to repeat them; hold Ctrl or Alt to lock it.\n\nSpecial keys: {keys}'**
  String keysCustomHelp(String keys);

  /// No description provided for @keysOneRow.
  ///
  /// In en, this message translates to:
  /// **'One row'**
  String get keysOneRow;

  /// No description provided for @keysTwoRows.
  ///
  /// In en, this message translates to:
  /// **'Two rows'**
  String get keysTwoRows;

  /// No description provided for @keysTwoRowsSymbols.
  ///
  /// In en, this message translates to:
  /// **'Two rows, more symbols'**
  String get keysTwoRowsSymbols;

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

  /// No description provided for @lineEndings.
  ///
  /// In en, this message translates to:
  /// **'Line endings'**
  String get lineEndings;

  /// No description provided for @lineField.
  ///
  /// In en, this message translates to:
  /// **'Line (1–{count})'**
  String lineField(int count);

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

  /// No description provided for @loadMoreRows.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMoreRows;

  /// No description provided for @loadedOf.
  ///
  /// In en, this message translates to:
  /// **'{loaded} of {total}'**
  String loadedOf(String loaded, String total);

  /// No description provided for @logAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logAll;

  /// No description provided for @logEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log is empty'**
  String get logEmpty;

  /// No description provided for @logErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get logErrors;

  /// No description provided for @logHint.
  ///
  /// In en, this message translates to:
  /// **'Kept across launches; older lines are dropped. Shared logs have hosts and addresses masked; passwords and keys are never logged.'**
  String get logHint;

  /// No description provided for @logInMemory.
  ///
  /// In en, this message translates to:
  /// **'Kept in memory only'**
  String get logInMemory;

  /// No description provided for @logSize.
  ///
  /// In en, this message translates to:
  /// **'{size} of up to {max}'**
  String logSize(String size, String max);

  /// No description provided for @logTileHint.
  ///
  /// In en, this message translates to:
  /// **'What nux did, for finding problems: size, preview, share'**
  String get logTileHint;

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logTitle;

  /// No description provided for @logWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get logWarnings;

  /// No description provided for @markResolved.
  ///
  /// In en, this message translates to:
  /// **'Save and mark resolved'**
  String get markResolved;

  /// No description provided for @matchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

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

  /// No description provided for @needsTool.
  ///
  /// In en, this message translates to:
  /// **'This needs one of these on the server: {tools}'**
  String needsTool(String tools);

  /// No description provided for @newBranch.
  ///
  /// In en, this message translates to:
  /// **'New branch'**
  String get newBranch;

  /// No description provided for @newBrowserTab.
  ///
  /// In en, this message translates to:
  /// **'New browser tab'**
  String get newBrowserTab;

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

  /// No description provided for @newRow.
  ///
  /// In en, this message translates to:
  /// **'New row'**
  String get newRow;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

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

  /// No description provided for @noCommits.
  ///
  /// In en, this message translates to:
  /// **'No commits yet'**
  String get noCommits;

  /// No description provided for @noDifferences.
  ///
  /// In en, this message translates to:
  /// **'No differences'**
  String get noDifferences;

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

  /// No description provided for @noStashes.
  ///
  /// In en, this message translates to:
  /// **'Nothing stashed'**
  String get noStashes;

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

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get noTags;

  /// No description provided for @noTransfers.
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get noTransfers;

  /// No description provided for @noWebView.
  ///
  /// In en, this message translates to:
  /// **'Web pages are not shown on this device'**
  String get noWebView;

  /// No description provided for @noWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get noWorkspace;

  /// No description provided for @noWorkspaceCard.
  ///
  /// In en, this message translates to:
  /// **'The open tabs belong to no workspace'**
  String get noWorkspaceCard;

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

  /// No description provided for @notASettingsFile.
  ///
  /// In en, this message translates to:
  /// **'This is not a nux settings file'**
  String get notASettingsFile;

  /// No description provided for @notCommittedYet.
  ///
  /// In en, this message translates to:
  /// **'Not committed yet'**
  String get notCommittedYet;

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

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

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

  /// No description provided for @openFileAt.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFileAt;

  /// No description provided for @openInApp.
  ///
  /// In en, this message translates to:
  /// **'In another app'**
  String get openInApp;

  /// No description provided for @openInBrowserTab.
  ///
  /// In en, this message translates to:
  /// **'Open in browser tab'**
  String get openInBrowserTab;

  /// No description provided for @openInFileBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in file browser'**
  String get openInFileBrowser;

  /// No description provided for @openInOtherApp.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get openInOtherApp;

  /// No description provided for @openInTab.
  ///
  /// In en, this message translates to:
  /// **'In a tab'**
  String get openInTab;

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

  /// No description provided for @openWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openWorkspace;

  /// No description provided for @operationCherryPick.
  ///
  /// In en, this message translates to:
  /// **'Cherry-picking'**
  String get operationCherryPick;

  /// No description provided for @operationMerge.
  ///
  /// In en, this message translates to:
  /// **'Merging'**
  String get operationMerge;

  /// No description provided for @operationRebase.
  ///
  /// In en, this message translates to:
  /// **'Rebasing'**
  String get operationRebase;

  /// No description provided for @operationRevert.
  ///
  /// In en, this message translates to:
  /// **'Reverting'**
  String get operationRevert;

  /// No description provided for @orSpecialKey.
  ///
  /// In en, this message translates to:
  /// **'Or a special key'**
  String get orSpecialKey;

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

  /// No description provided for @outdent.
  ///
  /// In en, this message translates to:
  /// **'Outdent'**
  String get outdent;

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

  /// No description provided for @passwordOrToken.
  ///
  /// In en, this message translates to:
  /// **'Password or token'**
  String get passwordOrToken;

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

  /// No description provided for @pathOnServer.
  ///
  /// In en, this message translates to:
  /// **'Path on the server'**
  String get pathOnServer;

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

  /// No description provided for @portsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} port} other{{count} ports}}'**
  String portsCount(int count);

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

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @publishBranchBody.
  ///
  /// In en, this message translates to:
  /// **'This branch is not on the server yet. Push it to origin and track it?'**
  String get publishBranchBody;

  /// No description provided for @publishBranchTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish {branch}?'**
  String publishBranchTitle(String branch);

  /// No description provided for @pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @pulled.
  ///
  /// In en, this message translates to:
  /// **'Pulled'**
  String get pulled;

  /// No description provided for @push.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get push;

  /// No description provided for @pushNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to push: the server has all these commits.'**
  String get pushNothing;

  /// No description provided for @pushPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Push to {upstream}'**
  String pushPreviewTitle(String upstream);

  /// No description provided for @pushRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Someone pushed to this branch, or you rewrote commits that were already pushed. Pull first to combine them, or force the push: the server branch is replaced only if it is still as you last fetched it, so nobody else\'s new work is lost by accident.'**
  String get pushRejectedBody;

  /// No description provided for @pushRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'The server has newer commits'**
  String get pushRejectedTitle;

  /// No description provided for @pushTag.
  ///
  /// In en, this message translates to:
  /// **'Push tag'**
  String get pushTag;

  /// No description provided for @pushed.
  ///
  /// In en, this message translates to:
  /// **'Pushed'**
  String get pushed;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrCode;

  /// No description provided for @quickOpen.
  ///
  /// In en, this message translates to:
  /// **'Quick open'**
  String get quickOpen;

  /// No description provided for @quickOpenHint.
  ///
  /// In en, this message translates to:
  /// **'File name, e.g. main'**
  String get quickOpenHint;

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

  /// No description provided for @rebase.
  ///
  /// In en, this message translates to:
  /// **'Rebase'**
  String get rebase;

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

  /// No description provided for @reloadPage.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reloadPage;

  /// No description provided for @rememberForWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Remember for this workspace'**
  String get rememberForWorkspace;

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

  /// No description provided for @removeKey.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeKey;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameBranch.
  ///
  /// In en, this message translates to:
  /// **'Rename branch'**
  String get renameBranch;

  /// No description provided for @repeatPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get repeatPassphrase;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @replaceWith.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceWith;

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

  /// No description provided for @resetSnippets.
  ///
  /// In en, this message translates to:
  /// **'Reset to presets'**
  String get resetSnippets;

  /// No description provided for @resetSnippetsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Replace your snippets with the presets?'**
  String get resetSnippetsQuestion;

  /// No description provided for @resolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve conflicts'**
  String get resolveConflicts;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore settings'**
  String get restoreSettings;

  /// No description provided for @restoreSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{The file has {count} setting. It replaces your current settings.} other{The file has {count} settings. They replace your current settings.}}'**
  String restoreSettingsBody(int count);

  /// No description provided for @restoreSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore settings?'**
  String get restoreSettingsTitle;

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

  /// No description provided for @saveAsRoot.
  ///
  /// In en, this message translates to:
  /// **'Save as root'**
  String get saveAsRoot;

  /// No description provided for @saveLogToFolder.
  ///
  /// In en, this message translates to:
  /// **'Save to folder'**
  String get saveLogToFolder;

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

  /// No description provided for @saveWithEncoding.
  ///
  /// In en, this message translates to:
  /// **'Save with encoding'**
  String get saveWithEncoding;

  /// No description provided for @savedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String savedAs(String name);

  /// No description provided for @savedAsRoot.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} as root'**
  String savedAsRoot(String name);

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

  /// No description provided for @searchInFiles.
  ///
  /// In en, this message translates to:
  /// **'Search in files'**
  String get searchInFiles;

  /// No description provided for @searchInFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Text to find'**
  String get searchInFilesHint;

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} match in {files}} other{{count} matches in {files}}}'**
  String searchMatches(int count, String files);

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

  /// No description provided for @serverVsYours.
  ///
  /// In en, this message translates to:
  /// **'Server → yours'**
  String get serverVsYours;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsRestored.
  ///
  /// In en, this message translates to:
  /// **'Settings restored'**
  String get settingsRestored;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareFile.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareFile;

  /// No description provided for @shareLog.
  ///
  /// In en, this message translates to:
  /// **'Share log'**
  String get shareLog;

  /// No description provided for @shareLogHint.
  ///
  /// In en, this message translates to:
  /// **'What nux did, also in earlier launches and crashes, as a text file with hosts and addresses hidden'**
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

  /// No description provided for @showBytes.
  ///
  /// In en, this message translates to:
  /// **'Show bytes'**
  String get showBytes;

  /// No description provided for @showChanges.
  ///
  /// In en, this message translates to:
  /// **'Show changes'**
  String get showChanges;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @showPreview.
  ///
  /// In en, this message translates to:
  /// **'Show preview'**
  String get showPreview;

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

  /// No description provided for @sideBySide.
  ///
  /// In en, this message translates to:
  /// **'Side by side'**
  String get sideBySide;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOff.
  ///
  /// In en, this message translates to:
  /// **'Sign off'**
  String get signOff;

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

  /// No description provided for @snippetCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get snippetCommand;

  /// No description provided for @snippetCpu.
  ///
  /// In en, this message translates to:
  /// **'Processes by CPU'**
  String get snippetCpu;

  /// No description provided for @snippetDirs.
  ///
  /// In en, this message translates to:
  /// **'Biggest folders here'**
  String get snippetDirs;

  /// No description provided for @snippetDisk.
  ///
  /// In en, this message translates to:
  /// **'Disk space'**
  String get snippetDisk;

  /// No description provided for @snippetDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker containers'**
  String get snippetDocker;

  /// No description provided for @snippetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed services'**
  String get snippetFailed;

  /// No description provided for @snippetFiles.
  ///
  /// In en, this message translates to:
  /// **'Large files here (over 50 MB)'**
  String get snippetFiles;

  /// No description provided for @snippetFree.
  ///
  /// In en, this message translates to:
  /// **'Memory use'**
  String get snippetFree;

  /// No description provided for @snippetIp.
  ///
  /// In en, this message translates to:
  /// **'Network addresses'**
  String get snippetIp;

  /// No description provided for @snippetLog.
  ///
  /// In en, this message translates to:
  /// **'Recent system log'**
  String get snippetLog;

  /// No description provided for @snippetMem.
  ///
  /// In en, this message translates to:
  /// **'Processes by memory'**
  String get snippetMem;

  /// No description provided for @snippetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get snippetName;

  /// No description provided for @snippetPorts.
  ///
  /// In en, this message translates to:
  /// **'Listening ports'**
  String get snippetPorts;

  /// No description provided for @snippetUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime and load'**
  String get snippetUptime;

  /// No description provided for @snippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get snippets;

  /// No description provided for @snippetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 command} other{{count} commands}}'**
  String snippetsCount(int count);

  /// No description provided for @snippetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet'**
  String get snippetsEmpty;

  /// No description provided for @snippetsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to run · hold to type without running'**
  String get snippetsHint;

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

  /// No description provided for @stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @stageAll.
  ///
  /// In en, this message translates to:
  /// **'Stage all'**
  String get stageAll;

  /// No description provided for @stageHunk.
  ///
  /// In en, this message translates to:
  /// **'Stage this part'**
  String get stageHunk;

  /// No description provided for @staged.
  ///
  /// In en, this message translates to:
  /// **'Staged'**
  String get staged;

  /// No description provided for @startWithNux.
  ///
  /// In en, this message translates to:
  /// **'Auto start'**
  String get startWithNux;

  /// No description provided for @stashApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get stashApply;

  /// No description provided for @stashBeforeSwitch.
  ///
  /// In en, this message translates to:
  /// **'On {from}, before switching to {to}'**
  String stashBeforeSwitch(String from, String to);

  /// No description provided for @stashChanges.
  ///
  /// In en, this message translates to:
  /// **'Stash changes'**
  String get stashChanges;

  /// No description provided for @stashDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get stashDrop;

  /// No description provided for @stashMessage.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get stashMessage;

  /// No description provided for @stashPop.
  ///
  /// In en, this message translates to:
  /// **'Apply and drop'**
  String get stashPop;

  /// No description provided for @stashThem.
  ///
  /// In en, this message translates to:
  /// **'Stash them'**
  String get stashThem;

  /// No description provided for @stashed.
  ///
  /// In en, this message translates to:
  /// **'Stashed'**
  String get stashed;

  /// No description provided for @stashes.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get stashes;

  /// No description provided for @statusBar.
  ///
  /// In en, this message translates to:
  /// **'Status bar'**
  String get statusBar;

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

  /// No description provided for @sudoNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This user may not use sudo on this server'**
  String get sudoNotAllowed;

  /// No description provided for @sudoPassword.
  ///
  /// In en, this message translates to:
  /// **'Password for sudo'**
  String get sudoPassword;

  /// No description provided for @sudoWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get sudoWrongPassword;

  /// No description provided for @svgUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This SVG cannot be drawn'**
  String get svgUnreadable;

  /// No description provided for @switchWithChangesBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You have {count} uncommitted change.} other{You have {count} uncommitted changes.}} Carry them over to the other branch, or stash them (they wait under Stashes)?'**
  String switchWithChangesBody(int count);

  /// No description provided for @switchWithChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to {branch}?'**
  String switchWithChangesTitle(String branch);

  /// No description provided for @switchWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get switchWorkspace;

  /// No description provided for @switchedStashed.
  ///
  /// In en, this message translates to:
  /// **'On {branch}; your changes are in Stashes'**
  String switchedStashed(String branch);

  /// No description provided for @tabClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed {title}'**
  String tabClosed(String title);

  /// No description provided for @tagMessage.
  ///
  /// In en, this message translates to:
  /// **'Message (optional, makes an annotated tag)'**
  String get tagMessage;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

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

  /// No description provided for @terminalAndEditor.
  ///
  /// In en, this message translates to:
  /// **'Terminal and editor'**
  String get terminalAndEditor;

  /// No description provided for @terminalAndEditorHint.
  ///
  /// In en, this message translates to:
  /// **'Colors, fonts, text size and line spacing'**
  String get terminalAndEditorHint;

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

  /// No description provided for @terminalKeys.
  ///
  /// In en, this message translates to:
  /// **'Terminal keys'**
  String get terminalKeys;

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

  /// No description provided for @theRemote.
  ///
  /// In en, this message translates to:
  /// **'the remote'**
  String get theRemote;

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

  /// No description provided for @thisBranch.
  ///
  /// In en, this message translates to:
  /// **'This branch'**
  String get thisBranch;

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

  /// No description provided for @unresolvedLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} block still to choose} other{{count} blocks still to choose}}'**
  String unresolvedLeft(int count);

  /// No description provided for @unstage.
  ///
  /// In en, this message translates to:
  /// **'Unstage'**
  String get unstage;

  /// No description provided for @unstageAll.
  ///
  /// In en, this message translates to:
  /// **'Unstage all'**
  String get unstageAll;

  /// No description provided for @unstageHunk.
  ///
  /// In en, this message translates to:
  /// **'Unstage this part'**
  String get unstageHunk;

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

  /// No description provided for @uploadFolder.
  ///
  /// In en, this message translates to:
  /// **'Upload folder'**
  String get uploadFolder;

  /// No description provided for @uploadHere.
  ///
  /// In en, this message translates to:
  /// **'Upload here'**
  String get uploadHere;

  /// No description provided for @uploadHereHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file to upload: open the folder for it} other{{count} files to upload: open the folder for them}}'**
  String uploadHereHint(int count);

  /// No description provided for @uploadSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Upload {count} file to} other{Upload {count} files to}}'**
  String uploadSharedTitle(int count);

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

  /// No description provided for @webViewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Web pages cannot be shown here'**
  String get webViewUnavailable;

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
