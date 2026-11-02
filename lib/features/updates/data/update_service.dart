import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

import '../../../core/app_info.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/release.dart';

/// In-app updates install APKs, so they exist on Android only, and not in builds made without the
/// updater (`NUX_UPDATER=false`, e.g. F-Droid, which updates the app itself).
bool get updatesSupported => updaterEnabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {'Accept': 'application/vnd.github+json'};

  /// The newest published release (including pre-releases with [beta]), or null if there is none.
  Future<Release?> latest({bool beta = false}) async {
    if (beta) {
      final response = await _client.get(
        Uri.https('api.github.com', '/repos/$releasesRepo/releases', {'per_page': '20'}),
        headers: _headers,
      );
      _check(response);
      return Release.newest(jsonDecode(response.body) as List<dynamic>, allowPrerelease: true);
    }
    final response =
        await _client.get(Uri.https('api.github.com', '/repos/$releasesRepo/releases/latest'), headers: _headers);
    if (response.statusCode == 404) return null;
    _check(response);
    return Release.fromGitHub(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _check(http.Response response) {
    if (response.statusCode != 200) throw http.ClientException('GitHub answered ${response.statusCode}');
  }

  /// Downloads the APK for this device and opens the system installer.
  Future<Stream<OtaEvent>> install(Release release) async {
    final ota = OtaUpdate();
    String? abi;
    try {
      abi = await ota.getAbi();
    } catch (_) {}
    final url = release.apkFor(abi);
    if (url == null) throw StateError('No APK in release ${release.version}');
    return ota.execute(url, destinationFilename: 'nux-${release.version}.apk');
  }

  /// Stops a running download; its stream then reports [OtaStatus.CANCELED].
  Future<void> cancel() => OtaUpdate().cancel();
}

final updateServiceProvider = Provider((ref) => UpdateService());

/// A newer release than the installed one, or null.
Future<Release?> checkForUpdate(Ref ref, {required bool beta}) async {
  final release = await ref.read(updateServiceProvider).latest(beta: beta);
  if (release == null) return null;
  final installed = (await ref.read(appVersionProvider.future)).split('+').first;
  return compareVersions(release.version, installed) > 0 ? release : null;
}

/// Checked once per app start in release builds on Android, unless turned off or dismissed for that version.
final availableUpdateProvider = FutureProvider<Release?>((ref) async {
  if (!updatesSupported || !kReleaseMode) return null;
  final settings = await ref.watch(
    appSettingsProvider.selectAsync((s) => (auto: s.autoUpdateCheck, beta: s.betaUpdates, dismissed: s.dismissedUpdate)),
  );
  if (!settings.auto) return null;
  try {
    final release = await checkForUpdate(ref, beta: settings.beta);
    return release == null || release.version == settings.dismissed ? null : release;
  } catch (_) {
    return null; // Offline or rate-limited: try again next start.
  }
});
