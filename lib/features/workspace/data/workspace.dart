import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/nux_tab.dart';
import 'tab_factory.dart';
import 'workspace_repository.dart';

/// The tabs outside any workspace (also where sessions from before workspaces were saved).
const _sessionKey = 'tabs.session';
const _currentKey = 'workspace.current';

String _sessionKeyOf(String? workspaceId) => workspaceId == null ? _sessionKey : '$_sessionKey.$workspaceId';

/// The open tabs of the current workspace (see [WorkspaceSwitcher]).
final workspaceProvider = Provider<TabSwitcherController>((ref) {
  final controller = TabSwitcherController(keepAlive: 3);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Swaps the tabs when another workspace is chosen. Tabs of the other workspaces stay alive in the
/// background (their sessions keep running) and every workspace's tabs are saved, so they come back after
/// a restart too.
class WorkspaceSwitcher extends ChangeNotifier {
  WorkspaceSwitcher({
    required this.controller,
    required this.settings,
    required this.factory,
    required this.repository,
    required this.log,
  });

  final TabSwitcherController controller;
  final SettingsRepository settings;

  /// Read when needed: tabs (built by the factory) use the switcher too.
  final TabFactory Function() factory;
  final WorkspaceRepository repository;
  final Log log;

  String? _currentId;
  Workspace? _current;
  final Map<String?, TabSet> _parked = {};
  Timer? _debounce;
  bool _switching = false;

  /// The open workspace; null for the tabs outside any workspace.
  String? get currentId => _currentId;
  Workspace? get current => _current;

  /// Restores the last workspace and its tabs.
  Future<void> start() async {
    final values = (await settings.load()).values;
    final id = values[_currentKey];
    final ws = id == null ? null : await repository.get(id);
    _currentId = ws?.id;
    _current = ws;
    await _restore(values[_sessionKeyOf(_currentId)]);
    controller.addListener(_scheduleSave);
    notifyListeners();
  }

  /// Opens workspace [id] (null: no workspace) with the tabs it had.
  Future<void> switchTo(String? id) async {
    if (id == _currentId || _switching) return;
    _switching = true;
    try {
      final ws = id == null ? null : await repository.get(id);
      if (id != null && ws == null) return;
      _saveNow();
      _parked[_currentId] = controller.detach();
      _currentId = id;
      _current = ws;
      unawaited(settings.set(_currentKey, id));
      if (id != null) unawaited(repository.touch(id));
      final parked = _parked.remove(id);
      if (parked != null) {
        controller.attach(parked);
      } else {
        await _restore((await settings.load()).values[_sessionKeyOf(id)]);
      }
      _saveNow();
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  /// After a workspace is renamed or edited.
  Future<void> refresh() async {
    final id = _currentId;
    if (id == null) return;
    _current = await repository.get(id);
    notifyListeners();
  }

  /// Deletes workspace [id] and closes its tabs (leaving it first when it is open).
  Future<void> delete(String id) async {
    if (id == _currentId) await switchTo(null);
    _parked.remove(id)?.dispose();
    await settings.set(_sessionKeyOf(id), null);
    await repository.delete(id);
    notifyListeners();
  }

  Future<void> _restore(String? saved) async {
    var restored = 0;
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, Object?>;
        final pinned = ((json['pinned'] as List?) ?? const []).cast<String>().toSet();
        for (final t in (json['tabs'] as List).cast<Map<String, Object?>>()) {
          final tab = factory().restore(t);
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
    if (restored > 0) return;
    // A new workspace starts with its folder; outside workspaces, with the hosts.
    final ws = _current;
    controller.open(ws == null ? factory().hosts() : factory().files(ws.connectionId, path: ws.rootPath));
  }

  void _scheduleSave() {
    if (_switching) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    _debounce?.cancel();
    final tabs = controller.tabs.whereType<NuxTab>();
    settings.set(
      _sessionKeyOf(_currentId),
      jsonEncode({
        'tabs': [for (final t in tabs) t.toJson()],
        'pinned': [
          for (final t in tabs)
            if (controller.isPinned(t)) t.id,
        ],
        'current': controller.current?.id,
      }),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.removeListener(_scheduleSave);
    for (final set in _parked.values) {
      set.dispose();
    }
    _parked.clear();
    super.dispose();
  }
}

final workspaceSwitcherProvider = Provider<WorkspaceSwitcher>((ref) {
  final switcher = WorkspaceSwitcher(
    controller: ref.watch(workspaceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    factory: () => ref.read(tabFactoryProvider),
    repository: ref.watch(workspaceRepositoryProvider),
    log: ref.watch(logProvider),
  );
  ref.onDispose(switcher.dispose);
  return switcher;
});

/// Completes once the last workspace's tabs are back (or the hosts tab is opened on first start).
final workspaceReadyProvider = FutureProvider<void>((ref) => ref.watch(workspaceSwitcherProvider).start());
