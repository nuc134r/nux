import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process running while something works in the background, with a notification.
abstract interface class KeepAlive {
  /// Starts the service, or updates it when it runs. Safe to call again (e.g. to retry).
  Future<void> start({required String title, required String text, required String stopLabel});

  /// Updates the notification; starts the service again if it was wanted but is not running (a start
  /// that failed, or the system stopped it).
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
///
/// Starting can fail without an exception: the plugin returns a [ServiceRequestFailure] (Android 12+
/// refuses to start a foreground service while the app is in the background, for one). Failures are
/// logged, and every later [update] tries again, so the service comes back once it can.
class ForegroundServiceKeepAlive implements KeepAlive {
  ForegroundServiceKeepAlive({required String channelName, required this.log}) {
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
        allowWakeLock: true,
        allowWifiLock: true,
        // The service outlives the activity: the Flutter engine with every connection belongs to the
        // process, not the screen (android/.../NuxEngine.kt), so closing nux from the recent apps keeps
        // them running. No restart by the plugin if the system kills the process: the connections died
        // with it, and a service without them would be a notification for nothing.
        stopWithTask: false,
        allowAutoRestart: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final void Function(String message) log;
  final _stop = StreamController<void>.broadcast();

  /// What the service should show while wanted; null when it is not wanted.
  ({String title, String text, String stopLabel})? _wanted;
  bool _askedPermissions = false;
  String? _lastFailure;
  DateTime? _stopPressed;

  void _onData(Object data) {
    if (data == _stopButton) {
      // The service already stopped itself; don't start it again before the app has caught up.
      _stopPressed = DateTime.now();
      _stop.add(null);
    }
  }

  @override
  Stream<void> get stopRequested => _stop.stream;

  /// One service call at a time. The plugin keeps the requested action (start, update, stop) in one
  /// stored value that the service reads when the call reaches it, so an update sent while a start is
  /// on its way replaced the start: the service never went to the foreground, and Android ended nux.
  Future<void> _queue = Future.value();
  bool _updateQueued = false;

  Future<void> _serial(Future<void> Function() call) {
    final next = _queue.then((_) => call()).catchError((Object e) => log('Background service: $e'));
    return _queue = next;
  }

  @override
  Future<void> start({required String title, required String text, required String stopLabel}) {
    _wanted = (title: title, text: text, stopLabel: stopLabel);
    _stopPressed = null;
    return _serial(() async {
      await _askOnce();
      await _ensure(withButtons: true);
    });
  }

  @override
  Future<void> update({required String title, required String text}) async {
    final wanted = _wanted;
    if (wanted == null) return;
    _wanted = (title: title, text: text, stopLabel: wanted.stopLabel);
    final pressed = _stopPressed;
    if (pressed != null && DateTime.now().difference(pressed) < const Duration(seconds: 10)) return;
    // Updates come often (traffic): one waiting in the queue shows the latest text anyway.
    if (_updateQueued) return;
    _updateQueued = true;
    await _serial(() {
      _updateQueued = false;
      return _ensure(withButtons: false);
    });
  }

  @override
  Future<void> stop() {
    _wanted = null;
    return _serial(() async {
      if (_wanted == null && await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    });
  }

  /// Notification permission (Android 13+) and, once, the battery exemption (Termux asks the same: some
  /// phones stop foreground services of battery-optimised apps anyway).
  Future<void> _askOnce() async {
    if (_askedPermissions) return;
    _askedPermissions = true;
    try {
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.getData<bool>(key: _batteryAskedKey) != true &&
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.saveData(key: _batteryAskedKey, value: true);
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      log('Permission request failed: $e');
    }
  }

  Future<void> _ensure({required bool withButtons}) async {
    final w = _wanted;
    if (w == null) return;
    final buttons = [NotificationButton(id: _stopButton, text: w.stopLabel)];
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: w.title,
        notificationText: w.text,
        notificationButtons: withButtons ? buttons : null,
      );
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: w.title,
      notificationText: w.text,
      notificationIcon: const NotificationIcon(metaDataName: 'io.nuc134r.nux.NOTIFICATION_ICON'),
      notificationButtons: buttons,
      callback: keepAliveCallback,
    );
    switch (result) {
      case ServiceRequestSuccess():
        if (_lastFailure != null) log('Background service started after an earlier failure');
        _lastFailure = null;
      case ServiceRequestFailure(:final error):
        final message = '$error';
        if (message != _lastFailure) log('Background service did not start: $message');
        _lastFailure = message;
    }
  }
}

const _batteryAskedKey = 'nux.batteryExemptionAsked';

/// The foreground service on Android, nothing elsewhere.
KeepAlive platformKeepAlive({required String channelName, required void Function(String message) log}) =>
    !kIsWeb && Platform.isAndroid ? ForegroundServiceKeepAlive(channelName: channelName, log: log) : NoKeepAlive();
