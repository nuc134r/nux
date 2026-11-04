import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'start_ellipsis_text.dart';
import 'switcher_tab.dart';

/// Builds the header row for [tab]; null [tab] means the grid is shown.
typedef TabHeaderBuilder = Widget Function(BuildContext context, SwitcherTab? tab);

/// An extra entry in a tab's long-press menu.
class TabAction {
  const TabAction({required this.icon, required this.label, required this.onSelected});

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// Texts the switcher shows itself (pass translated ones).
class TabSwitcherStrings {
  const TabSwitcherStrings({
    this.noTabs = 'No open tabs',
    this.close = 'Close',
    this.closeOthers = 'Close other tabs',
    this.pin = 'Pin',
    this.unpin = 'Unpin',
    this.pinned = 'Pinned',
    this.undo = 'Undo',
    this.closed = _closed,
    this.noPreview = 'No preview',
  });

  final String noTabs;
  final String close;
  final String closeOthers;
  final String pin;
  final String unpin;
  final String pinned;
  final String undo;
  final String Function(String title) closed;
  final String noPreview;

  static String _closed(String title) => 'Closed $title';
}

/// Full-screen tabs. Narrow screens: swipe the header sideways to switch, down for the grid.
/// Wide screens ([wideBreakpoint] and up): a tab strip above the header.
class TabSwitcher extends StatefulWidget {
  const TabSwitcher({
    super.key,
    required this.controller,
    required this.headerBuilder,
    this.emptyBuilder,
    this.gridFooterBuilder,
    this.actionsBuilder,
    this.stripTrailing,
    this.strings = const TabSwitcherStrings(),
    this.headerHeight = kToolbarHeight,
    this.wideBreakpoint = 840,
    this.previewScale = .6,
    this.headerColor,
  });

  final TabSwitcherController controller;
  final TabHeaderBuilder headerBuilder;

  /// Shown in the grid when there are no tabs.
  final WidgetBuilder? emptyBuilder;

  /// Shown under the grid (e.g. "new tab" buttons).
  final WidgetBuilder? gridFooterBuilder;

  /// Extra long-press menu entries for a tab (e.g. "Duplicate").
  final List<TabAction> Function(BuildContext context, SwitcherTab tab)? actionsBuilder;

  /// Shown at the end of the wide-layout tab strip (e.g. a "+" button).
  final Widget? stripTrailing;

  final TabSwitcherStrings strings;
  final double headerHeight;
  final double wideBreakpoint;

  /// Resolution of preview images relative to the screen's physical pixels (grid cards show tabs at
  /// about half size, so a bit over .5 keeps them sharp on any density).
  final double previewScale;

  /// The header's background; defaults to the colour scheme's `surfaceContainer`, set apart from the
  /// tab content by a hairline.
  final Color? headerColor;

