import 'package:flutter/widgets.dart';

/// One tab. Extend it with the state the tab needs; call [notifyListeners] when [title],
/// [subtitle] or [hasUnsavedChanges] change.
///
/// Heavy state that must survive parking (a terminal session, an editor buffer) belongs in the
/// tab object, not in the widget returned by [buildContent]: that widget is unmounted when the
/// tab is parked.
abstract class SwitcherTab extends ChangeNotifier {
  /// Stable id, unique among open tabs. Opening a tab whose id is already open selects that one.
  String get id;

  String get title;

  String? get subtitle => null;

  /// Shown in full in the tab's long-press sheet (where the subtitle is cut to one line elsewhere): e.g.
  /// the host and the whole path. Defaults to [subtitle].
  String? get details => subtitle;

  IconData? get icon => null;

  /// Tabs with the same group are shown together in the grid.
  String? get group => null;

  /// When true, closing asks for confirmation (see [TabSwitcherController.confirmClose]).
  bool get hasUnsavedChanges => false;

  Widget buildContent(BuildContext context);

  /// The tab's widget was unmounted because the tab fell out of the live set.
  void onParked() {}

  /// The tab's widget is mounted again.
  void onResumed() {}
}
