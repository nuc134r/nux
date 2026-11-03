import 'package:flutter/material.dart';

/// An entry of a [NuxMenuButton] menu.
sealed class NuxMenuItem {
  const NuxMenuItem();
}

/// A tappable row; closes the menu, then runs [onSelected].
class NuxMenuAction extends NuxMenuItem {
  const NuxMenuAction({required this.icon, required this.label, required this.onSelected, this.enabled = true});

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

class NuxMenuDivider extends NuxMenuItem {
  const NuxMenuDivider();
}

/// Any widget (e.g. a stepper); the menu stays open while it is used.
class NuxMenuCustom extends NuxMenuItem {
  const NuxMenuCustom(this.builder);

  final WidgetBuilder builder;
}

/// A "⋮" button that opens a quick, anchored menu (faster and roomier than [PopupMenuButton]).
class NuxMenuButton extends StatelessWidget {
  const NuxMenuButton({super.key, required this.items, this.tooltip, this.icon = const Icon(Icons.more_vert)});

  /// Built when the menu opens, so it reflects the current state.
  final List<NuxMenuItem> Function(BuildContext context) items;
  final String? tooltip;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, icon: icon, onPressed: () => showNuxMenu(context, items));
  }
}

/// Opens the menu under the widget of [context] (aligned to its right edge).
Future<void> showNuxMenu(BuildContext context, List<NuxMenuItem> Function(BuildContext context) items) async {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final action = await Navigator.of(context).push<VoidCallback>(
    _NuxMenuRoute(
      anchor: anchor,
      items: items,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(from: context, to: Navigator.of(context).context),
    ),
  );
  action?.call();
}

class _NuxMenuRoute extends PopupRoute<VoidCallback> {
  _NuxMenuRoute({required this.anchor, required this.items, required this.barrierLabel, required this.capturedThemes});

  final Rect anchor;
  final List<NuxMenuItem> Function(BuildContext context) items;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.black12;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 140);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 90);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return capturedThemes.wrap(
      LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final right = (constraints.maxWidth - anchor.right + 4).clamp(8.0, constraints.maxWidth);
          final top = anchor.top + 4;
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
          return Stack(
            children: [
              Positioned(
                top: top,
                right: right,
                child: FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    alignment: Alignment.topRight,
                    scale: Tween(begin: .85, end: 1.0).animate(curved),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 220,
                        maxWidth: (constraints.maxWidth - 16).clamp(0, 320),
                        maxHeight: constraints.maxHeight - top - media.padding.bottom - 8,
                      ),
                      child: _MenuPanel(items: items(context)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.items});

  final List<NuxMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5), width: .5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                switch (item) {
                  NuxMenuAction() => _ActionRow(item: item),
                  NuxMenuDivider() => Divider(height: 9, indent: 16, endIndent: 16, color: scheme.outlineVariant),
                  NuxMenuCustom() => Builder(builder: item.builder),
                },
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final NuxMenuAction item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: .38);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.enabled ? () => Navigator.of(context).pop(item.onSelected) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 20, 11),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: item.enabled ? theme.colorScheme.onSurfaceVariant : color),
              const SizedBox(width: 14),
              Flexible(
                child: Text(item.label, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
