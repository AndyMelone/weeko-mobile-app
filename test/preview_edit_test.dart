import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('aperçu : supprimer, défaire, glisser pour échanger, valider envoie l’aperçu modifié', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(WeekoApp(api: api.client));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Préparer'));
    await tester.pump();
    await tester.tap(find.text('Générer le planning'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rien n’est enregistré avant validation'), findsOneWidget);

    final lines = find.byType(LongPressDraggable<String>);
    final n = tester.widgetList(lines).length;
    expect(n, greaterThan(2));
    final ids = [for (final d in tester.widgetList<LongPressDraggable<String>>(lines)) d.data!];

    // Toucher → Supprimer, puis Défaire.
    await tester.tap(lines.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(lines).length, n - 1);
    await tester.tap(find.text('Défaire'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(lines).length, n);

    // Appui long sur la 1re séance, glissée sur la 2e : échange.
    final g = await tester.startGesture(tester.getCenter(lines.at(0)));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(tester.getCenter(lines.at(1)));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Modifiée'), findsNWidgets(2));

    // Puis supprimer la dernière séance et valider.
    await tester.ensureVisible(lines.last);
    await tester.pumpAndSettle();
    await tester.tap(lines.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider le planning'));
    await tester.pumpAndSettle();

    final post = api.requests.lastWhere((r) => r.url.path.endsWith('/generate'));
    final sent = ((jsonDecode(post.body) as Map)['sessions'] as List).cast<Map>();
    expect(sent, hasLength(n - 1));
    final preview = (FakeApi.previewOf(post.url.pathSegments[2])['sessions'] as List).cast<Map>();
    Map byId(List<Map> l, String id) => l.firstWhere((s) => s['id'] == id);
    final a = byId(preview, ids[0]), b = byId(preview, ids[1]);
    expect(byId(sent, ids[0])['start'], b['start']);
    expect(byId(sent, ids[1])['start'], a['start']);
    await tester.pump(const Duration(seconds: 4));
  });
}
