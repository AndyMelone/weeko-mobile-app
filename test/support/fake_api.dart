import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weeko/data/api/api_client.dart';

/// Réponse de `GET /state` capturée sur weeko-api après `npm run db:seed`.
final stateFixture = File('test/fixtures/state.json').readAsStringSync();

/// Fausse API : sert la fixture pour /state, enregistre les requêtes et
/// répond aux modifications avec [respond] (par défaut `{message: 'ok'}`).
class FakeApi {
  FakeApi({this.respond});

  final Object? Function(http.Request req)? respond;
  final requests = <http.Request>[];

  late final client = ApiClient(
    baseUrl: 'http://api.test/api',
    apiKey: 'test-key',
    client: MockClient((req) async {
      requests.add(req);
      final custom = respond?.call(req);
      if (custom is http.Response) return custom;
      if (custom == null && req.url.path.endsWith('/preview')) return _json(previewOf(req.url.pathSegments[2]));
      return _json(custom ?? (req.url.path == '/api/state' ? jsonDecode(stateFixture) : {'message': 'ok', 'id': 'e1'}));
    }),
  );

  /// Requêtes hors `GET /state`, sous la forme « POST /api/... ».
  List<String> get writes => [
    for (final r in requests)
      if (r.url.path != '/api/state') '${r.method} ${r.url.path}',
  ];

  static http.Response _json(Object? body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

  /// Aperçu de génération : les séances de la semaine de démo, recopiées en semaine [week].
  static Map<String, dynamic> previewOf(String week) {
    final w = int.parse(week);
    final sessions = [
      for (final s in (jsonDecode(stateFixture)['sessions'] as List).cast<Map<String, dynamic>>())
        if (s['week'] == 0) {...s, 'id': '${s['id']}-w$w', 'week': w},
    ];
    return {'message': 'Planning du 12 – 18 octobre : ${sessions.length} séances', 'sessions': sessions};
  }
}
