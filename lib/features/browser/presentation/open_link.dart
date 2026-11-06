import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../workspace/data/workspace.dart';
import 'browser_tab.dart';

/// A web link tapped in a terminal or a file: asks whether to open it in a browser tab of nux or in another
/// app (or just copy it). Other schemes are ignored.
Future<void> askOpenLink(BuildContext context, Uri uri) async {
  if (uri.scheme != 'http' && uri.scheme != 'https') return;
  final tabs = ProviderScope.containerOf(context, listen: false).read(workspaceProvider);
  final choice = await showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.openLinkQuestion),
        content: SelectableText(uri.toString()),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uri.toString()));
              Navigator.pop(context);
            },
            child: Text(l10n.copy),
          ),
          TextButton(onPressed: () => Navigator.pop(context, 'app'), child: Text(l10n.openInApp)),
          FilledButton(onPressed: () => Navigator.pop(context, 'tab'), child: Text(l10n.openInTab)),
        ],
      );
    },
  );
  switch (choice) {
    case 'tab':
      openBrowserTab(tabs, '$uri');
      tabs.gridOpen = false;
    case 'app':
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
