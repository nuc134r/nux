import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../app/router.dart';
import '../../../core/activity/activity_center.dart';
import '../../../core/activity/activity_view.dart';
import '../../../core/background/background_providers.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../../browser/domain/address.dart';
import '../../browser/presentation/browser_tab.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../files/presentation/incoming.dart';
import '../../forwarding/data/forwarding_providers.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../terminal/domain/terminal_tab.dart';
import '../../updates/data/update_service.dart';
import '../data/tab_factory.dart';
import '../../../core/db/database.dart' show Workspace;
import '../data/workspace.dart';
import '../data/workspace_repository.dart';
import '../domain/nux_tab.dart';
import 'workspace_drawer.dart';
import 'workspace_find.dart';

/// The scaffold holding the workspace drawer (tabs have scaffolds of their own).
final _scaffold = GlobalKey<ScaffoldState>();

/// The home screen: every open tab, Chrome style.
class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.watch(workspaceProvider);
    controller.confirmClose ??= (tab) async =>
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.discardChangesTitle(tab.title.replaceFirst('• ', ''))),
            content: Text(l10n.discardChangesBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.keepEditing)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.discard)),
            ],
          ),
        ) ??
        false;
    if (ref.watch(workspaceReadyProvider).isLoading) return const Scaffold();
    // Rules marked "start with nux" start once the screen (and its dialogs) can be shown.
    ref.watch(forwardingAutoStartProvider);
    ref.watch(zeroTierAutoStartProvider);
    // Open terminals and file browsers keep nux running in the background (with a notification).
    ref.watch(sshKeepAliveProvider);
    ref.watch(backgroundResyncProvider);
    // Files other apps open with or share to nux.
    ref.watch(incomingHandlerProvider);
    // An available update is an Activity event.
    ref.listen(availableUpdateProvider, (before, now) {
      final release = now.value;
      if (release == null || before?.value?.version == release.version) return;
      ref.read(activityCenterProvider).event(
        ActivitySource.update,
        l10n.activityUpdate(release.version),
        // Settings → update (closing the Activity sheet first).
        open: (context) {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(Routes.version);
        },
      );
    });
    return _KeyboardOnlyOnTop(
      child: Scaffold(
        key: _scaffold,
        // Opened with ☰ on the tab overview only: an edge swipe would fight terminals and editors.
        drawer: const WorkspaceDrawer(),
        drawerEnableOpenDragGesture: false,
        body: TabSwitcher(
          controller: controller,
          headerBuilder: (context, tab) => _Header(controller: controller, tab: tab as NuxTab?),
          emptyBuilder: (context) => const _NoTabs(),
          gridFooterBuilder: (context) => const _GridFooter(),
          stripTrailing: IconButton(
            tooltip: l10n.newTab,
            icon: const Icon(Icons.add),
            onPressed: () => controller.open(ref.read(tabFactoryProvider).hosts()),
          ),
          actionsBuilder: (context, tab) => [
            if (tab is TerminalTab)
              TabAction(
                icon: Icons.copy_all,
                label: l10n.duplicateTab,
                onSelected: () => openTerminal(ref, tab.connectionId),
              ),
          ],
          strings: TabSwitcherStrings(
            noTabs: l10n.noTabs,
            close: l10n.closeTab,
            closeOthers: l10n.closeOtherTabs,
            pin: l10n.pinTab,
            unpin: l10n.unpinTab,
            pinned: l10n.pinnedTabs,
            undo: l10n.undo,
            closed: l10n.tabClosed,
            noPreview: l10n.noPreview,
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.controller, required this.tab});

  final TabSwitcherController controller;
  final NuxTab? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tab = this.tab;
    final workspace = tab == null ? ref.watch(workspaceSwitcherProvider) : null;
    return Row(
      children: [
        if (workspace != null)
          // Over the tab overview: ☰ opens the workspace (project tree, git).
          IconButton(
            tooltip: l10n.workspaces,
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffold.currentState?.openDrawer(),
          )
        else
          const SizedBox(width: 4),
        if (tab != null) ...[
          // The tab's icon opens the workspace drawer too (☰ is only on the overview).
          IconButton(
            tooltip: l10n.workspaces,
            icon: Icon(tab.icon ?? Icons.tab, size: 20, color: tab.color ?? theme.colorScheme.onSurfaceVariant),
            onPressed: () => _scaffold.currentState?.openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tab?.onHeaderTap == null ? null : () => tab!.onHeaderTap!(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Over the tab grid: only the workspace's name, quietly.
                if (workspace != null)
                  ListenableBuilder(
                    listenable: workspace,
                    builder: (context, _) => Text(
                      workspace.current?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (tab != null)
                  Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                if (tab?.subtitle case final subtitle?)
                  // Paths keep their end (the folder the file is in), cutting the start.
                  subtitle.contains('/')
                      ? StartEllipsisText(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        )
                      : Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
              ],
            ),
          ),
        ),
        // Only the tab count and the menu: every action lives in the menu.
        TabCountButton(controller: controller, tooltip: l10n.showTabs, badge: const ActivityBadge()),
        _MenuButton(
          tab: tab,
          items: (_) {
            // Built when the menu opens (fresh state); actions run with the header's context.
            final entries = tab?.menuEntries(context) ?? const <NuxMenuItem>[];
            final sizeKind = tab?.textSizeKind;
            final settings = NuxMenuAction(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              onSelected: () => context.push(Routes.settings),
            );
            final activity = activityMenuItem(context, ref.read(activityCenterProvider));
            // In a workspace: find a file or text in it, from any tab.
            final ws = ref.read(workspaceSwitcherProvider).current;
            final find = [
              if (ws != null) ...[
                NuxMenuAction(icon: Icons.search, label: l10n.quickOpen, onSelected: () => showQuickOpen(context, ws)),
                NuxMenuAction(
                  icon: Icons.manage_search,
                  label: l10n.searchInFiles,
                  onSelected: () => showSearchInFiles(context, ws),
                ),
              ],
            ];
            if (tab != null) {
              return [
                if (sizeKind != null) textSizeMenuItem(sizeKind),
                if (sizeKind != null && entries.isNotEmpty) const NuxMenuDivider(),
                ...entries,
                // No divider above Settings when it is the only entry (e.g. the hosts tab).
                if (sizeKind != null || entries.isNotEmpty) const NuxMenuDivider(),
                if (find.isNotEmpty) ...[...find, const NuxMenuDivider()],
                activity,
                settings,
              ];
            }
            return [
              NuxMenuAction(
                icon: Icons.add,
                label: l10n.newTab,
                onSelected: () => controller.open(ref.read(tabFactoryProvider).hosts()),
              ),
              NuxMenuAction(
                icon: Icons.public,
                label: l10n.newBrowserTab,
                onSelected: () async {
                  final typed = await askAddress(context);
                  if (typed != null) openBrowserTab(controller, '${addressToUri(typed)}');
                },
              ),
              NuxMenuAction(
                icon: Icons.clear_all,
                label: l10n.closeAllTabs,
                enabled: !controller.isEmpty,
                onSelected: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.closeAllTabsTitle(controller.length)),
                      content: Text(l10n.closeAllTabsBody),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.closeAllTabs)),
                      ],
                    ),
                  );
                  if (ok == true) await controller.closeAll();
                },
              ),
              const NuxMenuDivider(),
              if (find.isNotEmpty) ...[...find, const NuxMenuDivider()],
              // The workspace: switch to another (or a new one), or close it.
              NuxMenuSubmenu(
                icon: Icons.swap_horiz,
                label: l10n.switchWorkspace,
                hint: ws?.name,
                items: [
                  for (final w in ref.read(workspacesProvider).value ?? const <Workspace>[])
                    NuxMenuAction(
                      icon: null,
                      label: w.name,
                      checked: w.id == ws?.id,
                      onSelected: () => ref.read(workspaceSwitcherProvider).switchTo(w.id),
                    ),
                  const NuxMenuDivider(),
                  NuxMenuAction(icon: Icons.add, label: l10n.newWorkspace, onSelected: () => newWorkspace(context, ref)),
                ],
              ),
              if (ws != null)
                NuxMenuAction(
                  icon: Icons.close,
                  label: l10n.closeWorkspace,
                  onSelected: () => ref.read(workspaceSwitcherProvider).switchTo(null),
                ),
              const NuxMenuDivider(),
              NuxMenuAction(
                icon: Icons.home_outlined,
                label: l10n.home,
                onSelected: () => controller.open(ref.read(tabFactoryProvider).hosts()),
              ),
              activity,
              settings,
            ];
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// The ⋮ button, with a dot when the tab asks for attention (e.g. transfers running).
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.tab, required this.items});

  final NuxTab? tab;
  final List<NuxMenuItem> Function(BuildContext context) items;

  @override
  Widget build(BuildContext context) {
    final tab = this.tab;
    Widget button(bool badge) => NuxMenuButton(
      tooltip: context.l10n.more,
      icon: Badge(isLabelVisible: badge, smallSize: 8, child: const Icon(Icons.more_vert)),
      items: items,
    );
    final changes = tab?.menuBadgeChanges;
    if (tab == null || changes == null) return button(tab?.menuBadge ?? false);
    return ListenableBuilder(listenable: changes, builder: (context, _) => button(tab.menuBadge));
  }
}

