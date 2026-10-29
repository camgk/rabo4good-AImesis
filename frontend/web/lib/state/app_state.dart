import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../onboarding/onboarding_store.dart';
import '../onboarding/suggestion_engine.dart';
import '../platform/browser.dart';
import 'patient_workspace.dart';

/// App-wide session state: config, API client, current account and the
/// per-patient workspace cache (so switching tabs doesn't refetch).
class AppState extends ChangeNotifier {
  AppState({
    required this.config,
    AimesisApi? api,
    OnboardingStore? onboarding,
    SuggestionEngine? suggestionEngine,
  })  : api = api ?? AimesisApi(baseUrl: config.apiUrl),
        onboarding = onboarding ?? OnboardingStore(),
        suggestionEngine = suggestionEngine ?? PlaceholderSuggestionEngine();

  static const _tokenKey = 'aimesis.web.token';

  final AppConfig config;
  final AimesisApi api;

  /// New patients being onboarded (kept in this browser tab for now).
  final OnboardingStore onboarding;

  /// Runs the models during onboarding. Placeholder until the calculation
  /// APIs are built.
  final SuggestionEngine suggestionEngine;

  Account? _account;
  Account? get account => _account;
  bool get isLoggedIn => _account != null;

  bool _restoring = false;
  bool get restoring => _restoring;

  final Map<String, PatientWorkspace> _workspaces = {};

  /// Bumped whenever a plan changes, so lists (patients, queue) can refresh.
  int _plansVersion = 0;
  int get plansVersion => _plansVersion;

  /// Try to restore a session from `sessionStorage` (survives page refresh).
  Future<void> restore() async {
    final token = storageGet(_tokenKey);
    if (token == null || token.isEmpty) return;
    _restoring = true;
    notifyListeners();
    try {
      api.token = token;
      final me = await api.me();
      if (me.isClinician) {
        _account = me;
      } else {
        api.logout();
        storageRemove(_tokenKey);
      }
    } catch (_) {
      api.logout();
      storageRemove(_tokenKey);
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Logs in; throws [ApiException] on bad credentials and
  /// [FamilyAccountException] when a family account tries to log in here.
  Future<Account> login(String email, String password) async {
    final acc = await api.login(email.trim(), password);
    if (!acc.isClinician) {
      api.logout();
      throw const FamilyAccountException();
    }
    _account = acc;
    final token = api.token;
    if (token != null) storageSet(_tokenKey, token);
    _workspaces.clear();
    notifyListeners();
    return acc;
  }

  void logout() {
    api.logout();
    storageRemove(_tokenKey);
    _account = null;
    _workspaces.clear();
    notifyListeners();
  }

  /// Handle a 401 anywhere: the session has expired.
  void handleUnauthorized() {
    if (_account != null) logout();
  }

  PatientWorkspace workspace(String patientId) => _workspaces.putIfAbsent(
        patientId,
        () => PatientWorkspace(this, patientId)..load(),
      );

  /// Whether [workspace] already holds data for [patientId].
  bool hasWorkspace(String patientId) => _workspaces[patientId]?.ready ?? false;

  void planChanged() {
    _plansVersion++;
    notifyListeners();
  }
}

class FamilyAccountException implements Exception {
  const FamilyAccountException();

  String get message =>
      'This is the care-team app. Families use the AImesis Family app.';

  @override
  String toString() => message;
}
