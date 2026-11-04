import 'package:flutter/material.dart';

/// One line of text that, when too long, keeps its end and cuts the start (`…/lib/src/main.dart`):
/// for paths, where the last part matters most.
class StartEllipsisText extends StatelessWidget {
  const StartEllipsisText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style.merge(this.style);
        final scaler = MediaQuery.textScalerOf(context);
        bool fits(String s) {
          // Laid out unconstrained: its natural width must fit (a path has break points, so a width-limited
          // layout could wrap it instead of overflowing).
          final painter = TextPainter(
            text: TextSpan(text: s, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final ok = painter.width <= constraints.maxWidth;
          painter.dispose();
          return ok;
        }

        if (!constraints.hasBoundedWidth || fits(text)) return Text(text, style: this.style, maxLines: 1);
        // The longest tail that fits after the ellipsis (binary search on where it starts).
        var lo = 1, hi = text.length;
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (fits('…${text.substring(mid)}')) {
            hi = mid;
          } else {
            lo = mid + 1;
          }
        }
        return Text('…${text.substring(lo)}', style: this.style, maxLines: 1, overflow: TextOverflow.clip);
      },
    );
  }
}
