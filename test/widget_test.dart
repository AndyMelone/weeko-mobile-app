import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:weeko/core/utils/formats.dart';
import 'package:weeko/data/models/models.dart';
import 'package:weeko/logic/app_state.dart';

import 'support/fake_api.dart';

Future<AppState> loaded(FakeApi api) async {
  final app = AppState(api.client);
  await app.load();
  return app;
}

void main() {
  group('formats', () {
    test('semaine de démo', () {
      expect(weekNum(0), 41);
      expect(weekRange(0), '5 – 11 octobre');
      expect(fmt(930), '15h30');
      expect(fmt(900), '15h');
      expect(dayShort(0, 3), 'jeu. 8 oct.');
    });

    test('aujourd’hui suit la vraie date', () {
      final saved = clock;
      addTearDown(() => clock = saved);
      clock = () => DateTime(2026, 9, 30, 21, 45); // mercredi
      expect(today(), (week: -1, day: 2));
      expect(weekRange(currentWeek), '28 sept. – 4 oct.');
      clock = () => DateTime(2026, 10, 5);
      expect(today(), (week: 0, day: 0));
    });
  });

  group('AppState', () {
    test('charge les données de démo depuis l’API', () async {
      final api = FakeApi();
      final app = await loaded(api);
      expect(app.status, LoadStatus.ready);
      expect(api.requests.single.headers['x-api-key'], 'test-key');
      expect(app.week(0).length, 11);
      expect(app.students, ['ange', 'adje', 'sondo']);
      expect(app.history['ange'], hasLength(4));
      expect(app.decided.map((s) => s.id), ['s8', 's10']);
      expect(app.todoCount, 2);
    });

    test('Adjé : jamais le week-end ni deux jours de suite', () async {
      final app = await loaded(FakeApi());
      expect(app.slotOn('adje', 5, app.week(0), 0), isNull);
      expect(app.slotOn('adje', 1, app.week(0), 0), isNull);
    });

    test('pointer envoie le brouillon puis recharge', () async {
      final api = FakeApi(
        respond: (r) => r.method == 'POST' ? {'message': 'Séance manquée · 1 séance à rattraper créée'} : null,
      );
      final app = await loaded(api);
      final msg = await app.savePointer('s1', const PointerDraft(missed: true, who: Who.eleve, motif: 'Élève malade'));
      expect(msg, 'Séance manquée · 1 séance à rattraper créée');
      expect(api.writes, ['POST /api/sessions/s1/pointer']);
      expect(jsonDecode(api.requests[1].body), {'missed': true, 'who': 'eleve', 'motif': 'Élève malade', 'redo': true});
      expect(api.requests.last.url.path, '/api/state');
    });

    test('caser un rattrapage envoie la proposition choisie', () async {
      final api = FakeApi();
      final app = await loaded(api);
      final it = app.items().firstWhere((i) => i.key == 'd2');
      expect(app.proposals(it), isNotEmpty);
      await app.place(it, const ProposalChoice(0));
      expect(api.writes, ['POST /api/rattrapages/d2/place']);
      expect(jsonDecode(api.requests[1].body), {'proposal': 0});
    });

    test('générer envoie d’abord la préparation en attente', () async {
      final api = FakeApi();
      final app = await loaded(api);
      app.updatePrep(1, (p) => p.changes['sondo'] = WeekChange.une);
      await app.generate(1);
      expect(api.writes, ['PATCH /api/weeks/1/prep', 'POST /api/weeks/1/generate']);
      expect((jsonDecode(api.requests[1].body) as Map)['changes'], {'sondo': 'une'});
    });

    test('trajets : désactivés par défaut, séances bout à bout', () async {
      final app = await loaded(FakeApi());
      expect(app.travelEnabled, isFalse);
      expect(app.slotOn('ange', 0, [], 0)?.start, 900);
      app.travelEnabled = true;
      expect(app.slotOn('ange', 0, [], 0)?.start, 930);
      expect(app.travel((svc: 'ange'), (svc: 'ma')), 30);
    });

    test('activer les trajets envoie le réglage', () async {
      final api = FakeApi();
      final app = await loaded(api);
      await app.setTravel(true);
      expect(api.writes, ['PATCH /api/settings']);
      expect(jsonDecode(api.requests[1].body), {'travel': true});
    });

    test('supprimer un élève envoie DELETE (réponse vide 204)', () async {
      final api = FakeApi(respond: (r) => r.method == 'DELETE' ? http.Response('', 204) : null);
      final app = await loaded(api);
      await app.deleteStudent('sondo');
      expect(api.writes, ['DELETE /api/students/sondo']);
      expect(app.busy, isFalse);
    });

    test('annuler un rattrapage casé envoie cancel', () async {
      final api = FakeApi(
        respond: (r) => r.url.path.endsWith('/cancel') ? {'message': 'Rattrapage annulé · séance à replacer'} : null,
      );
      final app = await loaded(api);
      final it = app.items().firstWhere((i) => i.key == 'd1');
      expect(await app.cancelRattrapage(it), 'Rattrapage annulé · séance à replacer');
      expect(api.writes, ['POST /api/rattrapages/d1/cancel']);
    });

    test('textes du récap : semaine, collectif, individuel', () async {
      final app = await loaded(FakeApi());
      final recap = app.recapOf(0);
      expect(recap, startsWith('Planning du 5 au 11 octobre'));
      expect(recap, contains('Lundi 5 octobre\n– 15h30–17h30 : Adjé'));
      final coll = app.collectiveOf(0);
      expect(coll, contains('Mamie Adjoua'));
      expect(coll, contains('Samedi 10 octobre · 8h–12h · Terminale D'));
      expect(coll, isNot(contains('Adjé')));
      expect(app.programmeOf('ange', 0), contains('pour la semaine du 5 au 11 octobre'));
      expect(app.programmeOf('ange', 0), contains('– Dimanche 11 octobre : 9h – 11h'));
    });

    test('indisponibilités : élève (samedi après 12h) et répétiteur (dimanche avant 12h)', () async {
      final state = jsonDecode(stateFixture) as Map<String, dynamic>;
      for (final s in state['services'] as List) {
        if (s['id'] == 'ange') {
          s['unavailable'] = [
            {'day': 5, 'start': 720, 'end': 1440},
          ];
        }
      }
      state['settings'] = {
        'travel': false,
        'unavailable': [
          {'day': 6, 'start': 0, 'end': 720},
        ],
      };
      final app = await loaded(FakeApi(respond: (r) => r.url.path == '/api/state' ? state : null));
      expect(app.slotOn('ange', 5, [], 0), isA<Slot>().having((s) => s.end, 'fin', lessThanOrEqualTo(720)));
      expect(app.slotOn('ange', 6, [], 0)?.start, 720);
      expect(app.slotOn('ma', 6, [], 0)?.start, 840);
      expect(app.ruleOf(app.svc('ange')), contains('indisponible le samedi après 12h'));
    });

    test('clé refusée : état en erreur avec message', () async {
      final api = FakeApi(respond: (_) => http.Response('{"message":"Clé API invalide ou absente"}', 401));
      final app = await loaded(api);
      expect(app.status, LoadStatus.error);
      expect(app.error, 'Clé API refusée par le serveur.');
    });
  });
}
