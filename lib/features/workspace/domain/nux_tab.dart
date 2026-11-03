import 'package:flutter/material.dart';

import '../../settings/data/settings_repository.dart';

import 'package:tab_switcher/tab_switcher.dart';

/// An entry in a tab's "more" menu in the header.
class TabMenuEntry {
  const TabMenuEntry({required this.icon, required this.label, required this.onSelected, this.enabled = true});

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// A nux tab: knows how to save itself for session restore and what to show in the header.
abstract class NuxTab extends SwitcherTab {
  /// Type name used when saving and restoring the session, e.g. `terminal`.
  String get kind;

  /// What is needed to recreate the tab (besides [id] and [kind]); JSON-compatible values only.
  Map<String, Object?> get args => const {};

  /// Colour tag shown next to the title (e.g. the connection's colour).
  Color? get color => null;

  /// Buttons in the header, before the tab count button.
  List<Widget> buildActions(BuildContext context) => const [];

  /// Entries of the header's "more" menu for this tab.
  List<TabMenuEntry> menuEntries(BuildContext context) => const [];

  /// The text size the menu's stepper (and pinching) changes, if the tab shows such text.
  TextSizeKind? get textSizeKind => null;

  Map<String, Object?> toJson() => {'kind': kind, 'id': id, 'args': args};
}
