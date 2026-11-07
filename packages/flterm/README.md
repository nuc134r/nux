# flterm (vendored)

[flterm](https://pub.dev/packages/flterm) 0.0.6 by Elias Andualem (MIT, see `LICENSE`), copied here with
a few patches until upstream has them:

- `TerminalTheme.lineHeight`: cell height as a multiple of the font's natural line height
  (`measureCellMetrics(lineHeight:)`).
- A touch tap shows the soft keyboard again (after Back hid it) when `showKeyboard` is on. It is detected
  with a raw `Listener`, since the tap recognizer inside (selection, links) wins the gesture arena.
- A touch long press selects the word under the finger (`InteractionRegion._handleLongPressStart`), so
  the selection handles have something to hold without a drag.
- Text with line breaks committed by the soft keyboard at once (its clipboard) is pasted
  (`TextInputSession.onPaste` → `paste`, bracketed when asked), not typed line by line; `paste` turns
  `\r\n` into `\n`.

Drop this copy and depend on pub.dev again once upstream supports line spacing.
