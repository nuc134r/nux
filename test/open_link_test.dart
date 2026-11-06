import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/browser/presentation/browser_tab.dart';
import 'package:nux/features/browser/presentation/open_link.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/l10n/gen/app_localizations.dart';

import 'helpers.dart';

void main() {
  testWidgets('a link asks: in a tab of nux, or in another app', (tester) async {
    final c = ProviderContainer(overrides: testOverrides());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => askOpenLink(context, Uri.parse('https://example.com/docs')),
              child: const Text('link'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/docs'), findsOneWidget);
    expect(find.text('In another app'), findsOneWidget);
    await tester.tap(find.text('In a tab'));
    await tester.pumpAndSettle();
    final tab = c.read(workspaceProvider).tabs.single;
    expect(tab, isA<BrowserTab>());
    expect((tab as BrowserTab).url, 'https://example.com/docs');
  });
}
