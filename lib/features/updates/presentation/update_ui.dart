import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../data/update_service.dart';
import '../domain/release.dart';


Future<void> showReleaseDialog(BuildContext context, WidgetRef ref, Release release) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text(l10n.updateAvailable(release.version)),
      content: release.notes.trim().isEmpty
          ? null
          : SingleChildScrollView(child: SelectableText(release.notes.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.later)),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            installUpdate(context, ref, release);
          },
          child: Text(l10n.update),
        ),
      ],
    ),
  );
}

/// Downloads the release APK with a progress dialog and hands it to the system installer.
Future<void> installUpdate(BuildContext context, WidgetRef ref, Release release) async {
  final l10n = context.l10n;
  final Stream<OtaEvent> events;
  try {
    events = await ref.read(updateServiceProvider).install(release);
  } catch (e) {
    if (context.mounted) _failed(context, release, '$e');
    return;
  }
  if (!context.mounted) return;
  // Set once the dialog is closing: the builder can see a final event more than once, and a cancelled
  // download still reports CANCELED afterwards — popping again would close the screen below.
  var closed = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StreamBuilder<OtaEvent>(
      stream: events,
      builder: (context, snapshot) {
        final event = snapshot.data;
        final status = event?.status;
        final done = status != null && status != OtaStatus.DOWNLOADING;
        if (done && !closed) {
          closed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (status != OtaStatus.INSTALLING && status != OtaStatus.INSTALLATION_DONE && status != OtaStatus.CANCELED) {
              _failed(
                context,
                release,
                status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR ? l10n.updatePermission : event?.value ?? status.name,
              );
            }
          });
        }
        final percent = double.tryParse(event?.value ?? '');
        return AlertDialog(
          title: Text(status == OtaStatus.INSTALLING ? l10n.updateInstalling : l10n.updateDownloading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: status == OtaStatus.DOWNLOADING && percent != null ? percent / 100 : null),
              const SizedBox(height: 8),
              Text(percent == null ? '' : '${percent.round()}%', textAlign: TextAlign.end),
            ],
          ),
          actions: [
            TextButton(
              onPressed: closed
                  ? null
                  : () {
                      closed = true;
                      Navigator.pop(dialogContext);
                      ref.read(updateServiceProvider).cancel().ignore();
                    },
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    ),
  );
}

void _failed(BuildContext context, Release release, String error) {
  final l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    persist: false,
    duration: const Duration(seconds: 8),
    content: Text(l10n.updateFailed(error)),
    action: release.pageUrl.isEmpty
        ? null
        : SnackBarAction(
            label: l10n.openReleasePage,
            onPressed: () => launchUrl(Uri.parse(release.pageUrl), mode: LaunchMode.externalApplication),
          ),
  ));
}
