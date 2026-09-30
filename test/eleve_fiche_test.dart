import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('fiche élève : historique « Voir plus » et copie du programme', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(WeekoApp(api: FakeApi().client));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Élèves'));
    await tester.pump();
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

    await tester.scrollUntilVisible(find.text('Voir plus (1)'), 200, scrollable: vertical);
    expect(find.text('Jeu. 24 sept. · 15h30–17h30'), findsNothing);
    await tester.tap(find.text('Voir plus (1)'));
    await tester.pump();
    expect(find.text('Jeu. 24 sept. · 15h30–17h30'), findsOneWidget);
    expect(find.text('Voir moins'), findsOneWidget);

    expect(find.text('Envoyer le programme'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('Copier le programme'), 200, scrollable: vertical);
    await tester.tap(find.byTooltip('Copier le programme'));
    await tester.pump();
    await tester.pump();
    expect(copied, startsWith('Bonjour,'));
    expect(find.text('Programme copié'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
