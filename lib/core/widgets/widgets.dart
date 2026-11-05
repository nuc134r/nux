export 'package:tab_switcher/tab_switcher.dart' show StartEllipsisText;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../activity/activity_center.dart';

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
  // Kept in Activity too: a snackbar is easily missed (or hidden under the drawer).
  try {
    ProviderScope.containerOf(context, listen: false)
        .read(activityCenterProvider)
        .event(ActivitySource.other, text, unread: false);
  } catch (_) {
    // No app around it (a widget test of one screen).
  }
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
