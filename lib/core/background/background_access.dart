import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What Android lets the background service do: show its notification (Android 13+ asks), and run
/// without battery optimisation (some phones stop optimised apps' services anyway).
abstract interface class BackgroundAccess {
  Future<bool> notificationsAllowed();

  /// Asks; false when still not allowed (Android stops showing the prompt after two refusals).
  Future<bool> allowNotifications();
  Future<bool> batteryUnrestricted();
  Future<void> allowUnrestrictedBattery();
}

/// Not Android (tests, desktop): nothing to allow.
class NoBackgroundAccess implements BackgroundAccess {
  const NoBackgroundAccess();

  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<bool> allowNotifications() async => true;

  @override
  Future<bool> batteryUnrestricted() async => true;

  @override
  Future<void> allowUnrestrictedBattery() async {}
}

class AndroidBackgroundAccess implements BackgroundAccess {
  const AndroidBackgroundAccess();

  @override
  Future<bool> notificationsAllowed() async =>
      await FlutterForegroundTask.checkNotificationPermission() == NotificationPermission.granted;

  @override
  Future<bool> allowNotifications() async =>
      await FlutterForegroundTask.requestNotificationPermission() == NotificationPermission.granted;

  @override
  Future<bool> batteryUnrestricted() => FlutterForegroundTask.isIgnoringBatteryOptimizations;

  @override
  Future<void> allowUnrestrictedBattery() async {
    if (!await FlutterForegroundTask.requestIgnoreBatteryOptimization()) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }
  }
}

final backgroundAccessProvider = Provider<BackgroundAccess>(
  (ref) => !kIsWeb && Platform.isAndroid ? const AndroidBackgroundAccess() : const NoBackgroundAccess(),
);
