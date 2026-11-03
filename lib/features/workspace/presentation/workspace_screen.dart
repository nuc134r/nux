import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tab_switcher/tab_switcher.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../forwarding/data/forwarding_providers.dart';
import '../../terminal/domain/terminal_tab.dart';
import '../../updates/presentation/update_ui.dart';
import '../data/tab_factory.dart';
import '../data/workspace.dart';
import '../domain/nux_tab.dart';

/// The home screen: every open tab, Chrome style.
class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.watch(workspaceProvider);
    if (ref.watch(workspaceReadyProvider).isLoading) return const Scaffold();
    // Rules marked "start with nux" start once the screen (and its dialogs) can be shown.
    ref.watch(forwardingAutoStartProvider);
    return TabSwitcher(
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
    final entries = tab?.menuEntries(context) ?? const <TabMenuEntry>[];
    return Row(
      children: [
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
              Text(
                tab?.title ?? l10n.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: tab == null ? 'JetBrains Mono' : null,
                  fontWeight: tab == null ? FontWeight.w600 : null,
                ),
              ),
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
        ...?tab?.buildActions(context),
        if (tab == null)
          IconButton(
            tooltip: l10n.newTab,
            icon: const Icon(Icons.add),
            onPressed: () => controller.open(ref.read(tabFactoryProvider).hosts()),
          ),
        TabCountButton(controller: controller, tooltip: l10n.showTabs),
        PopupMenuButton<VoidCallback>(
          tooltip: l10n.more,
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            for (final e in entries)
              PopupMenuItem(value: e.onSelected, enabled: e.enabled, child: ListTile(leading: Icon(e.icon), title: Text(e.label))),
            if (entries.isNotEmpty) const PopupMenuDivider(),
            PopupMenuItem(
              value: () => controller.open(ref.read(tabFactoryProvider).hosts()),
              child: ListTile(leading: const Icon(Icons.dns_outlined), title: Text(l10n.hosts)),
            ),
            PopupMenuItem(
              value: () => quickConnect(context, ref),
              child: ListTile(leading: const Icon(Icons.bolt), title: Text(l10n.quickConnect)),
            ),
            PopupMenuItem(
              value: () => context.push(Routes.forwarding),
              child: ListTile(leading: const Icon(Icons.swap_horiz), title: Text(l10n.portForwarding)),
            ),
            PopupMenuItem(
              value: () => context.push(Routes.keys),
              child: ListTile(leading: const Icon(Icons.key), title: Text(l10n.keys)),
            ),
            PopupMenuItem(
              value: () => context.push(Routes.settings),
              child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(l10n.settings)),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
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
