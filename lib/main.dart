import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/log/log.dart';

void main() {
  final container = ProviderContainer();
  final log = container.read(logProvider);
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Every crash below lands in the log file at once, so it is still there after a restart.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      log.e('flutter', details.exceptionAsString(), null, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log.e('app', 'Uncaught platform error', error, stack);
      return true;
    };
    Isolate.current.addErrorListener(
      RawReceivePort((Object? pair) {
        final [error, stack] = pair! as List<Object?>;
        log.e('app', 'Uncaught isolate error', error, StackTrace.fromString('$stack'));
      }).sendPort,
    );
    try {
      log.persistTo('${(await getApplicationSupportDirectory()).path}/logs');
    } catch (e) {
      log.w('app', 'The log is kept in memory only: $e');
    }
    runApp(UncontrolledProviderScope(container: container, child: const NuxApp()));
  }, (error, stack) => log.e('app', 'Uncaught error', error, stack));
}
