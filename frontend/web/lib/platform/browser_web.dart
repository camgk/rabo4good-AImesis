import 'package:web/web.dart' as web;

String? storageGet(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void storageSet(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

void storageRemove(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}

void openUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

void printPage() => web.window.print();

/// Base URI of the app (honours `<base href>`), so `config.json` resolves to
/// the app root even on deep links like /patients/PAT-2026-0001/passport.
Uri appBaseUri() {
  try {
    final base = web.document.baseURI;
    if (base.isNotEmpty) return Uri.parse(base);
  } catch (_) {}
  return Uri.base;
}
