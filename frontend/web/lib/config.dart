import 'dart:convert';

import 'package:http/http.dart' as http;

import 'platform/browser.dart';

/// Runtime configuration.
///
/// Resolution order for the API base URL:
///  1. `config.json` served next to index.html (`{"apiUrl": "..."}`), written
///     by the container entrypoint from env `API_URL` on Cloud Run;
///  2. `--dart-define=API_URL=...` at build/run time;
///  3. `http://localhost:8080`.
class AppConfig {
  const AppConfig({required this.apiUrl, this.source = 'default'});

  static const String _defineApiUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  final String apiUrl;

  /// Where [apiUrl] came from: `config.json` or `dart-define`.
  final String source;

  static String _normalise(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static Future<AppConfig> load({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final uri = appBaseUri().resolve('config.json').replace(
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final res = await c.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['apiUrl'] is String) {
          final url = _normalise(body['apiUrl'] as String);
          if (url.isNotEmpty) return AppConfig(apiUrl: url, source: 'config.json');
        }
      }
    } catch (_) {
      // No config.json (local `flutter run`) or not JSON: fall back.
    } finally {
      if (client == null) c.close();
    }
    return AppConfig(apiUrl: _normalise(_defineApiUrl), source: 'dart-define');
  }
}
