import 'package:flutter/material.dart';

import 'controller.dart';

/// The square-with-a-number button that toggles the tab grid.
class TabCountButton extends StatelessWidget {
  const TabCountButton({super.key, required this.controller, this.tooltip, this.badge});

  final TabSwitcherController controller;
  final String? tooltip;

  /// Drawn over the top-right corner of the count (e.g. a dot for something new).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.length;
        return IconButton(
          tooltip: tooltip,
          onPressed: controller.toggleGrid,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? ':D' : '$count',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
              if (badge != null) Positioned(top: -5, right: -5, child: badge!),
            ],
          ),
        );
      },
    );
  }
}
