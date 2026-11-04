import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/forwarding/data/forwarding_providers.dart';
import 'package:nux/features/forwarding/domain/forwarding_manager.dart';

import 'forwarding_manager_test.dart' show FakeForward, FakeKeepAlive;
import 'helpers.dart';

void main() {
  testWidgets('a host slides its forwardings out; while hidden, running ones peek out under it', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final forward = FakeForward()
      ..stats.open = 2
      ..stats.bytesIn = 3 << 20;
    final manager = ForwardingManager(
      connect: (rule) async => ForwardLease(client: Object(), done: Completer<void>().future, release: () {}),
      startForward: (lease, rule, onChange) async => forward,
      keepAlive: FakeKeepAlive(),
      log: Log(),
      texts: () => ForwardingTexts(title: (n) => '$n', text: (a, b) => '', stop: 'Stop'),
    );
    addTearDown(manager.dispose);
    final c = ProviderContainer(
      overrides: [...testOverrides(db: db, secrets: secrets), forwardingManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    expect(find.text('Database'), findsNothing);
    await tester.tap(find.byTooltip('Forwardings'));
    await settle(tester);
    expect(find.text('Database'), findsOneWidget);
    expect(find.text('Add port forwarding'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.text('2 connections'), findsOneWidget);
    expect(find.text('↓ 3.0 MB'), findsOneWidget);

    await tester.tap(find.byTooltip('Forwardings'));
    await settle(tester);
    expect(find.text('Database'), findsNothing);
    expect(find.text('1 port, 2 connections'), findsOneWidget, reason: 'the peek under the closed host');
    await tester.tap(find.text('1 port, 2 connections'));
    await settle(tester);
    expect(find.text('Database'), findsOneWidget);

    await manager.stopAll(); // ends the notification ticker
    await tester.pump(const Duration(seconds: 1));
  });
}
