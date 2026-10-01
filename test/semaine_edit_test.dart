import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weeko/data/models/models.dart';
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<FakeApi> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();
    return api;
  }

  testWidgets('Semaine : appui long + glisser une séance sur une autre → POST swap', (tester) async {
    final api = await open(tester);
    final rows = find.byType(LongPressDraggable<Session>);
    expect(tester.widgetList(rows).length, greaterThan(1));
    final a = tester.widget<LongPressDraggable<Session>>(rows.at(0)).data!;
    final b = tester.widget<LongPressDraggable<Session>>(rows.at(1)).data!;

    final g = await tester.startGesture(tester.getCenter(rows.at(0)));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(tester.getCenter(rows.at(1)));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    final post = api.requests.lastWhere((r) => r.url.path.endsWith('/swap'));
    expect(post.url.path, '/api/sessions/${a.id}/swap');
    expect(jsonDecode(post.body), {'with': b.id});
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Semaine : toucher → Supprimer la séance → confirmation → cancel sans rattrapage', (tester) async {
    final api = await open(tester);
    final rows = find.byType(LongPressDraggable<Session>);
    final s = tester.widget<LongPressDraggable<Session>>(rows.first).data!;
    await tester.tap(rows.first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Supprimer la séance'));
    await tester.tap(find.text('Supprimer la séance'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer cette séance ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    final post = api.requests.lastWhere((r) => r.url.path.endsWith('/cancel'));
    expect(post.url.path, '/api/sessions/${s.id}/cancel');
    expect(jsonDecode(post.body), {'redo': false});
    await tester.pump(const Duration(seconds: 4));
  });
}