class _NoTabs extends ConsumerWidget {
  const _NoTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              // Centred in the free space, with the way out (the hosts) right under the text.
              Padding(
                padding: EdgeInsets.fromLTRB(24, math.max(48, constraints.maxHeight / 2 - 160), 24, 24),
                child: Column(
                  children: [
                    Icon(Icons.tab_unselected, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(l10n.noTabs, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      l10n.noTabsHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.home_outlined),
                          label: Text(l10n.home),
                          onPressed: () => ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).hosts()),
                        ),
                        const _ActivityButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridFooter extends ConsumerWidget {
  const _GridFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tabs = ref.watch(workspaceProvider);
    // Without tabs the empty state has the button, in the middle. Listened to: the footer is built once and
    // kept while tabs close, so it must notice the last one going.
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) => tabs.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.home_outlined),
                      label: Text(l10n.home),
                      onPressed: () => ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).hosts()),
                    ),
                    const _ActivityButton(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Next to Home on the tab overview: opens Activity; shows what runs or is new like the tab count does.
class _ActivityButton extends StatelessWidget {
  const _ActivityButton();

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    icon: const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_outlined),
        Positioned(top: -3, right: -3, child: ActivityBadge()),
      ],
    ),
    label: Text(context.l10n.activity),
    onPressed: () => showActivity(context),
  );
}

/// Under another screen (an editor, settings) the keyboard must not reach the tabs: each frame of its
/// animation rebuilt and resized the open terminal (cell metrics, a PTY resize) behind that screen, which
/// made forms with text fields stutter. The tabs are passed in built, and only see view insets while this
/// route is on top, so nothing under here rebuilds while covered.
class _KeyboardOnlyOnTop extends StatelessWidget {
  const _KeyboardOnlyOnTop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    return MediaQuery.removeViewInsets(context: context, removeBottom: covered, child: child);
  }
}
