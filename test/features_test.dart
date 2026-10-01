import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:weeko/core/utils/formats.dart';
import 'package:weeko/data/models/models.dart';
import 'package:weeko/logic/app_state.dart';
import 'package:weeko/main.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

Future<AppState> loaded(FakeApi api) async {
  final app = AppState(api.client);
  await app.load();
  return app;
}

Map<String, dynamic> bodyOf(FakeApi api, String path) =>
    jsonDecode(api.requests.lastWhere((r) => r.url.path == path).body) as Map<String, dynamic>;

Future<void> openApp(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(WeekoApp(api: api.client));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('séance touchée', () {
    testWidgets('séance à venir : pas de pointage, changer l’heure → PATCH', (tester) async {
      final api = FakeApi();
      await openApp(tester, api);
      // Mardi 0h : la séance d'Ange (mardi 15h30) n'a pas commencé.
      await tester.tap(find.text('Ange Kra').first);
      await tester.pumpAndSettle();
      expect(find.text('Pointer la séance'), findsNothing);
      expect(find.textContaining('Séance à venir'), findsOneWidget);

      await tester.tap(find.text('Changer l’heure ou le jour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jeu.').last);
      await tester.pump();
      await tester.tap(find.textContaining('Valider'));
      await tester.pumpAndSettle();
      expect(api.writes, ['PATCH /api/sessions/s3']);
      expect(bodyOf(api, '/api/sessions/s3'), {'week': 0, 'day': 3, 'start': 930, 'end': 1050});
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('annuler une séance prévue → POST cancel (à rattraper)', (tester) async {
      final api = FakeApi();
      await openApp(tester, api);
      await tester.tap(find.text('Ange Kra').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler · prévenir une absence'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la séance'));
      await tester.pumpAndSettle();
      expect(api.writes, ['POST /api/sessions/s3/cancel']);
      expect(bodyOf(api, '/api/sessions/s3/cancel'), {'redo': true, 'who': 'eleve'});
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('AppState', () {
    test('séance commencée ou non', () async {
      final app = await loaded(FakeApi());
      expect(app.hasStarted(app.sessionById('s1')!), isTrue); // lundi
      expect(app.hasStarted(app.sessionById('s3')!), isFalse); // mardi 15h30, il est 0h
    });

    test('rattrapage placé à un créneau précis', () async {
      final api = FakeApi();
      final app = await loaded(api);
      final it = app.items().firstWhere((i) => i.key == 'd2');
      await app.place(it, const SlotPick(Slot(week: 1, day: 2, start: 1020, end: 1140)));
      expect(bodyOf(api, '/api/rattrapages/d2/place'), {
        'slot': {'week': 1, 'day': 2, 'start': 1020, 'end': 1140},
      });
    });

    test('indisponibilités du répétiteur et agenda', () async {
      final api = FakeApi();
      final app = await loaded(api);
      await app.setTutorUnavailable(const [
        TimeBlock(day: 6, start: 0, end: 720),
        TimeBlock(day: 5, start: 720, end: 1440),
      ]);
      expect(bodyOf(api, '/api/settings'), {
        'unavailable': [
          {'day': 6, 'start': '00:00', 'end': '12:00'},
          {'day': 5, 'start': '12:00', 'end': '23:59'},
        ],
      });
      expect(app.calendarUrl, isNull);
      app.calendarToken = 'abc';
      expect(app.calendarUrl, 'http://api.test/api/calendar/abc.ics');
      expect(app.calendarWebcal, 'webcal://api.test/api/calendar/abc.ics');
    });

    test('argent : dû selon le tarif, payé, reste, solde', () async {
      final state = jsonDecode(stateFixture) as Map<String, dynamic>;
      for (final s in state['services'] as List) {
        if (s['id'] == 'ange') s['rate'] = 5000;
      }
      for (final s in state['sessions'] as List) {
        if (s['svc'] == 'ange') s['status'] = 'faite'; // 2 séances en octobre
      }
      state['payments'] = [
        {'id': 'p1', 'serviceId': 'ange', 'amount': 6000, 'paidOn': '2026-10-03', 'note': 'Espèces'},
        {'id': 'p2', 'serviceId': 'ange', 'amount': 1000, 'paidOn': '2026-09-20', 'note': ''},
      ];
      final app = await loaded(FakeApi(respond: (r) => r.url.path == '/api/state' ? state : null));
      final f = app.financeOf('ange', 2026, 10);
      expect(f.done, 2);
      expect(f.due, 10000);
      expect(f.paid, 6000);
      expect(f.left, 4000);
      // Septembre : 0 dû, 1 000 payé d'avance → reste 3 000 au total.
      expect(f.balance, 3000);
      expect(app.financeMessage('ange', 2026, 10), contains('2 séances faites × 5 000 F = 10 000 F'));
      expect(money(1250000), '1 250 000 F');
    });

    test('hors ligne : planning en cache, pointage gardé puis envoyé', () async {
      var offline = false;
      final api = FakeApi(
        respond: (r) {
          if (offline) throw http.ClientException('pas de réseau');
          return null;
        },
      );
      final app = await loaded(api); // en ligne : planning mis en cache
      offline = true;
      // Nouvelle ouverture de l'app sans réseau : le cache s'affiche.
      final cold = AppState(api.client);
      await cold.load();
      expect(cold.status, LoadStatus.ready);
      expect(cold.offline, isTrue);
      expect(cold.week(0), hasLength(app.week(0).length));

      final msg = await cold.savePointer('s1', const PointerDraft(missed: false));
      expect(msg, contains('Hors ligne'));
      expect(cold.pendingPointers, hasLength(1));
      expect(cold.sessionById('s1')!.status, SessionStatus.faite);

      offline = false;
      api.requests.clear();
      await cold.load();
      expect(cold.offline, isFalse);
      expect(cold.pendingPointers, isEmpty);
      expect(api.writes, ['POST /api/sessions/s1/pointer']);
      cold.dispose();
    });
  });
}
