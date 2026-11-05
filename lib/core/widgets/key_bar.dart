import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../keys/key_bar_layout.dart';

/// How a modifier key looks: off, on for the next key, or locked on.
enum KeyLatch { off, once, locked }

/// Extra keys above the keyboard, in rows. A row that fits fills the width; one that does not scrolls.
///
/// Tap types a key. Held, a key with long-press alternates shows them (slide to one and let go); other
/// keys repeat (arrows, ⌫, symbols). Ctrl / Alt: tap for the next key, hold to lock. The bar never takes
/// focus, so the keyboard stays up.
class KeyBar extends StatelessWidget {
  const KeyBar({super.key, required this.rows, required this.onKey, this.latch, this.onLock, this.fit = false});

  /// A preview: every row fits the width (keys get as narrow as needed, nothing scrolls) and no room is
  /// kept for the system bars.
  final bool fit;

  final List<List<BarKey>> rows;

  /// A key (special name or text) was typed.
  final void Function(String token) onKey;

  /// The state of a modifier key.
  final KeyLatch Function(String token)? latch;

  /// A modifier key was held: lock it.
  final void Function(String token)? onLock;

  static const _minKeyWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowHeight = rows.length == 1 ? 46.0 : 40.0;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        bottom: !fit,
        left: !fit,
        right: !fit,
        child: LayoutBuilder(
          builder: (context, box) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                SizedBox(
                  height: rowHeight,
                  child: fit || row.length * _minKeyWidth <= box.maxWidth - 8
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(children: [for (final k in row) Expanded(child: _key(k))]),
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          children: [for (final k in row) _key(k)],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(BarKey k) => _KeyButton(
    barKey: k,
    latch: latch?.call(k.main) ?? KeyLatch.off,
    onKey: onKey,
    onLock: onLock,
    minWidth: fit ? 0 : _minKeyWidth,
  );
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.barKey,
    required this.latch,
    required this.onKey,
    this.onLock,
    this.minWidth = KeyBar._minKeyWidth,
  });

  final double minWidth;

  final BarKey barKey;
  final KeyLatch latch;
  final void Function(String token) onKey;
  final void Function(String token)? onLock;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  static const _holdDelay = Duration(milliseconds: 380);
  static const _repeatEvery = Duration(milliseconds: 55);
  static const _slop = 12.0;

  Timer? _hold;
  Timer? _repeat;
  Offset? _down;
  bool _pressed = false;

  /// The key was held: its tap on release is already done (repeat, lock or alternates).
  bool _held = false;

  OverlayEntry? _popup;
  final _popupChoice = ValueNotifier<int>(0);
  List<Rect> _choiceRects = const [];

  BarKey get _k => widget.barKey;

  void _type(String token) {
    HapticFeedback.selectionClick();
    widget.onKey(token);
  }

  void _onDown(PointerDownEvent e) {
    _down = e.position;
    _held = false;
    setState(() => _pressed = true);
    _hold = Timer(_holdDelay, _onHold);
  }

  void _onHold() {
    if (!mounted || _down == null) return;
    _held = true;
    if (isModifierKey(_k.main) && widget.onLock != null) {
      HapticFeedback.mediumImpact();
      widget.onLock!(_k.main);
    } else if (_k.alternates.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _showPopup();
    } else if (keyRepeats(_k.main)) {
      _type(_k.main);
      _repeat = Timer.periodic(_repeatEvery, (_) => widget.onKey(_k.main));
    } else {
      _held = false; // a plain key held long still types once on release
    }
  }

  void _onMove(PointerMoveEvent e) {
    final down = _down;
    if (down == null) return;
    if (_popup != null) {
      for (final (i, r) in _choiceRects.indexed) {
        if (e.position.dx >= r.left && e.position.dx < r.right) _popupChoice.value = i;
      }
      return;
    }
    // Moved before the hold: a scroll of the row, not a key press.
    if (!_held && (e.position - down).distance > _slop) _cancel();
  }

  void _onUp(PointerUpEvent e) {
    if (_down == null) return;
    if (_popup != null) {
      final options = [_k.main, ..._k.alternates];
      _type(options[_popupChoice.value]);
    } else if (!_held) {
      _type(_k.main);
    }
    _cancel();
  }

  void _cancel() {
    _hold?.cancel();
    _repeat?.cancel();
    _hold = _repeat = null;
    _down = null;
    _popup?.remove();
    _popup = null;
    if (mounted && _pressed) setState(() => _pressed = false);
  }

  /// The key and its alternates in a row above it; the first alternate is chosen until the finger moves.
  void _showPopup() {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (box == null || overlay == null) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final keyRect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final options = [_k.main, ..._k.alternates];
    const cell = 44.0, height = 46.0;
    final width = cell * options.length;
    final left = (keyRect.center.dx - cell / 2 - cell).clamp(4.0, overlayBox.size.width - width - 4);
    final top = keyRect.top - height - 6;
    final origin = overlayBox.localToGlobal(Offset(left, top));
    _choiceRects = [
      for (var i = 0; i < options.length; i++) Rect.fromLTWH(origin.dx + cell * i, origin.dy, cell, height),
    ];
    _popupChoice.value = options.length > 1 ? 1 : 0;
    final theme = Theme.of(context);
    _popup = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Material(
            elevation: 6,
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            child: ValueListenableBuilder<int>(
              valueListenable: _popupChoice,
              builder: (context, chosen, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, o) in options.indexed)
                    Container(
                      width: cell,
                      height: height,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == chosen ? theme.colorScheme.primary : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            keyLabel(o),
                            style: TextStyle(
                              fontFamily: monoFont,
                              fontSize: 17,
                              color: i == chosen ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_popup!);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _repeat?.cancel();
    _popup?.remove();
    _popupChoice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latch = widget.latch;
    final label = keyLabel(_k.main);
    final special = isSpecialKey(_k.main);
    final background = switch (latch) {
      KeyLatch.locked => scheme.primary,
      KeyLatch.once => scheme.primaryContainer,
      KeyLatch.off => _pressed ? scheme.surfaceContainerHighest : Colors.transparent,
    };
    final foreground = switch (latch) {
      KeyLatch.locked => scheme.onPrimary,
      KeyLatch.once => scheme.onPrimaryContainer,
      KeyLatch.off => special ? scheme.onSurfaceVariant : scheme.onSurface,
    };
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _cancel(),
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          constraints: BoxConstraints(minWidth: widget.minWidth),
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
          padding: EdgeInsets.symmetric(horizontal: widget.minWidth == 0 ? 2 : 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: monoFont,
                    fontSize: special && label.length > 1 ? 13 : 17,
                    fontWeight: special ? FontWeight.w600 : FontWeight.w400,
                    color: foreground,
                  ),
                ),
              ),
              // A dot: this key has more on long press.
              if (_k.alternates.isNotEmpty)
                Positioned(
                  top: 2,
                  right: -2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: scheme.outline, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
