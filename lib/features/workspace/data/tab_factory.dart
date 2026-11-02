import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../terminal/domain/terminal_tab.dart';
import '../domain/nux_tab.dart';
import '../presentation/hosts_tab.dart';

/// Creates tabs. Tabs keep this provider's [Ref] to reach repositories and the SSH pool.
class TabFactory {
  TabFactory(this._ref);

  final Ref _ref;

  HostsTab hosts() => HostsTab();

  TerminalTab terminal(String connectionId) => TerminalTab(_ref, connectionId: connectionId);

  /// Recreates a saved tab; null for unknown kinds (e.g. saved by a newer version).
  NuxTab? restore(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final args = (json['args'] as Map?)?.cast<String, Object?>() ?? const {};
    return switch (json['kind']) {
      HostsTab.kindName => HostsTab(),
      TerminalTab.kindName when id != null && args['connectionId'] is String =>
        TerminalTab(_ref, connectionId: args['connectionId']! as String, id: id),
      _ => null,
    };
  }
}

final tabFactoryProvider = Provider((ref) => TabFactory(ref));
