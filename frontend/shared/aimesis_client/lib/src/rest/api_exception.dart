import 'dart:convert';

/// Error from the AImesis API. [status] is the HTTP status code, or 0 for
/// network errors / timeouts. [message] comes from the `{"error": "..."}` body.
class ApiException implements Exception {
  final int status;
  final String message;

  const ApiException(this.status, this.message);

  /// Builds an exception from an error response body (`{"error": "..."}`;
  /// FastAPI's `{"detail": ...}` is tolerated too).
  factory ApiException.fromResponse(int status, String body, {String? reasonPhrase}) {
    String? msg;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final e = decoded['error'] ?? decoded['message'] ?? decoded['detail'];
        if (e is String) {
          msg = e;
        } else if (e is List && e.isNotEmpty) {
          final first = e.first;
          msg = first is Map && first['msg'] != null ? first['msg'].toString() : first.toString();
        } else if (e != null) {
          msg = e.toString();
        }
      }
    } catch (_) {
      // not JSON
    }
    if (msg == null || msg.isEmpty) {
      final trimmed = body.trim();
      msg = trimmed.isNotEmpty && trimmed.length < 200
          ? trimmed
          : (reasonPhrase ?? 'HTTP $status');
    }
    return ApiException(status, msg);
  }

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isNetworkError => status == 0;

  @override
  String toString() => 'ApiException($status): $message';
}
