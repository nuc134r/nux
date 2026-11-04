import 'package:flutter/material.dart';

/// A titled card grouping list tiles (settings sections and similar).
class Island extends StatelessWidget {
  const Island({super.key, this.title, required this.children, this.margin = const EdgeInsets.fromLTRB(12, 4, 12, 8)});

  final String? title;
  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) SectionTitle(title!),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// The add action of a full screen that lists things (Keys, Port forwarding, ZeroTier): one wide button
/// at the bottom, in reach of the thumb, instead of a FAB or a ⋮ entry. Goes in `Scaffold.bottomNavigationBar`.
class AddBar extends StatelessWidget {
  const AddBar({super.key, required this.label, required this.onPressed, this.icon = Icons.add});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: Icon(icon),
          label: Text(label),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

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
          final painter = TextPainter(
            text: TextSpan(text: s, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          final ok = !painter.didExceedMaxLines;
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
