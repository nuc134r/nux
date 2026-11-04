/// Full-screen tabs like Chrome for Android: swipe the header to switch, swipe down for the grid,
/// swipe a card away to close. The current tab and the most recently used ones stay mounted (their
/// state survives switching); older tabs are parked and shown by a preview.
library;

export 'src/controller.dart';
export 'src/start_ellipsis_text.dart';
export 'src/switcher_tab.dart';
export 'src/tab_count_button.dart';
export 'src/tab_switcher.dart';
