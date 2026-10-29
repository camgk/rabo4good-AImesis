/// Browser helpers (session storage, open URL, print) with a VM-safe stub so
/// that `flutter test` can load the app on the Dart VM.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
