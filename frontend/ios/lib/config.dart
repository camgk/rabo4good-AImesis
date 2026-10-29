import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API base URL baked in at build time:
/// `flutter run --dart-define=API_URL=https://mock-api-xyz.run.app`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

/// Resolves the API URL at startup.
///
/// iOS: always [apiUrl] (the dart-define).
/// Web fallback: like the care-team web app, try `config.json` next to
/// index.html first (`{"apiUrl": "..."}`), so the same build can be served
/// from Cloud Run with a different backend. Falls back to [apiUrl].
Future<String> resolveApiUrl({http.Client? client}) async {
  if (!kIsWeb) return apiUrl;
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.base.resolve('config.json'))
        .timeout(const Duration(seconds: 3));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map && body['apiUrl'] is String) {
        final url = (body['apiUrl'] as String).trim();
        if (url.isNotEmpty) return url;
      }
    }
  } catch (_) {
    // no config.json (local dev) → use the dart-define
  } finally {
    if (client == null) c.close();
  }
  return apiUrl;
}
