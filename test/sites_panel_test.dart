import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Succès Group dans Élèves : ajouter une classe, basculer avec un élève', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Préparer'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Gérer les sites et classes'), 200);
    await tester.tap(find.text('Gérer les sites et classes'));
    await tester.pump();
    // Onglet Élèves, « Succès Group » sélectionné en premier.
    expect(find.text('Ajouter un site'), findsOneWidget);

    await tester.tap(find.text('+ Ajouter une classe').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Première D');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    final post = api.requests.lastWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/classes');
    expect((jsonDecode(post.body) as Map)['name'], 'Première D');

    // Choisir un élève quitte Succès Group, le chip y revient.
    await tester.tap(find.text('Adjé'));
    await tester.pump();
    expect(find.text('Ajouter un site'), findsNothing);
    await tester.tap(find.text('Succès Group'));
    await tester.pump();
    expect(find.text('Ajouter un site'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
