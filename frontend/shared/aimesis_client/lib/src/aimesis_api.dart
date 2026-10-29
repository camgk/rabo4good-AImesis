import 'models/account.dart';
import 'models/patient_context.dart';
import 'models/plan.dart';
import 'rest/api_core.dart';
import 'rest/api_exception.dart';
import 'rest/episodes_api.dart';
import 'rest/passport_api.dart';

/// REST client for the AImesis (mock) API. One instance per app; holds the
/// bearer token after [login].
class AimesisApi extends ApiCore with EpisodesApi, PassportApi {
  AimesisApi({required super.baseUrl, super.client, super.timeout});

  Account? _account;

  /// Account from the last successful [login] / [me] call.
  Account? get account => _account;

  // ---- auth --------------------------------------------------------------

  /// `GET /auth/demo-accounts` (no auth) — login quick-pick.
  Future<List<DemoAccount>> demoAccounts() async =>
      asList(await getJson('/auth/demo-accounts'), DemoAccount.fromJson);

  /// `POST /auth/login` — stores the token and returns the account.
  Future<Account> login(String email, String password) async {
    token = null;
    final res = asObject(await postJson('/auth/login', {'email': email.trim(), 'password': password}));
    final t = res['token'];
    if (t is! String || t.isEmpty) {
      throw const ApiException(200, 'Login response did not contain a token.');
    }
    token = t;
    final acc = res['account'];
    _account = acc is Map ? Account.fromJson(asObject(acc)) : await me();
    return _account!;
  }

  /// Clears the token (no server call).
  void logout() {
    token = null;
    _account = null;
  }

  /// `GET /me`
  Future<Account> me() async => _account = Account.fromJson(asObject(await getJson('/me')));

  // ---- patients ----------------------------------------------------------

  /// `GET /patients` (filtered by role).
  Future<List<PatientSummary>> patients() async =>
      asList(await getJson('/patients'), PatientSummary.fromJson);

  /// `GET /patients/{id}`
  Future<Patient> patient(String id) async =>
      Patient.fromJson(asObject(await getJson('/patients/${_e(id)}')));

  /// `POST /pairing` `{"code"}` — adds the patient to the (family) account.
  Future<PatientSummary> pair(String code) async =>
      PatientSummary.fromJson(asObject(await postJson('/pairing', {'code': code.trim()})));

  // ---- plan --------------------------------------------------------------

  /// `GET /patients/{id}/plan`
  Future<Plan> plan(String patientId) async =>
      Plan.fromJson(asObject(await getJson('/patients/${_e(patientId)}/plan')));

  /// `PUT /patients/{id}/risk-factors` → recomputed plan.
  Future<Plan> updateRiskFactors(String patientId, RiskFactors rf) async =>
      Plan.fromJson(asObject(await putJson('/patients/${_e(patientId)}/risk-factors', rf.toJson())));

  /// `POST /patients/{id}/plan/submit` (oncologist).
  Future<Plan> submitPlan(String patientId) async =>
      Plan.fromJson(asObject(await postJson('/patients/${_e(patientId)}/plan/submit')));

  /// `POST /patients/{id}/plan/approve` (pharmacist).
  Future<Plan> approvePlan(String patientId, {String? comment}) async => Plan.fromJson(asObject(
      await postJson('/patients/${_e(patientId)}/plan/approve', {
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      })));

  /// `POST /patients/{id}/plan/return` (pharmacist, comment required).
  Future<Plan> returnPlan(String patientId, String comment) async => Plan.fromJson(
      asObject(await postJson('/patients/${_e(patientId)}/plan/return', {'comment': comment})));

  // ---- misc --------------------------------------------------------------

  /// `GET /healthz` — true when the server answers `{"ok": true}`.
  Future<bool> healthz() async {
    final res = await getJson('/healthz');
    return res is Map && res['ok'] == true;
  }

  static String _e(String s) => Uri.encodeComponent(s);
}
