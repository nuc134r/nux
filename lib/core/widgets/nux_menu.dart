import 'package:flutter/material.dart';

/// An entry of a [NuxMenuButton] menu.
sealed class NuxMenuItem {
  const NuxMenuItem();
}

/// A tappable row; closes the menu, then runs [onSelected].
class NuxMenuAction extends NuxMenuItem {
  const NuxMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
    this.checked,
    this.hint,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onSelected;
  final bool enabled;

  /// Shows a check mark when true (options in a submenu); null for plain actions.
  final bool? checked;

  /// Short text at the end of the row (e.g. "2 active").
  final String? hint;
}

/// A row that opens [items] in place of the menu (with a back row).
class NuxMenuSubmenu extends NuxMenuItem {
  const NuxMenuSubmenu({required this.icon, required this.label, required this.items, this.hint});

  final IconData icon;
  final String label;
  final List<NuxMenuItem> items;

  /// The current choice, shown at the end of the row (e.g. "Name").
  final String? hint;
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

/// Opens the menu over the widget of [context] (aligned to its right edge), or with [beside] just below
/// it (above it when it is low on the screen), leaving the widget visible (list items).
Future<void> showNuxMenu(
  BuildContext context,
  List<NuxMenuItem> Function(BuildContext context) items, {
  bool beside = false,
}) async {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final action = await Navigator.of(context).push<VoidCallback>(
    _NuxMenuRoute(
      anchor: anchor,
      beside: beside,
      items: items,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(from: context, to: Navigator.of(context).context),
    ),
  );
  action?.call();
}

class _NuxMenuRoute extends PopupRoute<VoidCallback> {
  _NuxMenuRoute({
    required this.anchor,
    required this.beside,
    required this.items,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final bool beside;
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
          // Beside a list item: below it, or above it when it sits in the lower part of the screen.
          final above = beside && anchor.bottom > constraints.maxHeight * .55;
          final top = beside ? anchor.bottom + 4 : anchor.top + 4;
          final bottom = constraints.maxHeight - anchor.top + 4;
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
          return Stack(
            children: [
              Positioned(
                top: above ? null : top,
                bottom: above ? bottom : null,
                right: right,
                child: FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    alignment: above ? Alignment.bottomRight : Alignment.topRight,
                    scale: Tween(begin: .85, end: 1.0).animate(curved),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 220,
                        maxWidth: (constraints.maxWidth - 16).clamp(0, 320),
                        maxHeight: above
                            ? anchor.top - media.padding.top - 8
                            : constraints.maxHeight - top - media.padding.bottom - 8,
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

/// Width of the menu panel (fits the longest labels, Russian included).
const double menuWidth = 280;

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.items});

  final List<NuxMenuItem> items;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  /// Open submenus, innermost last.
  final _stack = <NuxMenuSubmenu>[];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = _stack.lastOrNull;
    final items = _tidy(sub?.items ?? widget.items);
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5), width: .5),
      ),
      clipBehavior: Clip.antiAlias,
      // One width for the menu and its submenus, so pages switch in place.
      child: SizedBox(
        width: menuWidth,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topRight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(_stack.length),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sub != null) ...[
                      _Row(
                        icon: Icons.arrow_back,
                        label: sub.label,
                        bold: true,
                        onTap: () => setState(_stack.removeLast),
                      ),
                      Divider(height: 9, indent: 16, endIndent: 16, color: scheme.outlineVariant),
                    ],
                    for (final item in items)
                      switch (item) {
                        NuxMenuAction() => _Row(
                          icon: item.icon,
                          label: item.label,
                          enabled: item.enabled,
                          checked: item.checked,
                          hint: item.hint,
                          onTap: () => Navigator.of(context).pop(item.onSelected),
                        ),
                        NuxMenuSubmenu() => _Row(
                          icon: item.icon,
                          label: item.label,
                          hint: item.hint,
                          chevron: true,
                          onTap: () => setState(() => _stack.add(item)),
                        ),
                        NuxMenuDivider() => Divider(height: 9, indent: 16, endIndent: 16, color: scheme.outlineVariant),
                        NuxMenuCustom() => Builder(builder: item.builder),
                      },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Without dividers at the ends or next to each other (entries that only show sometimes leave them).
List<NuxMenuItem> _tidy(List<NuxMenuItem> items) {
  final out = <NuxMenuItem>[];
  for (final item in items) {
    if (item is NuxMenuDivider && (out.isEmpty || out.last is NuxMenuDivider)) continue;
    out.add(item);
  }
  while (out.isNotEmpty && out.last is NuxMenuDivider) {
    out.removeLast();
  }
  return out;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.checked,
    this.hint,
    this.chevron = false,
    this.bold = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool? checked;
  final String? hint;
  final bool chevron;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: .38);
    final muted = enabled ? scheme.onSurfaceVariant : color;
    final leading = checked == null ? icon : (checked! ? Icons.check : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 11, chevron ? 10 : 20, 11),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: leading == null
                    ? null
                    : Icon(leading, size: 20, color: checked == true ? scheme.primary : muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: bold || checked == true ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 12),
                Text(hint!, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
              if (chevron) ...[const SizedBox(width: 4), Icon(Icons.chevron_right, size: 20, color: muted)],
            ],
          ),
        ),
      ),
    );
  }
}
