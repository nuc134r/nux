import 'dart:async';

import 'package:flutter/widgets.dart';

/// Gives [child] the space it gets only once that has stopped changing for [delay]; meanwhile it keeps its
/// last size, kept to the bottom and clipped.
///
/// The soft keyboard slides in over a few hundred milliseconds, and a terminal resized on every frame of
/// that sends the server a new window size each time: the shell redraws for each, and the screen ends up
/// with repeated lines. Held like this, the terminal is resized once, when the keyboard is up. A change of
/// width (rotation, split screen) applies at once.
class SettledSize extends StatefulWidget {
  const SettledSize({super.key, required this.child, this.delay = const Duration(milliseconds: 160)});

  final Widget child;
  final Duration delay;

  @override
  State<SettledSize> createState() => _SettledSizeState();
}

class _SettledSizeState extends State<SettledSize> {
  Size? _size;
  Size? _pending;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _arm(Size now) {
    if (now == _pending) return;
    _pending = now;
    _settle?.cancel();
    _settle = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() {
        _size = _pending;
        _pending = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final now = box.biggest;
      final size = _size;
      if (size == null || size.width != now.width || !now.isFinite) {
        _settle?.cancel();
        _pending = null;
        _size = now;
      } else if (size != now) {
        _arm(now);
      } else {
        _settle?.cancel();
        _pending = null;
      }
      final held = _size!;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomLeft,
          minWidth: held.width,
          maxWidth: held.width,
          minHeight: held.height,
          maxHeight: held.height,
          child: widget.child,
        ),
      );
    },
  );
}
