import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'models_test.dart' show planJson;

void main() {
  const patient = Patient(
    id: 'new',
    alias: 'Test',
    age: 9,
    sex: 'M',
    protocol: 'Euronet',
    cycle: 'C1',
    weightKg: 30,
    heightCm: 135,
    chemo: [ChemoRow(drug: 'cisplatin', doseMgM2: 80, days: [1])],
    history: [HistoryEntry(cycle: 'C0', note: 'nausea day 2')],
    riskFactors: RiskFactors(canSwallowTablets: false, preferredRoute: 'oral_liquid'),
  );

  test('evaluateCycle posts the patient and parses plan + ai', () async {
    late http.Request seen;
    final api = AimesisApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'plan': planJson,
              'ai': {'summary': 'High risk.', 'familyExplanation': 'Uitleg', 'model': 'gemini-x'},
              'aiError': null,
            }),
            200,
            headers: {'content-type': 'application/json'});
      }),
    )..token = 'tok';

    final ev = await api.evaluateCycle(patient);
    expect(seen.method, 'POST');
    expect(seen.url.path, '/cycles/evaluate');
    expect(seen.headers['Authorization'] ?? seen.headers['authorization'], 'Bearer tok');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    final p = body['patient'] as Map<String, dynamic>;
    expect(p['alias'], 'Test');
    expect((p['chemo'] as List).single['drug'], 'cisplatin');
    expect((p['history'] as List).single['note'], 'nausea day 2');
    expect(p['riskFactors']['preferredRoute'], 'oral_liquid');

    expect(ev.plan.overallTier, Plan.fromJson(planJson).overallTier);
    expect(ev.plan.antiemetics.length, Plan.fromJson(planJson).antiemetics.length);
    expect(ev.aiSummary, 'High risk.');
    expect(ev.familyExplanation, 'Uitleg');
    expect(ev.aiModel, 'gemini-x');
    expect(ev.aiError, isNull);
    expect(ev.hasAi, isTrue);
  });

  test('evaluateCycle tolerates ai null with aiError', () async {
    final api = AimesisApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async => http.Response(
          jsonEncode({'plan': planJson, 'ai': null, 'aiError': 'quota exceeded'}), 200,
          headers: {'content-type': 'application/json'})),
    )..token = 'tok';
    final ev = await api.evaluateCycle(patient);
    expect(ev.hasAi, isFalse);
    expect(ev.aiError, 'quota exceeded');
  });
}
