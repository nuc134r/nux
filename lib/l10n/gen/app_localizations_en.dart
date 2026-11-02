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
  String get appTitle => 'nux';

  @override
  String get appVersion => 'App version';

  @override
  String get appearance => 'Appearance';

  @override
  String get cancel => 'Cancel';

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogOffline =>
      'GitHub is unreachable; showing the changelog of this version.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get homeEarly =>
      'SSH, SFTP, port forwarding and a code editor are on their way. This early build sets up updates, so new features reach you as they land.';

  @override
  String get homeWelcome => 'Welcome to nux';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get later => 'Later';

  @override
  String get licenses => 'Licenses';

  @override
  String get openReleasePage => 'Open release page';

  @override
  String get predictiveBack => 'Predictive back gesture';

  @override
  String get predictiveBackHint => 'The page follows your back swipe';

  @override
  String get settings => 'Settings';

  @override
  String get sourceCode => 'Source code';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

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
  String get whatsNew => 'What\'s new';
}
