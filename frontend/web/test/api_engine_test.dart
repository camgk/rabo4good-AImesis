import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:aimesis_web/onboarding/onboarding_models.dart';
import 'package:aimesis_web/onboarding/suggestion_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  CycleRef ref() {
    final now = DateTime(2026, 10, 29);
    final first = CycleRecord(id: 'c1', patientId: 'p1', createdAt: now, createdBy: 'x')
      ..session.priorNausea = 'nausea day 2-3';
    final current = CycleRecord(id: 'c2', patientId: 'p1', createdAt: now, createdBy: 'x')
      ..intake.weightKg = 30
      ..intake.heightCm = 135
      ..intake.chemo = [const ChemoRow(drug: 'cisplatin', doseMgM2: 80, days: [1, 2])];
    final p = PatientRecord(
      id: 'p1',
      createdAt: now,
      isLocal: true,
      profile: PatientProfile(alias: 'Test', age: 9, diagnosis: 'Osteosarcoma'),
      imported: const [PriorCycle(label: 'Cycle A1', note: 'vomited twice')],
      cycles: [first, current],
    );
    return (patient: p, cycle: current);
  }

  final planJson = {
    'patientId': 'p1',
    'status': 'draft',
    'overallTier': 'high',
    'drugTiers': [
      {'drug': 'cisplatin', 'doseMgM2': 80, 'tier': 'high', 'rule': '≥50 mg/m²', 'source': 'POGO'}
    ],
    'dexamethasone': {'blocked': true, 'reason': 'Protocol forbids steroids', 'source': 'UZA'},
    'antiemetics': [
      {'drug': 'ondansetron', 'doseMg': 4, 'unit': 'mg', 'frequency': '3x/day', 'route': 'oral_liquid', 'days': [1, 2], 'formula': '0.15 mg/kg'}
    ],
    'interactions': [
      {'severity': 'critical', 'drugs': ['aprepitant', 'ifosfamide'], 'message': 'Neurotoxicity risk', 'source': 'UZA'}
    ],
  };

  test('ApiSuggestionEngine sends history and maps the plan', () async {
    late Map<String, dynamic> sent;
    final api = AimesisApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({'plan': planJson, 'ai': null, 'aiError': 'no key'}), 200,
            headers: {'content-type': 'application/json'});
      }),
    )..token = 't';
    final updates = await ApiSuggestionEngine(api).run(ref()).toList();
    final history = (sent['patient']['history'] as List).cast<Map<String, dynamic>>();
    expect(history.map((h) => h['note']), ['vomited twice', 'nausea day 2-3']);

    final last = updates.last;
    expect(last.stepKey, 'combine');
    expect(last.state, ModelState.failed);
    final s = last.result!;
    expect(s.placeholder, isFalse);
    expect(s.overallTier, 'high');
    expect(s.dexBlocked, isTrue);
    expect(s.dexBlockedReason, 'Protocol forbids steroids');
    expect(s.antiemetics.single.dose, '4 mg · 3x/day');
    expect(s.criticalInteractions.single, contains('Neurotoxicity'));
    final round = Suggestion.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(round.dexBlockedReason, s.dexBlockedReason);
    expect(round.criticalInteractions, s.criticalInteractions);
    expect(round.aiError, 'no key');
  });

  test('ApiSuggestionEngine marks steps failed when the request fails', () async {
    final api = AimesisApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async => http.Response('{"error":"boom"}', 500)),
    )..token = 't';
    final updates = await ApiSuggestionEngine(api).run(ref()).toList();
    expect(updates.last.state, ModelState.failed);
    expect(updates.every((u) => u.result == null), isTrue);
    expect(updates.last.error, contains('boom'));
  });
}
