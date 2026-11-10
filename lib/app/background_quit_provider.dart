import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/background/background_providers.dart';
import '../core/background/background_quit.dart';
import '../core/log/log.dart';
import '../features/ssh/data/ssh_providers.dart';
import '../features/zerotier/data/zerotier_service.dart';

/// Quits nux on Android when it has no screen and nothing runs in the background (see [BackgroundQuit]).
/// Watched by the workspace.
final backgroundQuitProvider = Provider<BackgroundQuit?>((ref) {
  if (kIsWeb || !Platform.isAndroid) return null;
  final quit = BackgroundQuit(
    hub: ref.watch(keepAliveHubProvider),
    shutdown: () async {
      ref.read(logProvider).i('app', 'Closed with nothing running in the background: quitting');
      ref.read(sshPoolProvider).disconnectAll();
      final zt = ref.read(zeroTierServiceProvider);
      if (zt.running) await zt.stop().timeout(const Duration(seconds: 5), onTimeout: () {});
    },
    quit: () => exit(0),
  );
  ref.onDispose(quit.dispose);
  return quit;
});
