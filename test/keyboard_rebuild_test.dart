import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';

import 'helpers.dart';

void main() {
  testWidgets('the keyboard under a screen opened over the tabs does not rebuild them', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    c.read(workspaceProvider).open(c.read(tabFactoryProvider).terminal('sample'));
    await settle(tester);
    c.read(routerProvider).push(Routes.newForward());
    await settle(tester);
    var rebuilt = 0;
    final types = <String>{};
    debugOnRebuildDirtyWidget = (e, builtOnce) {
      rebuilt++;
      types.add(e.widget.runtimeType.toString());
    };
    for (var i = 1; i <= 10; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: i * 80.0);
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;
    tester.view.reset();
    // The terminal behind the form used to be rebuilt (and resized) on every frame: ~850 widgets a frame.
    expect(types, isNot(contains('TerminalView')));
    expect(types, isNot(contains('TabSwitcher')));
    expect(rebuilt, lessThan(1000), reason: '10 frames of keyboard animation');
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
