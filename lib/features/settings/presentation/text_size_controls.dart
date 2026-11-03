import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../data/settings_repository.dart';

double watchTextSize(WidgetRef ref, TextSizeKind kind) =>
    ref.watch(appSettingsProvider.select((s) => s.value?.textSize(kind) ?? kind.defaultSize));

/// "Text size  − 14 +" for a tab's menu; changes apply at once.
NuxMenuItem textSizeMenuItem(TextSizeKind kind) => NuxMenuCustom((context) => TextSizeStepper(kind: kind));

class TextSizeStepper extends ConsumerWidget {
  const TextSizeStepper({super.key, required this.kind});

  final TextSizeKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final size = watchTextSize(ref, kind);
    void step(double by) => ref.read(settingsRepositoryProvider).setTextSize(kind, (size + by).roundToDouble());
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 10, 2),
      child: Row(
        children: [
          Icon(Icons.format_size, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Text(l10n.textSize, style: theme.textTheme.bodyLarge)),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.smallerText,
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: size > TextSizeKind.min ? () => step(-1) : null,
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${size.round()}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.largerText,
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: size < TextSizeKind.max ? () => step(1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-finger pinch over [child] changes the [kind] text size (whole points, saved at once).
/// A raw [Listener], so it never competes with the child's own gestures.
class PinchTextSize extends ConsumerStatefulWidget {
  const PinchTextSize({super.key, required this.kind, required this.child});

  final TextSizeKind kind;
  final Widget child;

  @override
  ConsumerState<PinchTextSize> createState() => _PinchTextSizeState();
}

class _PinchTextSizeState extends ConsumerState<PinchTextSize> {
  final _pointers = <int, Offset>{};
  double? _startDistance;
  double _startSize = 0;
  double _applied = 0;

  double get _distance {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _startDistance = _distance;
      _startSize = _applied = ref.read(appSettingsProvider).value?.textSize(widget.kind) ?? widget.kind.defaultSize;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _startDistance;
    if (start == null || _pointers.length != 2 || start < 1) return;
    final size = (_startSize * _distance / start).roundToDouble().clamp(TextSizeKind.min, TextSizeKind.max).toDouble();
    if (size != _applied) {
      _applied = size;
      ref.read(settingsRepositoryProvider).setTextSize(widget.kind, size);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _startDistance = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
