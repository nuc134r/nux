import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/platform/content.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../workspace/data/tab_factory.dart';
import '../../workspace/data/workspace.dart';
import '../domain/transfers.dart';
import 'file_sharing.dart';

/// What other apps hand to nux: "Open with" opens the file in an editor tab; "Share" asks for a host and
/// opens its files, where the user goes to the folder and taps Upload here. Watched by the home screen.
final incomingHandlerProvider = Provider<void>((ref) {
  final files = ref.watch(contentFilesProvider);
  final sub = files.incoming.listen((incoming) => unawaited(_handle(ref, files, incoming)));
  ref.onDispose(sub.cancel);
  unawaited(Future.microtask(files.start));
});

Future<void> _handle(Ref ref, ContentFiles files, Incoming incoming) async {
  final tabs = ref.read(workspaceProvider);
  final factory = ref.read(tabFactoryProvider);
  if (incoming.action != IncomingAction.send) {
    for (final item in incoming.items) {
      tabs.open(factory.content(files, item));
    }
    tabs.gridOpen = false;
    return;
  }
  final uploads = contentUploads(files, incoming.items);
  final text = incoming.text;
  if (uploads.isEmpty && text != null && text.isNotEmpty) {
    final bytes = utf8.encode(text);
    uploads.add(
      UploadSource(name: 'shared.txt', size: bytes.length, open: (start) => Stream.value(bytes.sublist(start))),
    );
  }
  if (uploads.isEmpty) return;
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final hosts = ref.read(connectionsProvider).value ?? await ref.read(connectionRepositoryProvider).watchAll().first;
  if (!context.mounted) return;
  final host = await showDialog<Connection>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.uploadSharedTitle(uploads.length)),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: hosts.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noHosts))
            : SizedBox(
                width: 360,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in hosts)
                      ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: Text(h.name),
                        onTap: () => Navigator.pop(context, h),
                      ),
                  ],
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))],
      );
    },
  );
  if (host == null) return;
  final tab = factory.files(host.id)..setPendingUploads(uploads);
  tabs
    ..open(tab)
    ..gridOpen = false;
}