  /// Whether the tab content around [context] is the one in front (not parked, not a neighbour being
  /// swiped in, not under the grid). Live tabs stay mounted, so a `PopScope` in a tab should only act
  /// when this is true. True outside a [TabSwitcher].
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ActiveTab>()?.active ?? true;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _ActiveTab extends InheritedWidget {
  const _ActiveTab({required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(_ActiveTab old) => active != old.active;
}

class _TabSwitcherState extends State<TabSwitcher> {
  TabSwitcherController get _c => widget.controller;

  late PageController _pages;
  final Map<String, GlobalKey> _boundaries = {};
  Set<String> _live = {};
  final Set<String> _parked = {};
  String? _shownId;
  bool _shownGrid = true;

  /// True while a header swipe animates to a page, so its page changes don't select tabs.
  bool _jumping = false;

  /// True while the user drags the header: only then does the body follow the header's page.
  final _swiping = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _pages = _newPages();
    _live = _c.liveIds;
    _shownId = _c.current?.id;
    _shownGrid = _c.gridOpen;
    _c.addListener(_changed);
  }

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _pages.dispose();
    _swiping.dispose();
    super.dispose();
  }

  void _changed() {
    final current = _c.current;
    // The tab being left was painted last frame: keep a picture of it for the grid.
    if (_shownId != null && (_shownId != current?.id || (!_shownGrid && _c.gridOpen))) _capture(_shownId!);

    final live = _c.liveIds;
    for (final t in _c.tabs) {
      final was = _live.contains(t.id), now = live.contains(t.id);
      if (was && !now && _parked.add(t.id)) t.onParked();
      if (now && _parked.remove(t.id)) t.onResumed();
    }
    _parked.removeWhere((id) => !_c.tabs.any((t) => t.id == id));
    _boundaries.removeWhere((id, _) => !_c.tabs.any((t) => t.id == id));
    _live = live;
    _shownId = current?.id;
    _shownGrid = _c.gridOpen;

    setState(() {});
    // The header's PageView learns about new tabs in this rebuild, so jump after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPage());
  }

  /// keepPage off: a restored page (from before tabs were closed in the grid) would be out of range and
  /// spring back into place, sliding the header in.
  PageController _newPages() => PageController(initialPage: _c.currentIndex.clamp(0, 1 << 30), keepPage: false);

  /// The header's PageView is unmounted while the grid (or the wide strip) shows; when it comes back it
  /// starts on the current tab instead of where it was.
  void _resetPagesIfDetached() {
    if (_pages.hasClients || _pages.initialPage == _c.currentIndex.clamp(0, 1 << 30)) return;
    final old = _pages;
    _pages = _newPages();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _syncPage() {
    final index = _c.currentIndex;
    if (!mounted || index < 0 || !_pages.hasClients || _pages.positions.length != 1) return;
    if ((_pages.page ?? -1).round() == index && _pages.page == _pages.page?.roundToDouble()) return;
    _jumping = true;
    _pages.jumpToPage(index);
    _jumping = false;
  }

  void _capture(String id) {
    final tab = _c.find<SwitcherTab>((t) => t.id == id);
    final boundary = _boundaries[id]?.currentContext?.findRenderObject();
    if (tab == null || boundary is! RenderRepaintBoundary || !boundary.attached || !boundary.hasSize) return;
    // An unpainted boundary has no layer and toImage throws at once (in release builds too: the old
    // `debugNeedsPaint` guard only worked in debug builds), so the call is guarded instead.
    try {
      // toImage takes the layer now and rasterizes it later, so this is still the picture of the tab
      // being left even though the next frame shows another one.
      boundary
          .toImage(pixelRatio: View.of(context).devicePixelRatio * widget.previewScale)
          .then(
            (image) => _c.setPreview(tab, image),
            onError: (Object _) {}, // keep the old preview
          );
    } catch (_) {
      // A preview is never worth failing a tab switch over (this runs before the switch is shown).
    }
  }

  /// Whether [tab] may close (asks when it has unsaved changes).
  Future<bool> _mayClose(SwitcherTab tab) async =>
      !tab.hasUnsavedChanges || _c.confirmClose == null || await _c.confirmClose!(tab);

  Future<void> _closeWithUndo(SwitcherTab tab, {bool force = false}) async {
    final title = tab.title;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await _c.close(tab, force: force)) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // With an action Flutter keeps a snackbar until it is used; Undo is only worth a few seconds.
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text(widget.strings.closed(title)),
          action: SnackBarAction(label: widget.strings.undo, onPressed: _c.reopenClosed),
        ),
      );
  }

