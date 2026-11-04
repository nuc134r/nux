import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'switcher_tab.dart';

/// A closed tab that can still be reopened.
class ClosedTab {
  const ClosedTab(this.tab, this.index, {required this.pinned});

  final SwitcherTab tab;
  final int index;
  final bool pinned;
}

/// A whole set of tabs taken out of a [TabSwitcherController] with [TabSwitcherController.detach]: the
/// tabs stay alive (not disposed) until the set is attached again or [dispose]d.
class TabSet {
  TabSet._(this.tabs, this._mru, this._pinned, this._previews, this._closed, this.gridOpen);

  final List<SwitcherTab> tabs;
  final List<String> _mru;
  final Set<String> _pinned;
  final Map<String, ui.Image> _previews;
  final List<ClosedTab> _closed;
  final bool gridOpen;

  void dispose() {
    for (final t in tabs) {
      t.dispose();
    }
    for (final c in _closed) {
      c.tab.dispose();
    }
    for (final p in _previews.values) {
      p.dispose();
    }
  }
}

/// Opens, selects and closes tabs; remembers which ones are live.
///
/// Pinned tabs always come first. The order of [tabs] is the order shown to the user; the
/// most-recently-used order decides which tab becomes current after a close and which tabs stay live.
class TabSwitcherController extends ChangeNotifier {
  TabSwitcherController({this.keepAlive = 3, this.undoDepth = 10})
      : assert(keepAlive >= 0),
        assert(undoDepth >= 0);

  /// How many background tabs stay mounted besides the current one.
  final int keepAlive;

  /// How many closed tabs can be reopened. Older ones are disposed.
  final int undoDepth;

  /// Asked before closing a tab with unsaved changes; return true to close anyway.
  Future<bool> Function(SwitcherTab tab)? confirmClose;

  final List<SwitcherTab> _tabs = [];
  final List<String> _mru = []; // ids, most recent first
  final Set<String> _pinned = {};
  final Map<String, ui.Image> _previews = {};
  final List<ClosedTab> _closed = [];
  bool _gridOpen = false;
  bool _disposed = false;

  List<SwitcherTab> get tabs => List.unmodifiable(_tabs);
  int get length => _tabs.length;
  bool get isEmpty => _tabs.isEmpty;

  SwitcherTab? get current => _mru.isEmpty ? null : _byId(_mru.first);

  int get currentIndex {
    final c = current;
    return c == null ? -1 : _tabs.indexOf(c);
  }

  /// Whether the tab grid is shown instead of the current tab. Always true without tabs.
  bool get gridOpen => _gridOpen || _tabs.isEmpty;

  set gridOpen(bool value) {
    if (_gridOpen == value) return;
    _gridOpen = value;
    notifyListeners();
  }

  void toggleGrid() => gridOpen = !gridOpen;

  /// The current tab and the [keepAlive] most recently used others.
  Set<String> get liveIds => _mru.take(keepAlive + 1).toSet();

  bool isLive(SwitcherTab tab) => liveIds.contains(tab.id);

  bool isPinned(SwitcherTab tab) => _pinned.contains(tab.id);

  ui.Image? preview(SwitcherTab tab) => _previews[tab.id];

  /// Stores the tab's latest preview (the controller owns and disposes it).
  void setPreview(SwitcherTab tab, ui.Image image) {
    if (!_tabs.contains(tab)) {
      image.dispose();
      return;
    }
    _previews.remove(tab.id)?.dispose();
    _previews[tab.id] = image;
    notifyListeners();
  }

  T? find<T extends SwitcherTab>([bool Function(T tab)? test]) {
    for (final t in _tabs) {
      if (t is T && (test == null || test(t))) return t;
    }
    return null;
  }

  /// Opens [tab] right after the current one (or at [index]). An already open tab with the same
  /// id is selected instead, and [tab] is disposed.
  void open(SwitcherTab tab, {bool foreground = true, int? index, bool pinned = false}) {
    final existing = _byId(tab.id);
    if (existing != null) {
      if (!identical(existing, tab)) tab.dispose();
      if (foreground) select(existing);
      return;
    }
    if (pinned) _pinned.add(tab.id);
    final firstUnpinned = _tabs.indexWhere((t) => !isPinned(t));
    final pinnedCount = firstUnpinned < 0 ? _tabs.length : firstUnpinned;
    var at = index ?? (currentIndex < 0 ? _tabs.length : currentIndex + 1);
    at = pinned ? at.clamp(0, pinnedCount) : at.clamp(pinnedCount, _tabs.length);
    _tabs.insert(at, tab);
    tab.addListener(notifyListeners);
    if (foreground || _mru.isEmpty) {
      _mru.insert(0, tab.id);
      _gridOpen = false;
    } else {
      _mru.add(tab.id);
    }
    notifyListeners();
  }

