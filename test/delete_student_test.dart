import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('appui long sur le nom d’un élève → confirmation → suppression', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi(respond: (r) => r.method == 'DELETE' ? http.Response('', 204) : null);
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Élèves'));
    await tester.pump();
    expect(find.text('Supprimer l’élève'), findsNothing);

    await tester.ensureVisible(find.text('Sondo'));
    await tester.longPress(find.text('Sondo'));
    await tester.pumpAndSettle();
    // Feuille d'actions : Modifier / Supprimer.
    expect(find.text('Modifier'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer Sondo ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pump();
    await tester.pump();
    expect(api.writes, ['DELETE /api/students/sondo']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('appui long → Modifier → formulaire prérempli → PATCH', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Élèves'));
    await tester.pump();

    await tester.ensureVisible(find.text('Sondo'));
    await tester.longPress(find.text('Sondo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier Sondo'), findsOneWidget);
    expect(find.text('+225 07 00 00 00 03'), findsOneWidget); // WhatsApp prérempli

    await tester.enterText(find.widgetWithText(TextField, 'Sondo'), 'Sondo Traoré');
    await tester.pump();
    final save = find.text('Enregistrer');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
    );
    await tester.tap(save);
    await tester.pump();
    await tester.pump();
    expect(api.writes, ['PATCH /api/students/sondo']);
    final body = jsonDecode(api.requests.last.method == 'PATCH' ? api.requests.last.body : api.requests[1].body);
    expect(body['name'], 'Sondo Traoré');
    expect(body['phone'], '+225 07 00 00 00 03');
    expect(body['count'], 2);
    await tester.pump(const Duration(seconds: 4));
  });
}
