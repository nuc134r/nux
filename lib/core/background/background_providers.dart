import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'keep_alive.dart';
import 'keep_alive_hub.dart';

/// The app's one foreground service (Android), shared by SSH sessions and port forwards.
final keepAliveHubProvider = Provider((ref) => KeepAliveHub(
      platformKeepAlive(channelName: currentL10n.value.backgroundChannel),
      stopLabel: () => currentL10n.value.disconnectAll,
      idleText: () => currentL10n.value.backgroundHint,
    ));
