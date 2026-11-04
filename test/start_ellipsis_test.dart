import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/widgets/widgets.dart';

void main() {
  testWidgets('a long path keeps its end', (tester) async {
    const path = '/home/dev/projects/very/deep/folder/structure/lib/src';
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 160, child: StartEllipsisText(path))),
      ),
    );
    final shown = tester.widget<Text>(find.byType(Text)).data!;
    expect(shown, startsWith('…'));
    expect(path.endsWith(shown.substring(1)), isTrue);
    expect(shown, endsWith('lib/src'));
  });
}
