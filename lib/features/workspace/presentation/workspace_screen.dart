import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../app/router.dart';
import '../../../core/background/background_providers.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../forwarding/data/forwarding_providers.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../terminal/domain/terminal_tab.dart';
import '../../updates/presentation/update_ui.dart';
import '../data/tab_factory.dart';
import '../data/workspace.dart';
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
          const SizedBox(width: 16),
        if (tab != null) ...[
          Icon(tab.icon ?? Icons.tab, size: 20, color: tab.color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
        ],
        Expanded(
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
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        // Only the tab count and the menu: every action lives in the menu.
        TabCountButton(controller: controller, tooltip: l10n.showTabs),
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
                settings,
              ];
            }
            return [
              NuxMenuAction(
                icon: Icons.add,
                label: l10n.newTab,
                onSelected: () => controller.open(ref.read(tabFactoryProvider).hosts()),
              ),
              const NuxMenuDivider(),
              if (find.isNotEmpty) ...[...find, const NuxMenuDivider()],
              NuxMenuAction(
                icon: Icons.dns_outlined,
                label: l10n.hosts,
                onSelected: () => controller.open(ref.read(tabFactoryProvider).hosts()),
              ),
              NuxMenuAction(icon: Icons.bolt, label: l10n.quickConnect, onSelected: () => quickConnect(context, ref)),
              NuxMenuAction(icon: Icons.key, label: l10n.keys, onSelected: () => context.push(Routes.keys)),
              NuxMenuAction(
                icon: Icons.lan_outlined,
                label: 'ZeroTier',
                onSelected: () => context.push(Routes.zerotier),
              ),
              const NuxMenuDivider(),
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
    return ListView(
      children: [
        const UpdateBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _GridFooter extends ConsumerWidget {
  const _GridFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.dns_outlined),
              label: Text(l10n.hosts),
              onPressed: () => ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).hosts()),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.bolt),
              label: Text(l10n.quickConnect),
              onPressed: () => quickConnect(context, ref),
            ),
          ],
        ),
      ),
    );
  }
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