  void select(SwitcherTab tab) {
    if (!_tabs.contains(tab)) return;
    final changed = current != tab;
    _mru
      ..remove(tab.id)
      ..insert(0, tab.id);
    final wasGrid = _gridOpen;
    _gridOpen = false;
    if (changed || wasGrid) notifyListeners();
  }

  void selectIndex(int index) {
    if (index >= 0 && index < _tabs.length) select(_tabs[index]);
  }

  /// Closes [tab]; asks [confirmClose] first when it has unsaved changes (unless [force]).
  /// Returns whether it was closed.
  Future<bool> close(SwitcherTab tab, {bool force = false}) async {
    if (!_tabs.contains(tab)) return false;
    if (!force && tab.hasUnsavedChanges && confirmClose != null && !await confirmClose!(tab)) return false;
    if (_disposed || !_tabs.contains(tab)) return false;
    final index = _tabs.indexOf(tab);
    final pinned = _pinned.remove(tab.id);
    _tabs.removeAt(index);
    _mru.remove(tab.id);
    tab.removeListener(notifyListeners);
    _previews.remove(tab.id)?.dispose();
    if (undoDepth == 0) {
      tab.dispose();
    } else {
      _closed.add(ClosedTab(tab, index, pinned: pinned));
      while (_closed.length > undoDepth) {
        _closed.removeAt(0).tab.dispose();
      }
    }
    notifyListeners();
    return true;
  }

  /// Closes every unpinned tab except [keep]. Tabs with unsaved changes ask first.
  Future<void> closeOthers(SwitcherTab keep) async {
    for (final t in [..._tabs]) {
      if (t != keep && !isPinned(t)) await close(t);
    }
    select(keep);
  }

  bool get canReopen => _closed.isNotEmpty;

  /// Reopens the most recently closed tab where it was.
  SwitcherTab? reopenClosed() {
    if (_closed.isEmpty) return null;
    final c = _closed.removeLast();
    open(c.tab, index: c.index, pinned: c.pinned);
    return c.tab;
  }

  void setPinned(SwitcherTab tab, bool pinned) {
    if (!_tabs.contains(tab) || isPinned(tab) == pinned) return;
    _tabs.remove(tab);
    if (pinned) {
      _pinned.add(tab.id);
      _tabs.insert(_tabs.where(isPinned).length, tab);
    } else {
      _pinned.remove(tab.id);
      _tabs.insert(_tabs.where(isPinned).length, tab);
    }
    notifyListeners();
  }

  /// Moves a tab within its section (pinned tabs stay before unpinned ones).
  void move(SwitcherTab tab, int toIndex) {
    final from = _tabs.indexOf(tab);
    if (from < 0) return;
    final pinnedCount = _tabs.where(isPinned).length;
    final to = isPinned(tab) ? toIndex.clamp(0, pinnedCount - 1) : toIndex.clamp(pinnedCount, _tabs.length - 1);
    if (to == from) return;
    _tabs
      ..removeAt(from)
      ..insert(to, tab);
    notifyListeners();
  }

  /// Takes every tab out (without disposing them), leaving the controller empty, e.g. to show another
  /// workspace's tabs. [attach] puts them back as they were.
  TabSet detach() {
    for (final t in _tabs) {
      t.removeListener(notifyListeners);
    }
    final set = TabSet._([..._tabs], [..._mru], {..._pinned}, {..._previews}, [..._closed], _gridOpen);
    _tabs.clear();
    _mru.clear();
    _pinned.clear();
    _previews.clear();
    _closed.clear();
    _gridOpen = false;
    notifyListeners();
    return set;
  }

  /// Replaces the (empty) controller's tabs with [set], as detached. Any tabs still open are disposed.
  void attach(TabSet set) {
    for (final t in _tabs) {
      t.removeListener(notifyListeners);
      t.dispose();
    }
    _tabs
      ..clear()
      ..addAll(set.tabs);
    _mru
      ..clear()
      ..addAll(set._mru);
    _pinned
      ..clear()
      ..addAll(set._pinned);
    _previews
      ..clear()
      ..addAll(set._previews);
    _closed
      ..clear()
      ..addAll(set._closed);
    _gridOpen = set.gridOpen;
    for (final t in _tabs) {
      t.addListener(notifyListeners);
    }
    notifyListeners();
  }

  SwitcherTab? _byId(String id) {
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _tabs) {
      t.removeListener(notifyListeners);
      t.dispose();
    }
    for (final c in _closed) {
      c.tab.dispose();
    }
    for (final p in _previews.values) {
      p.dispose();
    }
    _tabs.clear();
    _closed.clear();
    _previews.clear();
    super.dispose();
  }
}
