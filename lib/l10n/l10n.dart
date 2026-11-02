import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The app's current translations, for objects without a BuildContext (e.g. tab titles).
/// Kept up to date by the app root.
final currentL10n = ValueNotifier<AppLocalizations>(lookupAppLocalizations(const Locale('en')));
