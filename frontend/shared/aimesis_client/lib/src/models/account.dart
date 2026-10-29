import 'json_helpers.dart';
import 'tier.dart';

/// Logged-in account (`GET /me`, `POST /auth/login`).
class Account {
  final String id;
  final String email;
  final String role;
  final String displayName;
  final List<String> patientIds;

  const Account({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    this.patientIds = const [],
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: str(json['id']),
        email: str(json['email']),
        role: str(json['role']),
        displayName: str(json['displayName']),
        patientIds: strList(json['patientIds']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'displayName': displayName,
        'patientIds': patientIds,
      };

  bool get isClinician => Role.isClinician(role);
  bool get isFamily => Role.isFamily(role);
  bool get isOncologist => role == Role.oncologist;
  bool get isNurse => role == Role.nurse;
  bool get isPharmacist => role == Role.pharmacist;
  bool get isParent => role == Role.parent;
  bool get isPatient => role == Role.patient;

  /// oncologist + nurse may PUT risk factors.
  bool get canEditRiskFactors => isOncologist || isNurse;

  /// oncologist submits the plan (oncologist sign-off).
  bool get canSubmitPlan => isOncologist;

  /// pharmacist approves / returns.
  bool get canApprovePlan => isPharmacist;

  @override
  String toString() => 'Account($id, $role)';
}

/// Entry from `GET /auth/demo-accounts` (login quick-pick).
class DemoAccount {
  final String email;
  final String role;
  final String displayName;

  const DemoAccount({
    required this.email,
    required this.role,
    required this.displayName,
  });

  factory DemoAccount.fromJson(Map<String, dynamic> json) => DemoAccount(
        email: str(json['email']),
        role: str(json['role']),
        displayName: str(json['displayName']),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'role': role,
        'displayName': displayName,
      };

  bool get isClinician => Role.isClinician(role);
  bool get isFamily => Role.isFamily(role);
}
