import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tous les écrans se rendent', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    final api = FakeApi();
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();
    expect(find.text("AUJOURD'HUI"), findsOneWidget);
    // Jours passés repliés, avec les séances non pointées « à pointer ».
    expect(find.textContaining('à pointer'), findsWidgets);
    await tester.tap(find.textContaining('Jour passé'));
    await tester.pump();
    await tester.tap(find.text('Adjé').first);
    await tester.pumpAndSettle();
    // Feuille de séance (lundi, déjà passée) → Pointer.
    await tester.tap(find.text('Pointer la séance'));
    await tester.pumpAndSettle();
    expect(find.text('Pointer la séance'), findsOneWidget);
    await tester.tap(find.text('Manquée'));
    await tester.pump();
    await tester.tap(find.text('Élèves'));
    await tester.pump();
    expect(find.text('Programme à envoyer'.toUpperCase()), findsOneWidget);
    await tester.tap(find.text('Rattrapages').last);
    await tester.pump();
    await tester.tap(find.text('Préparer').last);
    await tester.pump();
    expect(find.text('Générer le planning'), findsOneWidget);
    await tester.tap(find.text('Générer le planning'));
    await tester.pumpAndSettle();
    expect(find.text('Aperçu du 12 au 18 octobre'), findsOneWidget);
    expect(find.textContaining('rien n’est enregistré avant validation'), findsOneWidget);
    expect(find.text('Lundi 12 octobre'), findsOneWidget);
    await tester.tap(find.text('Collectif'));
    await tester.pump();
    expect(find.textContaining('Terminale D'), findsWidgets);
    await tester.tap(find.text('Individuel'));
    await tester.pump();
    expect(find.textContaining('Voici le programme de Ange'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(api.writes, ['POST /api/weeks/1/preview']);

    await tester.tap(find.text('Générer le planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider le planning'));
    await tester.pumpAndSettle();
    expect(api.writes, ['POST /api/weeks/1/preview', 'POST /api/weeks/1/preview', 'POST /api/weeks/1/generate']);
    expect(find.text('Planning validé · ok'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    addTearDown(tester.view.reset);
  });
}
