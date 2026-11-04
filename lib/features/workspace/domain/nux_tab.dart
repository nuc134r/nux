import 'package:flutter/material.dart';

import 'package:tab_switcher/tab_switcher.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../settings/data/settings_repository.dart';

/// A nux tab: knows how to save itself for session restore and what to show in the header.
abstract class NuxTab extends SwitcherTab {
  /// Type name used when saving and restoring the session, e.g. `terminal`.
  String get kind;

  /// What is needed to recreate the tab (besides [id] and [kind]); JSON-compatible values only.
  Map<String, Object?> get args => const {};

  /// Colour tag shown next to the title (e.g. the connection's colour).
  Color? get color => null;

  /// This tab's part of the header's ⋮ menu (the header itself only has the tab count and ⋮).
  List<NuxMenuItem> menuEntries(BuildContext context) => const [];

  /// Shows a dot on the ⋮ button (e.g. transfers running); [menuBadgeChanges] says when it may change.
  bool get menuBadge => false;
  Listenable? get menuBadgeChanges => null;

  /// What tapping the title in the full-screen header does (e.g. the browser asks for an address).
  void Function(BuildContext context)? get onHeaderTap => null;

  /// The text size the menu's stepper (and pinching) changes, if the tab shows such text.
  TextSizeKind? get textSizeKind => null;

  Map<String, Object?> toJson() => {'kind': kind, 'id': id, 'args': args};
}