  Future<void> _showMenu(SwitcherTab tab) async {
    HapticFeedback.mediumImpact();
    final s = widget.strings;
    final pinned = _c.isPinned(tab);
    final extra = widget.actionsBuilder?.call(context, tab) ?? const <TabAction>[];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(tab.icon ?? Icons.tab),
              title: Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: tab.subtitle == null
                  ? null
                  : tab.subtitle!.contains('/')
                  ? StartEllipsisText(tab.subtitle!)
                  : Text(tab.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            for (final a in extra)
              ListTile(
                leading: Icon(a.icon),
                title: Text(a.label),
                onTap: () {
                  Navigator.pop(sheet);
                  a.onSelected();
                },
              ),
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? s.unpin : s.pin),
              onTap: () {
                Navigator.pop(sheet);
                _c.setPinned(tab, !pinned);
              },
            ),
            if (_c.length > 1)
              ListTile(
                leading: const Icon(Icons.tab_unselected),
                title: Text(s.closeOthers),
                onTap: () {
                  Navigator.pop(sheet);
                  _c.closeOthers(tab);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.close),
              onTap: () {
                Navigator.pop(sheet);
                _closeWithUndo(tab);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= widget.wideBreakpoint;
    final grid = _c.gridOpen;
    if (!grid && !wide) _resetPagesIfDetached();
    return PopScope(
      canPop: !(grid && !_c.isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && grid && !_c.isEmpty) _c.gridOpen = false;
      },
      child: Scaffold(
        body: Column(
          children: [
            if (wide && !_c.isEmpty)
              _TabStrip(
                controller: _c,
                topPadding: media.padding.top,
                onClose: _closeWithUndo,
                onMenu: _showMenu,
                trailing: widget.stripTrailing,
              ),
            _Header(
              height: widget.headerHeight,
              topPadding: wide && !_c.isEmpty ? 0 : media.padding.top,
              color: widget.headerColor,
              overGrid: grid,
              onSwipeDown: () => _c.gridOpen = true,
              child: grid || wide
                  ? widget.headerBuilder(context, grid ? null : _c.current)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollStartNotification && n.dragDetails != null) _swiping.value = true;
                        if (n is ScrollEndNotification) {
                          _swiping.value = false;
                          final page = _pages.page?.round();
                          if (!_jumping && page != null && page != _c.currentIndex) _c.selectIndex(page);
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _pages,
                        physics: const SnappyPageScrollPhysics(),
                        itemCount: _c.length,
                        itemBuilder: (context, i) => widget.headerBuilder(context, _c.tabs[i]),
                      ),
                    ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: Stack(
                  children: [
                    // Live tabs stay mounted (offstage when hidden) so their state survives.
                    _Body(
                      controller: _c,
                      pages: _pages,
                      swiping: _swiping,
                      boundaryFor: (id) => _boundaries.putIfAbsent(id, GlobalKey.new),
                      hidden: grid,
                      slide: !wide,
                      noPreview: widget.strings.noPreview,
                    ),
                    if (grid)
                      Positioned.fill(
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: Column(
                            children: [
                              Expanded(
                                child: _c.isEmpty
                                    ? widget.emptyBuilder?.call(context) ?? Center(child: Text(widget.strings.noTabs))
                                    : _TabGrid(
                                        controller: _c,
                                        strings: widget.strings,
                                        onClose: _closeWithUndo,
                                        mayClose: _mayClose,
                                        onDismissed: (t) => _closeWithUndo(t, force: true),
                                        onMenu: _showMenu,
                                      ),
                              ),
                              ?widget.gridFooterBuilder?.call(context),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page physics that settle quickly: a stiff, critically damped spring, and short flicks already
/// change the page.
class SnappyPageScrollPhysics extends PageScrollPhysics {
  const SnappyPageScrollPhysics({super.parent});

  @override
  SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) => SnappyPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: .5, stiffness: 600, ratio: 1);

  @override
  double get minFlingVelocity => 150;

  @override
  double get minFlingDistance => 8;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.height,
    required this.topPadding,
    required this.color,
    required this.overGrid,
    required this.onSwipeDown,
    required this.child,
  });

  /// Above the grid the header is part of the background, not a tab's title bar.
  final bool overGrid;

  final double height;
  final double topPadding;
  final Color? color;
  final VoidCallback onSwipeDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: overGrid ? theme.colorScheme.surface : color ?? theme.colorScheme.surfaceContainer,
      shape: overGrid ? null : Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: .5)),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 150) onSwipeDown();
        },
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
  }
}

/// The live tabs, stacked. While the header is swiped, the current tab and its neighbour slide
/// along; a parked neighbour is shown by its preview.
class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.pages,
    required this.swiping,
    required this.boundaryFor,
    required this.hidden,
    required this.slide,
    required this.noPreview,
  });

  final TabSwitcherController controller;
  final PageController pages;
  final ValueListenable<bool> swiping;
  final GlobalKey Function(String id) boundaryFor;
  final bool hidden;
  final bool slide;
  final String noPreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: Listenable.merge([pages, swiping]),
        builder: (context, _) {
          final tabs = controller.tabs;
          final live = controller.liveIds;
          final current = controller.currentIndex;
          final following = slide && swiping.value && pages.hasClients && pages.positions.length == 1;
          final page = following ? (pages.page ?? current.toDouble()) : current.toDouble();
          final width = constraints.maxWidth;
          final neighbour = page < current ? current - 1 : (page > current ? current + 1 : -1);
          return Stack(
            children: [
              for (final (i, tab) in tabs.indexed)
                if (live.contains(tab.id))
                  KeyedSubtree(
                    key: ValueKey(tab.id),
                    child: _Slot(
                      offset: (i - page) * width,
                      visible: !hidden && (i == current || i == neighbour),
                      active: !hidden && i == current,
                      child: RepaintBoundary(
                        key: boundaryFor(tab.id),
                        child: Builder(builder: tab.buildContent),
                      ),
                    ),
                  ),
              if (!hidden && neighbour >= 0 && neighbour < tabs.length && !live.contains(tabs[neighbour].id))
                _Slot(
                  offset: (neighbour - page) * width,
                  visible: true,
                  active: false,
                  child: _Preview(image: controller.preview(tabs[neighbour]), fit: BoxFit.cover, noPreview: noPreview),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.offset, required this.visible, required this.active, required this.child});

  final double offset;
  final bool visible;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: active,
          child: FocusScope(
            canRequestFocus: active,
            child: _ActiveTab(
              active: active,
              child: Transform.translate(offset: Offset(offset, 0), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.image, required this.fit, required this.noPreview});

  final ui.Image? image;
  final BoxFit fit;
  final String noPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = this.image;
    if (image == null) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            noPreview,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: RawImage(image: image, fit: fit, alignment: Alignment.topCenter),
    );
  }
}

