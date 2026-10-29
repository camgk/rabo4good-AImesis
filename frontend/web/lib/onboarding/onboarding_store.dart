import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/foundation.dart';

import '../platform/browser.dart';
import 'onboarding_models.dart';

/// Patient profiles and their cycles added in this browser tab
/// (`sessionStorage`), so a page refresh or a switch to the pharmacist
/// account keeps them.
///
/// Swap for an API-backed store once the backend has patient and cycle
/// endpoints.
class OnboardingStore extends ChangeNotifier {
  OnboardingStore({this.persist = true}) {
    if (persist) _load();
  }

  static const _key = 'aimesis.web.patients.v2';
  static const _legacyKey = 'aimesis.web.onboarding';

  /// False in tests, so records don't leak between them.
  final bool persist;
  final Map<String, PatientRecord> _patients = {};

  /// All profiles, most recent activity first.
  List<PatientRecord> get patients =>
      _patients.values.toList()..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  /// Patients created here (not in the API).
  List<PatientRecord> get localPatients => patients.where((p) => p.isLocal).toList();

  PatientRecord? patient(String id) => _patients[id];

  CycleRef? cycle(String cycleId) {
    for (final p in _patients.values) {
      for (final c in p.cycles) {
        if (c.id == cycleId) return (patient: p, cycle: c);
      }
    }
    return null;
  }

  List<CycleRef> _cycles(bool Function(CycleRecord) test) => [
        for (final p in _patients.values)
          for (final c in p.cycles)
            if (test(c)) (patient: p, cycle: c),
      ]..sort((a, b) => (b.cycle.approvedAt ?? b.cycle.updatedAt).compareTo(a.cycle.approvedAt ?? a.cycle.updatedAt));

  List<CycleRef> get inProgress => _cycles((c) => !c.isSent);
  List<CycleRef> get sent => _cycles((c) => c.isSent);

  static String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';

  /// New patient with an empty first cycle.
  CycleRef createPatient({required String createdBy}) {
    final now = DateTime.now();
    final p = PatientRecord(id: _id('NEW'), createdAt: now, isLocal: true);
    final c = CycleRecord(id: _id('CYC'), patientId: p.id, createdAt: now, createdBy: createdBy);
    p.cycles.add(c);
    _patients[p.id] = p;
    _changed();
    return (patient: p, cycle: c);
  }

  /// Profile for an existing (API) patient, holding its record's cycles as
  /// read-only history. Refreshes the profile if it already exists.
  PatientRecord importApiPatient(Patient api) {
    final existing = _patients[api.id];
    final profile = PatientProfile.fromApi(api);
    if (existing != null) {
      profile
        ..formulationPreference = existing.profile.formulationPreference
        ..whatHelps = existing.profile.whatHelps;
      existing
        ..profile = profile
        ..imported = priorCyclesOf(api);
      _changed();
      return existing;
    }
    final p = PatientRecord(
      id: api.id,
      createdAt: DateTime.now(),
      isLocal: false,
      profile: profile,
      imported: priorCyclesOf(api),
    );
    _patients[p.id] = p;
    _changed();
    return p;
  }

  /// Starts the next cycle for [p], carrying over what usually stays the
  /// same. Weight and height are left empty: they must be measured again.
  /// [api] seeds the first cycle added to an existing API patient.
  CycleRef startCycle(PatientRecord p, {required String createdBy, Patient? api}) {
    final open = p.inProgress;
    if (open != null) return (patient: p, cycle: open);
    final prev = p.latest;
    final now = DateTime.now();
    final c = CycleRecord(
      id: _id('CYC'),
      patientId: p.id,
      createdAt: now,
      createdBy: createdBy,
      intake: CycleIntake(
        protocol: prev?.intake.protocol ?? api?.protocol ?? '',
        firstCycle: false,
        chemo: [...?(prev?.intake.chemo ?? api?.chemo)],
        activeMeds: [...?(prev?.intake.activeMeds ?? api?.activeMeds)],
      ),
      session: CycleSession(
        canSwallowTablets: prev?.session.canSwallowTablets ?? api?.riskFactors.canSwallowTablets ?? true,
        preferredRoute: prev?.session.preferredRoute ?? api?.riskFactors.preferredRoute ?? DoseRoute.oralTablet,
        anticipatory: prev?.session.anticipatory ?? api?.riskFactors.anticipatory ?? false,
      ),
    );
    p.cycles.add(c);
    _changed();
    return (patient: p, cycle: c);
  }

  void save(PatientRecord p, [CycleRecord? touched]) {
    touched?.updatedAt = DateTime.now();
    _patients[p.id] = p;
    _changed();
  }

  /// Removes an unsent cycle; a new patient with no cycles left goes too.
  void discardCycle(String cycleId) {
    final ref = cycle(cycleId);
    if (ref == null || ref.cycle.isSent) return;
    ref.patient.cycles.removeWhere((c) => c.id == cycleId);
    if (ref.patient.cycles.isEmpty) _patients.remove(ref.patient.id);
    _changed();
  }

  /// The API record's history plus its current cycle, oldest first.
  static List<PriorCycle> priorCyclesOf(Patient api) => [
        for (final h in api.history)
          PriorCycle(
            label: 'Cycle ${h.cycle}',
            date: h.date,
            summary: h.antiemetics == null ? '' : 'Antiemetics: ${h.antiemetics}',
            note: [
              h.nauseaDays.isEmpty ? 'No nausea' : 'Nausea day ${daysText(h.nauseaDays)}',
              h.vomitingDays.isEmpty ? 'no vomiting' : 'vomiting day ${daysText(h.vomitingDays)}',
              if (h.note.isNotEmpty) '“${h.note}”',
            ].join(' · '),
          ),
        if (api.cycle != null || api.chemo.isNotEmpty)
          PriorCycle(
            label: api.cycle == null ? 'Current cycle' : 'Cycle ${api.cycle}',
            date: api.cycleStart,
            summary: [
              if (api.protocol != null) api.protocol!,
              api.chemo.map((c) => '${c.drug} d${daysText(c.days)}').join(', '),
            ].where((s) => s.isNotEmpty).join(' · '),
            note: 'Plan ${PlanStatus.label(api.planStatus).toLowerCase()}',
            current: true,
          ),
      ];

  void _changed() {
    if (persist) {
      storageSet(_key, jsonEncode([for (final p in _patients.values) p.toJson()]));
    }
    notifyListeners();
  }

  void _load() {
    storageRemove(_legacyKey);
    final raw = storageGet(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      for (final j in jsonDecode(raw) as List) {
        final p = PatientRecord.fromJson(Map<String, dynamic>.from(j as Map));
        _patients[p.id] = p;
      }
    } catch (_) {
      // Unreadable (older format): start clean rather than fail the app.
      _patients.clear();
      storageRemove(_key);
    }
  }
}
