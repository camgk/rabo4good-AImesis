// Tolerant JSON parsing helpers (internal; not exported).
// Missing / null / wrongly-typed optional values become null, 0, '' or [].

typedef Json = Map<String, dynamic>;

String str(Object? v, [String fallback = '']) =>
    v == null ? fallback : (v is String ? v : v.toString());

String? strOrNull(Object? v) =>
    v == null ? null : (v is String ? v : v.toString());

double dbl(Object? v, [double fallback = 0]) => dblOrNull(v) ?? fallback;

double? dblOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int integer(Object? v, [int fallback = 0]) => intOrNull(v) ?? fallback;

int? intOrNull(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

bool boolean(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

Json? mapOrNull(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

Json mapOrEmpty(Object? v) => mapOrNull(v) ?? <String, dynamic>{};

List<String> strList(Object? v) =>
    v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : <String>[];

List<int> intList(Object? v) =>
    v is List ? v.map(intOrNull).whereType<int>().toList() : <int>[];

List<T> objList<T>(Object? v, T Function(Json) fromJson) => v is List
    ? v.map(mapOrNull).whereType<Json>().map(fromJson).toList()
    : <T>[];

/// Adds [key] to [m] only when [value] is not null (for optional fields).
void putIfNotNull(Json m, String key, Object? value) {
  if (value != null) m[key] = value;
}
