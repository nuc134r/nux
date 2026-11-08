import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../activity/activity_center.dart';
import '../log/log.dart';

/// How an earlier run of nux ended, as Android recorded it (android/.../ExitChannel.kt).
class PreviousExit {
  const PreviousExit({required this.reason, this.time, this.description, this.trace, this.importance});

  factory PreviousExit.fromMap(Map<Object?, Object?> m) => PreviousExit(
    reason: m['reason'] as String? ?? 'unknown',
    time: switch (m['time']) {
      final num t => DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      _ => null,
    },
    description: m['description'] as String?,
    trace: m['trace'] as String?,
    importance: (m['importance'] as num?)?.toInt(),
  );

  final String reason;
  final DateTime? time;
  final String? description;

  /// The stack trace of a Java / Kotlin crash.
  final String? trace;

  /// Android's process importance then (100 on screen, 125 a foreground service, 400 cached...).
  final int? importance;

  /// Not something the user or an update did.
  bool get unexpected => const {
    'crash',
    'native crash',
    'not responding',
    'initialization failure',
    'java crash',
    'excessive resource usage',
    'low memory',
    'signaled',
    'dependency died',
  }.contains(reason);

  String get summary => [
    reason,
    if (description != null && description!.isNotEmpty) description,
    if (importance != null) 'importance $importance',
  ].join(' · ');
}

const _channel = MethodChannel('nux/exits');

/// The exits Dart has not seen yet; none off Android or when the channel is missing (tests).
Future<List<PreviousExit>> unseenExits() async {
  if (kIsWeb || !Platform.isAndroid) return const [];
  try {
    final list = await _channel.invokeListMethod<Object?>('unseen') ?? const [];
    return [for (final m in list.whereType<Map<Object?, Object?>>()) PreviousExit.fromMap(m)];
  } on MissingPluginException {
    return const [];
  } on PlatformException {
    return const [];
  }
}

/// Once at start: how the earlier runs ended goes to the log, and an unexpected end to Activity too.
final previousExitsProvider = Provider<void>((ref) {
  unawaited(
    unseenExits().then((exits) {
      if (exits.isEmpty) return;
      final log = ref.read(logProvider);
      for (final e in exits) {
        final when = e.time?.toIso8601String() ?? '?';
        final text = 'Earlier run ended at $when: ${e.summary}${e.trace == null ? '' : '\n${e.trace}'}';
        e.unexpected ? log.w('exit', text) : log.i('exit', text);
      }
      final crash = exits.where((e) => e.unexpected).lastOrNull;
      if (crash == null) return;
      ref
          .read(activityCenterProvider)
          .event(
            ActivitySource.other,
            currentL10n.value.activityAppCrashed,
            subtitle: crash.summary,
            state: ActivityState.failed,
            open: (context) {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(Routes.log);
            },
          );
    }),
  );
});
