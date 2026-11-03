# flterm (vendored)

[flterm](https://pub.dev/packages/flterm) 0.0.6 by Elias Andualem (MIT, see `LICENSE`), copied here with
two patches until upstream has them:

- `TerminalTheme.lineHeight`: cell height as a multiple of the font's natural line height
  (`measureCellMetrics(lineHeight:)`).
- A touch tap shows the soft keyboard again (after Back hid it) when `showKeyboard` is on. It is detected
  with a raw `Listener`, since the tap recognizer inside (selection, links) wins the gesture arena.

Drop this copy and depend on pub.dev again once upstream supports line spacing.
