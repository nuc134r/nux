import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../core/log/log.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/nux_tab.dart';
import 'tab_factory.dart';

const _sessionKey = 'tabs.session';

/// The open tabs. Saved (debounced) on every change and restored on start (see [workspaceReadyProvider]).
final workspaceProvider = Provider<TabSwitcherController>((ref) {
  final controller = TabSwitcherController(keepAlive: 3);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Completes once the previous session's tabs are back (or the hosts tab is opened on first start).
final workspaceReadyProvider = FutureProvider<void>((ref) async {
  final controller = ref.watch(workspaceProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  final factory = ref.watch(tabFactoryProvider);
  final log = ref.watch(logProvider);

  final saved = (await settings.load()).values[_sessionKey];
  var restored = 0;
  if (saved != null) {
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      final pinned = ((json['pinned'] as List?) ?? const []).cast<String>().toSet();
      for (final t in (json['tabs'] as List).cast<Map<String, Object?>>()) {
        final tab = factory.restore(t);
        if (tab == null) continue;
        controller.open(tab, foreground: false, index: controller.length, pinned: pinned.contains(tab.id));
        restored++;
      }
      final current = controller.find<NuxTab>((t) => t.id == json['current']);
      if (current != null) controller.select(current);
    } catch (e, st) {
      log.e('workspace', 'Could not restore the tabs', e, st);
    }
  }
  if (restored == 0) controller.open(factory.hosts());

  Timer? debounce;
  void save() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      final tabs = controller.tabs.whereType<NuxTab>();
      settings.set(
        _sessionKey,
        jsonEncode({
          'tabs': [for (final t in tabs) t.toJson()],
          'pinned': [for (final t in tabs) if (controller.isPinned(t)) t.id],
          'current': controller.current?.id,
        }),
      );
    });
  }

  controller.addListener(save);
  ref.onDispose(() {
    debounce?.cancel();
    controller.removeListener(save);
  });
});
