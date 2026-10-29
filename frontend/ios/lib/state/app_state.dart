import 'dart:async';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/episode_service.dart';
import '../services/offline_queue.dart';
import '../util/cycle.dart';

const supportedLangs = ['nl', 'fr', 'en'];
const langNames = {'nl': 'Nederlands', 'fr': 'Français', 'en': 'English'};

/// Thrown by [AppState.login] when a care-team account tries the family app.
class ClinicianAccountException implements Exception {
  const ClinicianAccountException();
}

/// Everything the family app knows: session, chosen child, language,
/// passport + episodes for the chosen child, and the offline queue.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({required this.api, required this.prefs})
      : queue = OfflineQueue(prefs) {
    episodes = EpisodeService(api: api, queue: queue);
    _lang = prefs.getString(_kLang) ?? _deviceLang();
    _langExplicit = prefs.getBool(_kLangExplicit) ?? false;
    api.onUnauthorized = _onUnauthorized;
  }

  static const _kToken = 'aimesis.token';
  static const _kLang = 'aimesis.lang';
  static const _kLangExplicit = 'aimesis.langExplicit';
  static const _kPatient = 'aimesis.patientId';

  final AimesisApi api;
  final SharedPreferences prefs;
  final OfflineQueue queue;
  late final EpisodeService episodes;

  bool restoring = true;
  Account? account;
  List<PatientSummary> patients = const [];
  String? _patientId;

  Passport? passport;
  Object? passportError;
  bool passportLoading = false;

  List<Episode> episodeList = const [];
  Object? episodesError;
  bool episodesLoading = false;

  String _lang = 'en';
  bool _langExplicit = false;

  // ---- language ----------------------------------------------------------

  String get lang => _lang;
  Locale get locale => Locale(_lang);
  bool get langExplicit => _langExplicit;

  static String _deviceLang() {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return supportedLangs.contains(code) ? code : 'en';
  }

  Future<void> setLang(String lang, {bool explicit = true}) async {
    if (!supportedLangs.contains(lang)) return;
    final changed = lang != _lang;
    _lang = lang;
    if (explicit) _langExplicit = true;
    await prefs.setString(_kLang, lang);
    await prefs.setBool(_kLangExplicit, _langExplicit);
    notifyListeners();
    if (changed && selected != null) unawaited(loadPassport());
  }

  // ---- session -----------------------------------------------------------

  bool get loggedIn => account != null;
  bool get isTeen => account?.isPatient ?? false;

  Future<void> restore() async {
    final token = prefs.getString(_kToken);
    if (token != null && token.isNotEmpty) {
      api.token = token;
      try {
        final acc = await api.me();
        if (acc.isFamily) {
          account = acc;
          await _loadPatients();
        } else {
          await _clearSession();
        }
      } on ApiException catch (e) {
        if (e.isUnauthorized || e.isForbidden) await _clearSession();
        // network error: stay on login; token kept for the next try
        if (e.isNetworkError) api.token = null;
      } catch (_) {
        api.token = null;
      }
    }
    restoring = false;
    notifyListeners();
    if (loggedIn) unawaited(refreshAll());
  }

  Future<Account> login(String email, String password) async {
    final acc = await api.login(email, password);
    if (!acc.isFamily) {
      api.logout();
      throw const ClinicianAccountException();
    }
    account = acc;
    await prefs.setString(_kToken, api.token ?? '');
    await _loadPatients();
    // Default language = the child's language, unless the family chose one.
    final childLang = selected?.language;
    if (!_langExplicit && childLang != null && supportedLangs.contains(childLang)) {
      _lang = childLang;
      await prefs.setString(_kLang, childLang);
    }
    notifyListeners();
    unawaited(refreshAll());
    return acc;
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    api.logout();
    account = null;
    patients = const [];
    _patientId = null;
    passport = null;
    episodeList = const [];
    await prefs.remove(_kToken);
    await prefs.remove(_kPatient);
  }

  void _onUnauthorized() {
    if (account == null) return;
    // Token expired (12 h): back to the login screen; queued logs stay.
    unawaited(logout());
  }

  // ---- children ----------------------------------------------------------

  PatientSummary? get selected {
    for (final p in patients) {
      if (p.id == _patientId) return p;
    }
    return patients.isEmpty ? null : patients.first;
  }

  int get cycleDay => cycleDayFor(selected?.cycleStartDate, DateTime.now());

  Future<void> _loadPatients() async {
    patients = await api.patients();
    final saved = prefs.getString(_kPatient);
    if (saved != null && patients.any((p) => p.id == saved)) {
      _patientId = saved;
    } else {
      _patientId = patients.isEmpty ? null : patients.first.id;
    }
  }

  Future<void> selectPatient(String id) async {
    _patientId = id;
    passport = null;
    episodeList = const [];
    await prefs.setString(_kPatient, id);
    notifyListeners();
    await refreshAll();
  }

  Future<PatientSummary> pair(String code) async {
    final p = await api.pair(code.trim().toUpperCase());
    await _loadPatients();
    await selectPatient(p.id);
    return p;
  }

  // ---- data --------------------------------------------------------------

  Future<void> refreshAll() async {
    if (!loggedIn) return;
    await episodes.flush();
    try {
      await _loadPatients();
    } catch (_) {/* keep what we have */}
    notifyListeners();
    await Future.wait([loadPassport(), loadEpisodes()]);
  }

  Future<void> loadPassport() async {
    final p = selected;
    if (p == null) return;
    passportLoading = true;
    notifyListeners();
    try {
      final requested = _lang;
      final result = await api.passport(p.id, requested);
      if (selected?.id == p.id && requested == _lang) {
        passport = result;
        passportError = null;
      }
    } catch (e) {
      passportError = e;
    } finally {
      passportLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEpisodes() async {
    final p = selected;
    if (p == null) return;
    episodesLoading = true;
    notifyListeners();
    try {
      final result = await api.episodes(p.id);
      if (selected?.id == p.id) {
        episodeList = result;
        episodesError = null;
      }
    } catch (e) {
      episodesError = e;
    } finally {
      episodesLoading = false;
      notifyListeners();
    }
  }

  /// Logs waiting on this phone for the chosen child.
  List<QueuedEpisode> get pending =>
      selected == null ? const [] : queue.forPatient(selected!.id);

  Future<int> flushQueue() async {
    final left = await episodes.flush();
    notifyListeners();
    if (left == 0) unawaited(loadEpisodes());
    return left;
  }

  /// Called by the log page after an episode was sent or queued.
  void onEpisodeLogged(LogResult r) {
    if (r.episode != null) {
      episodeList = [r.episode!, ...episodeList];
    }
    notifyListeners();
  }

  // ---- "given" ticks (local only) ----------------------------------------

  String _givenKey(int day, PassportItem item) =>
      'aimesis.given|${selected?.id}|${selected?.cycle}|$day|${item.time}|${item.medicine}';

  bool isGiven(int day, PassportItem item) =>
      prefs.getBool(_givenKey(day, item)) ?? false;

  Future<void> setGiven(int day, PassportItem item, bool value) async {
    final key = _givenKey(day, item);
    if (value) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
    notifyListeners();
  }

  // ---- lifecycle ---------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && loggedIn) {
      unawaited(refreshAll());
    }
  }
}

/// Makes [AppState] available to the widget tree and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
