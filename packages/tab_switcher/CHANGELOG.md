## 2.0.0-dev.1

Rewrite for Dart 3 and Material 3 (developed inside the nux repository):

- `TabSwitcherController` is a `ChangeNotifier`: open, select, close (with confirmation for unsaved
  changes), undo close, pin, groups, close others, move.
- Live and parked tabs: the current tab and the most recently used ones stay mounted, so their state
  survives switching; older ones are unmounted and shown by a preview image.
- Header swipe switches tabs with the body following; swipe down opens the grid.
- Wide layouts get a tab strip.

## 1.0.1

- Last release of the original package.
