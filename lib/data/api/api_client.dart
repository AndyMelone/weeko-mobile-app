import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur renvoyée par l'API (ou réseau), avec un message affichable.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client HTTP de weeko-api. Ajoute la clé API à chaque requête.
class ApiClient {
  ApiClient({required String baseUrl, required this.apiKey, http.Client? client})
    : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _http = client ?? http.Client();

  final String _base;
  final String apiKey;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll({'x-api-key': apiKey, 'Accept': 'application/json'});
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on Exception {
      throw const ApiException('Serveur injoignable. Vérifiez la connexion.');
    }
    final data = _decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      throw ApiException(_message(data, res.statusCode), statusCode: res.statusCode);
    }
    if (data == null && res.bodyBytes.isNotEmpty) {
      throw const ApiException('Réponse du serveur illisible.');
    }
    return data;
  }

  /// Corps JSON, ou null s'il est vide ou illisible (ex. page d'erreur HTML).
  static dynamic _decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      return null;
    }
  }

  static String _message(dynamic data, int status) {
    if (status == 401) return 'Clé API refusée par le serveur.';
    final m = data is Map ? data['message'] : null;
    if (m is List) return m.join(' · ');
    if (m is String) return m;
    return 'Erreur serveur ($status).';
  }

  void close() => _http.close();
}
