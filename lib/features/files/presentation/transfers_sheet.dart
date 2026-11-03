import 'dart:io';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/files_providers.dart';
import '../domain/file_listing.dart';
import '../domain/transfers.dart';
import 'files_view.dart' show fileErrorText;

Future<void> showTransfersSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const TransfersSheet(),
    );

class TransfersSheet extends ConsumerWidget {
  const TransfersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final manager = ref.watch(transferManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final list = manager.transfers.reversed.toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.transfers, style: Theme.of(context).textTheme.titleMedium),
                  trailing: list.any((t) => !t.active)
                      ? TextButton(onPressed: manager.clearFinished, child: Text(l10n.clearFinished))
                      : null,
                ),
                if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l10n.noTransfers)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [for (final t in list) _TransferTile(t: t, manager: manager)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.t, required this.manager});

  final Transfer t;
  final TransferManager manager;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final up = t.direction == TransferDirection.upload;
    final status = switch (t.state) {
      TransferState.queued => l10n.transferQueued,
      TransferState.running => '${formatSize(t.done)} / ${formatSize(t.total)}',
      TransferState.done => up ? l10n.transferUploaded : l10n.transferDownloaded,
      TransferState.failed => fileErrorText(l10n, t.error ?? ''),
      TransferState.cancelled => l10n.transferCancelled,
    };
    return ListTile(
      leading: Icon(up ? Icons.upload : Icons.download),
      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.active) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: LinearProgressIndicator(value: t.fraction)),
          Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: switch (t.state) {
        TransferState.queued || TransferState.running =>
          IconButton(tooltip: l10n.cancel, icon: const Icon(Icons.close), onPressed: () => manager.cancel(t)),
        TransferState.failed || TransferState.cancelled =>
          IconButton(tooltip: l10n.resume, icon: const Icon(Icons.replay), onPressed: () => manager.retry(t)),
        TransferState.done when !up && t.localPath != null => PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (v) async {
              final file = File(t.localPath!);
              if (v == 'share') {
                await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
              } else {
                final saved = await FilePicker.saveFile(fileName: t.name, bytes: await file.readAsBytes());
                if (saved != null && context.mounted) showSnack(context, l10n.savedAs(t.name));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'save', child: ListTile(leading: const Icon(Icons.save_alt), title: Text(l10n.saveAs))),
              PopupMenuItem(value: 'share', child: ListTile(leading: const Icon(Icons.share_outlined), title: Text(l10n.share))),
            ],
          ),
        _ => null,
      },
    );
  }
}
