import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../log/log.dart';
import 'keep_alive.dart';
import 'keep_alive_hub.dart';

/// The app's one foreground service (Android), shared by SSH sessions and port forwards.
final keepAliveHubProvider = Provider((ref) => KeepAliveHub(
      platformKeepAlive(
        channelName: currentL10n.value.backgroundChannel,
        log: (message) => ref.read(logProvider).w('background', message),
      ),
      stopLabel: () => currentL10n.value.disconnectAll,
      idleText: () => currentL10n.value.backgroundHint,
    ));

/// Retries the background service when the app comes back to the foreground (Android refuses to start it
/// from the background). Watched by the workspace.
final backgroundResyncProvider = Provider((ref) {
  final listener = AppLifecycleListener(onResume: () => ref.read(keepAliveHubProvider).resync());
  ref.onDispose(listener.dispose);
  return listener;
});
