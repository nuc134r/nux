import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/keys/key_bar_layout.dart';
import 'package:nux/features/settings/presentation/key_layout_editor.dart';
import 'package:nux/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('drag keys within and between rows, onto Remove; add one with +', (tester) async {
    var rows = parseKeyBar('ESC a b\nTAB c');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => KeyLayoutEditor(
                rows: rows,
                supports: (_) => true,
                onChanged: (r) => setState(() => rows = r),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> drag(String key, Finder onto) async {
      final g = await tester.startGesture(tester.getCenter(find.text(key)));
      await tester.pump(const Duration(milliseconds: 600)); // long press starts the drag
      await g.moveTo(tester.getCenter(onto));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
    }

    // b before a.
    await drag('b', find.text('a'));
    expect(formatKeyBar(rows), 'ESC b a\nTAB c');
    // a to the second row, before c.
    await drag('a', find.text('c'));
    expect(formatKeyBar(rows), 'ESC b\nTAB a c');
    // ESC away.
    final g = await tester.startGesture(tester.getCenter(find.text('Esc')));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(find.text('Remove'), findsOneWidget);
    await g.moveTo(tester.getCenter(find.text('Remove')));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(formatKeyBar(rows), 'b\nTAB a c');

    // + on the first row: a key typing "(" with () on long press.
    await tester.tap(find.byTooltip('Add key').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Types'), '(');
    await tester.enterText(find.widgetWithText(TextField, 'On long press'), '() ((');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(rows.first.last, const BarKey('(', ['()', '((']));
  });
}
