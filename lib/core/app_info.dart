import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub repository the app is released from (updates, changelog, "source code" link).
const releasesRepo = 'nuc134r/nux';

/// `--dart-define=NUX_UPDATER=false` builds without the GitHub updater (e.g. for F-Droid).
const updaterEnabled = bool.fromEnvironment('NUX_UPDATER', defaultValue: true);

/// "1.2.0+42" (CI builds: "1.2.0-5-g1a2b3c4+42").
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// The version as shown to people: no build number and no "commits after tag" suffix.
String? displayVersion(String? version) => version?.split('+').first.replaceFirst(RegExp(r'-\d+-g[0-9a-f]+$'), '');
