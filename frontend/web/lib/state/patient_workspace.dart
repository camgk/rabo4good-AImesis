import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/foundation.dart';

import 'app_state.dart';

/// Loads and caches one patient + their plan while the clinician moves
/// between the workspace tabs. Mutations (risk factors, sign-off) replace
/// [plan] with the server's recomputed plan.
class PatientWorkspace extends ChangeNotifier {
  PatientWorkspace(this._app, this.patientId);

  final AppState _app;
  final String patientId;

  Patient? patient;
  Plan? plan;
  Object? error;
  bool loading = false;
  bool _disposed = false;

  bool get ready => patient != null && plan != null;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait([
        _app.api.patient(patientId),
        _app.api.plan(patientId),
      ]);
      patient = results[0] as Patient;
      plan = results[1] as Plan;
    } catch (e) {
      error = e;
      if (e is ApiException && e.status == 401) _app.handleUnauthorized();
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Runs a plan-changing call and stores the returned plan.
  /// Rethrows so the caller can show a snackbar.
  Future<Plan> mutate(Future<Plan> Function(AimesisApi api) call) async {
    try {
      final p = await call(_app.api);
      plan = p;
      _notify();
      _app.planChanged();
      return p;
    } on ApiException catch (e) {
      if (e.status == 401) _app.handleUnauthorized();
      rethrow;
    }
  }

  /// Reloads the patient (e.g. after risk factors changed).
  Future<void> refreshPatient() async {
    try {
      patient = await _app.api.patient(patientId);
      _notify();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
