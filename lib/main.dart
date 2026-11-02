import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/log/log.dart';

void main() {
  final container = ProviderContainer();
  final log = container.read(logProvider);
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        log.e('flutter', details.exceptionAsString(), null, details.stack);
      };
      runApp(UncontrolledProviderScope(container: container, child: const NuxApp()));
    },
    (error, stack) => log.e('app', 'Uncaught error', error, stack),
  );
}
