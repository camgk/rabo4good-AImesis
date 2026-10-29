// Non-web fallback used by `flutter test` (Dart VM).
final Map<String, String> _memory = {};

String? storageGet(String key) => _memory[key];
void storageSet(String key, String value) => _memory[key] = value;
void storageRemove(String key) => _memory.remove(key);

void openUrl(String url) {}
void printPage() {}

/// Base URI of the app (honours `<base href>` on web).
Uri appBaseUri() => Uri.base;
