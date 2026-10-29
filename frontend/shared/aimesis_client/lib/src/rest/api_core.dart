import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Shared HTTP plumbing: base URL, bearer token, JSON encode/decode,
/// timeout and error mapping. Endpoint groups are mixins on this class.
abstract class ApiCore {
  ApiCore({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _baseUrl = _normalise(baseUrl),
        httpClient = client ?? http.Client();

  final http.Client httpClient;
  final Duration timeout;

  String _baseUrl;

  /// Bearer token (set by `login`, cleared by `logout`). May be set manually,
  /// e.g. when restoring a session.
  String? token;

  /// Called whenever a request returns 401 (e.g. to route back to login).
  void Function()? onUnauthorized;

  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = _normalise(value);

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  static String _normalise(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final u = Uri.parse('$_baseUrl$p');
    return (query == null || query.isEmpty) ? u : u.replace(queryParameters: query);
  }

  Map<String, String> headers({bool json = false, Map<String, String>? extra}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        ...?extra,
      };

  Future<dynamic> getJson(String path, {Map<String, String>? query}) =>
      _send(() => httpClient.get(uri(path, query), headers: headers()));

  Future<dynamic> postJson(String path, [Object? body]) => _send(() => httpClient.post(
        uri(path),
        headers: headers(json: true),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ));

  Future<dynamic> putJson(String path, Object? body) => _send(() => httpClient.put(
        uri(path),
        headers: headers(json: true),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'The server did not respond in time. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Could not reach the server ($e).');
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 401) onUnauthorized?.call();
      throw ApiException.fromResponse(res.statusCode, body, reasonPhrase: res.reasonPhrase);
    }
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiException(res.statusCode, 'Invalid JSON from server.');
    }
  }

  /// Casts a decoded body to a JSON object or throws a parse [ApiException].
  Map<String, dynamic> asObject(Object? decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    throw const ApiException(200, 'Unexpected response: expected a JSON object.');
  }

  /// Maps a decoded JSON array to models (non-object entries are skipped).
  List<T> asList<T>(Object? decoded, T Function(Map<String, dynamic>) fromJson) {
    if (decoded is! List) {
      throw const ApiException(200, 'Unexpected response: expected a JSON array.');
    }
    return decoded.whereType<Map<dynamic, dynamic>>().map((m) => fromJson(asObject(m))).toList();
  }

  /// Closes the underlying HTTP client.
  void close() => httpClient.close();
}
