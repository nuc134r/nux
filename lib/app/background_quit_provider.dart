import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/background/background_providers.dart';
import '../core/background/background_quit.dart';
import '../core/background/idle_suspend.dart';
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

/// Stops the ZeroTier node while nux is in the background and nothing uses it; starts it again when nux
/// is shown (see [IdleSuspend]). Watched by the workspace.
final zeroTierIdleSuspendProvider = Provider<IdleSuspend?>((ref) {
  if (kIsWeb || !Platform.isAndroid) return null;
  final zt = ref.watch(zeroTierServiceProvider);
  final idle = IdleSuspend(hub: ref.watch(keepAliveHubProvider), suspend: zt.suspend, resume: zt.resumeIfSuspended);
  ref.onDispose(idle.dispose);
  return idle;
});