class _TabGrid extends StatefulWidget {
  const _TabGrid({
    required this.controller,
    required this.strings,
    required this.onClose,
    required this.mayClose,
    required this.onDismissed,
    required this.onMenu,
  });

  final TabSwitcherController controller;
  final TabSwitcherStrings strings;
  final void Function(SwitcherTab tab) onClose;
  final Future<bool> Function(SwitcherTab tab) mayClose;
  final void Function(SwitcherTab tab) onDismissed;
  final void Function(SwitcherTab tab) onMenu;

  @override
  State<_TabGrid> createState() => _TabGridState();
}

/// The grid of cards. Laid out here (not by a sliver grid) so cards can animate: closing one slides the
/// others to their new spots, a swiped card rides above its neighbours, and opening the grid zooms out
/// from the current tab while picking a card zooms into it. Opens scrolled to the current tab.
class _TabGridState extends State<_TabGrid> with SingleTickerProviderStateMixin {
  static const _pad = 12.0, _gap = 12.0, _headerHeight = 40.0, _aspect = .72;

  ScrollController? _scroll;

  /// 1: the plain grid; 0: zoomed into [_focus] (the card fills the screen width).
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  String? _focus;

  /// The card being swiped (drawn above the others).
  String? _dragging;
  bool _opening = true;
  bool _picking = false;

