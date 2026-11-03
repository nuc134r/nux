import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process running while something works in the background, with a notification.
abstract interface class KeepAlive {
  Future<void> start({required String title, required String text, required String stopLabel});

  Future<void> update({required String title, required String text});

  Future<void> stop();

  /// The user pressed "Stop" in the notification.
  Stream<void> get stopRequested;
}

/// Does nothing (tests, desktop).
class NoKeepAlive implements KeepAlive {
  @override
  Future<void> start({required String title, required String text, required String stopLabel}) async {}

  @override
  Future<void> update({required String title, required String text}) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<void> get stopRequested => const Stream.empty();
}

const _stopButton = 'stop';

/// Entry point of the foreground service's isolate: it only relays the notification's buttons.
@pragma('vm:entry-point')
void keepAliveCallback() => FlutterForegroundTask.setTaskHandler(_RelayHandler());

class _RelayHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
    // The app may be gone (no one receives the message): the button must work anyway. When the app
    // is there it closes its connections and finds the service already stopped.
    if (id == _stopButton) FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

/// An Android foreground service (type `specialUse`, see AndroidManifest.xml) whose notification shows
/// what is running and offers "Stop".
class ForegroundServiceKeepAlive implements KeepAlive {
  ForegroundServiceKeepAlive({required String channelName}) {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'forwarding',
        channelName: channelName,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWifiLock: true,
        // Swiping nux out of the recent apps ends its Flutter engine and with it the connections, so the
        // notification goes too (by default the plugin restarted the service: a notification for
        // nothing, whose button no one heard).
        stopWithTask: true,
        allowAutoRestart: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final _stop = StreamController<void>.broadcast();

  void _onData(Object data) {
    if (data == _stopButton) _stop.add(null);
  }

  @override
  Stream<void> get stopRequested => _stop.stream;

  @override
  Future<void> start({required String title, required String text, required String stopLabel}) async {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final buttons = [NotificationButton(id: _stopButton, text: stopLabel)];
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text, notificationButtons: buttons);
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: title,
      notificationText: text,
      notificationIcon: const NotificationIcon(metaDataName: 'io.nuc134r.nux.NOTIFICATION_ICON'),
      notificationButtons: buttons,
      callback: keepAliveCallback,
    );
  }

  @override
  Future<void> update({required String title, required String text}) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
    }
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
  }
}

/// The foreground service on Android, nothing elsewhere.
KeepAlive platformKeepAlive({required String channelName}) =>
    !kIsWeb && Platform.isAndroid ? ForegroundServiceKeepAlive(channelName: channelName) : NoKeepAlive();
