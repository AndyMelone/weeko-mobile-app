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
    expect(find.text('Supprimer Sondo ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pump();
    await tester.pump();
    expect(api.writes, ['DELETE /api/students/sondo']);
    await tester.pump(const Duration(seconds: 4));
  });
}
