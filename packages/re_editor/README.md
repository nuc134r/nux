# re_editor (vendored)

[re_editor](https://pub.dev/packages/re_editor) 0.10.0 by Reqable (MIT, see `LICENSE`), copied here with
a few patches (marked `nux:` in the code) until upstream has them:

- On Android and iOS the keyboard sees the current line behind an invisible prefix, and a cursor at 0
  was taken as Backspace at the line start. Swiping the space bar left to the start of a line put it
  there and deleted a character; now only a removed prefix deletes (`_code_input.dart`).
- The cursor blink no longer touches its controller after dispose (`_code_editable.dart`).

Drop this copy and depend on pub.dev again once upstream has these.