  TabSwitcherController get controller => widget.controller;
  TabSwitcherStrings get strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _focus = controller.current?.id;
    if (_focus != null) _zoom.value = 0;
  }

  @override
  void dispose() {
    _zoom.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  /// Sections: pinned first, then each group in order of first appearance, then the rest.
  Map<String?, List<SwitcherTab>> _sections() {
    final tabs = controller.tabs;
    final sections = <String?, List<SwitcherTab>>{};
    final pinned = tabs.where(controller.isPinned).toList();
    if (pinned.isNotEmpty) sections[strings.pinned] = pinned;
    final hasGroups = tabs.any((t) => t.group != null);
    for (final t in tabs.where((t) => !controller.isPinned(t))) {
      sections.putIfAbsent(hasGroups ? t.group : null, () => []).add(t);
    }
    return sections;
  }

  /// Picks a card: zooms into it, then shows its tab.
  Future<void> _open(SwitcherTab tab) async {
    // A tap during the opening zoom still picks the card (it takes over from that zoom); a second
    // tap while zooming in is ignored.
    if (_picking) return;
    _picking = true;
    _zoom.stop();
    setState(() => _focus = tab.id);
    await _zoom.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeInCubic);
    if (mounted) controller.select(tab);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections();
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 220).floor().clamp(2, 6);
        final cardW = (width - 2 * _pad - _gap * (columns - 1)) / columns;
        final cardH = cardW / _aspect;
        final showHeaders = sections.length > 1 || sections.keys.any((k) => k != null);
        final rects = <String, Rect>{};
        final headers = <(double, String)>[];
        var y = 0.0;
        for (final MapEntry(key: title, value: list) in sections.entries) {
          if (showHeaders) {
            headers.add((y, title ?? ''));
            y += _headerHeight;
          }
          for (final (i, t) in list.indexed) {
            rects[t.id] = Rect.fromLTWH(
              _pad + (i % columns) * (cardW + _gap),
              y + _pad + (i ~/ columns) * (cardH + _gap),
              cardW,
              cardH,
            );
          }
          final rows = (list.length + columns - 1) ~/ columns;
          y += 2 * _pad + rows * (cardH + _gap) - _gap;
        }
        final total = y;
        final viewport = constraints.maxHeight;
        // Created once the layout is known, already scrolled so the current card is in view.
        final current = controller.current;
        _scroll ??= ScrollController(
          initialScrollOffset: current == null || rects[current.id] == null
              ? 0
              : (rects[current.id]!.top - viewport / 4).clamp(0, math.max(0, total - viewport)).toDouble(),
        );
        if (_opening) {
          _opening = false;
          if (_focus != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _zoom.animateTo(1, curve: Curves.easeOutCubic));
          }
        }

        final tabs = [for (final list in sections.values) ...list];
        // The swiped card last, so it is painted over its neighbours.
        tabs.sort((a, b) => (a.id == _dragging ? 1 : 0) - (b.id == _dragging ? 1 : 0));
        final grid = SizedBox(
          height: total,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (top, title) in headers)
                Positioned(
                  left: 16,
                  right: 16,
                  top: top + 16,
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              for (final t in tabs)
                AnimatedPositioned.fromRect(
                  key: ValueKey(t.id),
                  rect: rects[t.id]!,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: _SwipeCard(
                    width: cardW,
                    enabled: !controller.isPinned(t),
                    onDragStart: () => setState(() => _dragging = t.id),
                    onDragEnd: () => setState(() => _dragging = null),
                    mayClose: () => widget.mayClose(t),
                    onDismissed: () => widget.onDismissed(t),
                    child: _TabCard(
                      tab: t,
                      current: t == current,
                      pinned: controller.isPinned(t),
                      preview: controller.preview(t),
                      noPreview: strings.noPreview,
                      closeTooltip: strings.close,
                      onTap: () => _open(t),
                      onClose: () => widget.onClose(t),
                      onMenu: () => widget.onMenu(t),
                    ),
                  ),
                ),
            ],
          ),
        );
        return AnimatedBuilder(
          animation: _zoom,
          child: SingleChildScrollView(controller: _scroll, child: grid),
          builder: (context, child) {
            final t = _zoom.value;
            final focus = rects[_focus];
            if (t >= 1 || focus == null || !(_scroll?.hasClients ?? false) && t >= 1) return child!;
            // Zoomed around the focused card: at 0 it fills the width, centred in the screen.
            final offset = _scroll!.hasClients ? _scroll!.offset : _scroll!.initialScrollOffset;
            final r = focus.translate(0, -offset);
            final full = width / r.width;
            final scale = ui.lerpDouble(full, 1, t)!;
            final dx = ui.lerpDouble(width / 2 - r.center.dx * full, 0, t)!;
            final dy = ui.lerpDouble(viewport / 2 - r.center.dy * full, 0, t)!;
            return ClipRect(
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(dx, dy, 0, 1)
                  ..scaleByDouble(scale, scale, 1, 1),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

/// A card that can be swiped sideways to close: it fades as it goes and casts a shadow over the cards it
/// crosses; past the closing point a haptic tick says "let go to close".
class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    required this.width,
    required this.enabled,
    required this.onDragStart,
    required this.onDragEnd,
    required this.mayClose,
    required this.onDismissed,
    required this.child,
  });

  /// The card's width (known from the grid's layout).
  final double width;
  final bool enabled;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Future<bool> Function() mayClose;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
    ..addListener(() => setState(() => _dx = _settleTween.evaluate(_settle)));
  Tween<double> _settleTween = Tween(begin: 0, end: 0);
  double _dx = 0;
  bool _armed = false;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  double get _width => widget.width;
  double get _threshold => _width * .4;

  Future<void> _animateTo(double target) {
    _settleTween = Tween(begin: _dx, end: target);
    return _settle.forward(from: 0);
  }

  void _update(DragUpdateDetails d) {
    setState(() => _dx += d.delta.dx);
    final armed = _dx.abs() >= _threshold;
    if (armed != _armed) {
      _armed = armed;
      // A tick where letting go starts closing the tab (and a lighter one when it no longer would).
      armed ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
  }

  Future<void> _end(DragEndDetails d) async {
    final v = d.primaryVelocity ?? 0;
    final flung = v.abs() > 900 && v.sign == _dx.sign;
    if ((_armed || flung) && await widget.mayClose()) {
      await _animateTo(_dx.sign * _width * 1.4);
      _armed = false;
      widget.onDismissed();
      widget.onDragEnd();
      return;
    }
    _armed = false;
    await _animateTo(0);
    if (mounted) widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_dx.abs() / (_width * 1.2)).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: (_) {
        _settle.stop();
        widget.onDragStart();
      },
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: Transform.translate(
        offset: Offset(_dx, 0),
        child: Opacity(
          opacity: 1 - progress * .85,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: progress == 0
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .35 * math.min(1, progress * 3)),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.current,
    required this.pinned,
    required this.preview,
    required this.noPreview,
    required this.closeTooltip,
    required this.onTap,
    required this.onClose,
    required this.onMenu,
  });

  final SwitcherTab tab;
  final bool current;
  final bool pinned;
  final ui.Image? preview;
  final String noPreview;
  final String closeTooltip;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = Material(
      color: current ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: current ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  Icon(pinned ? Icons.push_pin : tab.icon ?? Icons.tab, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (tab.hasUnsavedChanges) Icon(Icons.circle, size: 8, color: scheme.tertiary),
                  IconButton(
                    tooltip: closeTooltip,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            if (tab.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                // Paths keep their end (the folder), cutting the start.
                child: tab.subtitle!.contains('/')
                    ? StartEllipsisText(
                        tab.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    : Text(
                        tab.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _Preview(image: preview, fit: BoxFit.fitWidth, noPreview: noPreview),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return card;
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.controller,
    required this.topPadding,
    required this.onClose,
    required this.onMenu,
    this.trailing,
  });

  final TabSwitcherController controller;
  final double topPadding;
  final void Function(SwitcherTab tab) onClose;
  final void Function(SwitcherTab tab) onMenu;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  children: [
                    for (final t in controller.tabs)
                      Padding(
                        key: ValueKey(t.id),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _StripTab(
                          tab: t,
                          current: t == controller.current,
                          pinned: controller.isPinned(t),
                          onTap: () => controller.select(t),
                          onClose: () => onClose(t),
                          onMenu: () => onMenu(t),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _StripTab extends StatelessWidget {
  const _StripTab({
    required this.tab,
    required this.current,
    required this.pinned,
    required this.onTap,
    required this.onClose,
    required this.onMenu,
  });

  final SwitcherTab tab;
  final bool current;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: current ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onMenu,
        onSecondaryTap: onMenu,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: pinned ? 56 : 220, minWidth: pinned ? 40 : 120),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(pinned ? Icons.push_pin : tab.icon ?? Icons.tab, size: 16),
                if (!pinned) ...[
                  const SizedBox(width: 6),
                  Flexible(child: Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (tab.hasUnsavedChanges) Icon(Icons.circle, size: 8, color: scheme.tertiary),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ] else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
