import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _advisory = 'Advisory only — requires clinician sign-off. Demo data, not for clinical use.';

final Map<String, dynamic> accountJson = {
  'id': 'acc-onc',
  'email': 'oncologist@demo.aimesis.app',
  'role': 'oncologist',
  'displayName': 'Oncologist (demo)',
  'patientIds': ['casus-1', 'casus-2', 'casus-3', 'casus-4'],
};

final Map<String, dynamic> patientJson = {
  'id': 'casus-1',
  'alias': 'Casus 1',
  'age': 16,
  'sex': 'F',
  'diagnosis': 'Neuroblastoma',
  'protocol': 'HR-NBL2 · RAPID COJEC',
  'cycle': 'B4',
  'cycleStart': '2026-09-25',
  'overallTier': 'high',
  'planStatus': 'draft',
  'language': 'nl',
  'weightKg': 52,
  'heightCm': 160,
  'bsaM2': 1.52,
  'diagnosisGroup': 'solid',
  'chemo': [
    {'drug': 'vincristine', 'doseMgM2': 1.5, 'days': [1]},
    {'drug': 'cisplatin', 'doseMgM2': 80, 'days': [1]},
  ],
  'activeMeds': <String>[],
  'history': [
    {
      'cycle': 'B3',
      'date': '2026-09-05',
      'antiemetics': 'Ondansetron 2x/d + aprepitant + dexamethasone + olanzapine',
      'nauseaDays': [2],
      'vomitingDays': <int>[],
      'note': 'Toch nausea gehad op dag 2 (toernota)',
    }
  ],
  'riskFactors': {'canSwallowTablets': true, 'preferredRoute': 'oral_tablet', 'anticipatory': false},
  'pairingCode': 'C1-NBL2',
};

final Map<String, dynamic> planJson = {
  'patientId': 'casus-3',
  'status': 'awaiting_pharmacist',
  'refused': false,
  'refusalReasons': <String>[],
  'drugTiers': [
    {'drug': 'ifosfamide', 'doseMgM2': 1800, 'tier': 'moderate', 'rule': 'Ifosfamide = moderate', 'source': 'UZA v2 (mock rules)'},
    {'drug': 'etoposide', 'doseMgM2': 100, 'tier': 'low', 'rule': 'Etoposide = low', 'source': 'UZA v2 (mock rules)'},
  ],
  'dayTiers': [
    {'day': 1, 'tier': 'high', 'drugs': ['ifosfamide', 'etoposide']},
    {'day': 2, 'tier': 'high', 'drugs': ['ifosfamide', 'etoposide']},
  ],
  'overallTier': 'high',
  'combinationRules': [
    {'rule': 'Ifosfamide + Etoposide = HEC', 'source': 'UZA v2 + POGO'},
  ],
  'dexamethasone': {'blocked': false, 'source': 'UZA v2 (mock rules)'},
  'antiemetics': [
    {
      'drug': 'ondansetron',
      'doseMg': 7.1,
      'unit': 'mg',
      'frequency': '3x/d',
      'route': 'oral_tablet',
      'days': [1, 2, 3, 4, 5, 6],
      'formula': 'min(5 mg/m² × 1.41 m², 8 mg) = 7.1 mg',
      'steps': ['5 × 1.41 = 7.05 mg', '→ 7.1 mg'],
      'source': 'UZA v2 · Ondansetron 5 mg/m², max 8 mg/dose',
      'notes': <String>[],
    },
    {
      'drug': 'olanzapine',
      'doseMg': 4,
      'unit': 'mg',
      'frequency': '1x/d (evening)',
      'route': 'oral_tablet',
      'days': [1, 3],
      'formula': '45 kg × 0.1 = 4.5 mg → 4.5 mg',
      'source': 'UZA v2 (mock rules)',
    },
  ],
  'breakthrough': [
    {
      'drug': 'alizapride',
      'doseMg': 75,
      'unit': 'mg',
      'frequency': '3x/d',
      'route': 'oral_tablet',
      'formula': '5 mg/kg/day',
      'source': 'UZA v2 (mock rules)',
      'notes': ['mock dose'],
    }
  ],
  'alternatives': [
    {'title': 'Palonosetron IV', 'detail': 'once instead of ondansetron', 'source': 'UZA v2'},
  ],
  'stepUps': [
    {'title': 'Extend aprepitant to days 4–5', 'reason': 'prior nausea day 4', 'source': 'UZA v2'},
  ],
  'interactions': [
    {'severity': 'info', 'drugs': ['aprepitant', 'dexamethasone'], 'message': 'halved', 'source': 'BCFI/CBIP (mock)'},
    {
      'severity': 'critical',
      'drugs': ['voriconazole', 'vincristine'],
      'message': 'Strong CYP3A4 inhibition',
      'alternative': 'Consider an echinocandin',
      'source': 'BCFI/CBIP (mock)',
    },
  ],
  'uzaVsPogo': [
    {'item': 'ifosfamide + etoposide', 'uzaTier': 'high', 'pogoTier': 'high', 'differs': false, 'note': ''},
    {'item': 'doxorubicin', 'uzaTier': 'high', 'pogoTier': 'moderate', 'differs': true, 'note': 'UZA stricter'},
  ],
  'episodesSummary': {
    'currentCycle': [
      {'day': 1, 'nausea': 2, 'vomiting': 1}
    ],
    'priorNauseaDays': [4],
  },
  'signoffs': {
    'oncologist': {'by': 'Oncologist (demo)', 'at': '2026-10-29T10:00:00Z'},
    'pharmacist': null,
  },
  'comments': [
    {'by': 'Hospital pharmacist (demo)', 'role': 'pharmacist', 'at': '2026-10-29T10:05:00Z', 'text': 'Check route'},
  ],
  'advisory': _advisory,
};

final Map<String, dynamic> passportJson = {
  'patientId': 'casus-1',
  'alias': 'Casus 1',
  'lang': 'nl',
  'title': 'CINV-paspoort',
  'overallTier': 'high',
  'status': 'approved',
  'signedOff': true,
  'days': [
    {
      'day': 1,
      'label': 'Dag 1',
      'date': '2026-09-25',
      'items': [
        {'time': '08:00', 'medicine': 'Ondansetron', 'amount': '7.6 mg', 'route': 'tablet'},
        {'time': '20:00', 'medicine': 'Olanzapine', 'amount': '5 mg', 'route': 'tablet', 'note': "'s avonds"},
      ],
    }
  ],
  'warningSigns': ['Braakt meer dan 3 keer per dag'],
  'wardPhone': '+32 3 000 00 00',
  'resources': [
    {
      'institution': 'Stichting tegen Kanker',
      'title': 'Misselijkheid en braken',
      'format': 'Web page',
      'language': 'nl',
      'url': 'https://www.cancer.be/kanker/bijwerkingen/misselijkheid-en-braken',
      'effort': 'low',
      'effortNote': 'Direct web article',
    }
  ],
  'pairingCode': 'C1-NBL2',
  'disclaimer': 'Demodata, niet voor klinisch gebruik.',
};

final Map<String, dynamic> episodeJson = {
  'id': 'ep-1',
  'patientId': 'casus-1',
  'type': 'nausea',
  'severity': 3,
  'at': '2026-10-29T09:30:00Z',
  'cycleDay': 35,
  'loggedBy': 'acc-teen1',
  'loggedByRole': 'patient',
};

/// Round-trips through JSON text to make sure toJson is encodable.
Map<String, dynamic> _rt(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void main() {
  group('models', () {
    test('Account', () {
      final a = Account.fromJson(accountJson);
      expect(a.isClinician, isTrue);
      expect(a.isFamily, isFalse);
      expect(a.canSubmitPlan, isTrue);
      expect(a.patientIds, hasLength(4));
      expect(Account.fromJson(_rt(a.toJson())).email, a.email);
      final fam = Account.fromJson({'id': 'acc-teen1', 'role': 'patient'});
      expect(fam.isFamily, isTrue);
      expect(fam.patientIds, isEmpty);
    });

    test('Patient', () {
      final p = Patient.fromJson(patientJson);
      expect(p.alias, 'Casus 1');
      expect(p.weightKg, 52.0);
      expect(p.bsaM2, 1.52);
      expect(p.chemo.map((c) => c.drug), ['vincristine', 'cisplatin']);
      expect(p.chemo[1].doseMgM2, 80.0);
      expect(p.history.single.nauseaDays, [2]);
      expect(p.history.single.hadNausea, isTrue);
      expect(p.riskFactors.preferredRoute, Route.oralTablet);
      expect(p.riskFactors.priorNauseaNote, isNull);
      expect(p.pairingCode, 'C1-NBL2');
      expect(p.hasAnthropometrics, isTrue);
      expect(p.tierLabel, 'High');
      final back = Patient.fromJson(_rt(p.toJson()));
      expect(back.chemo.length, 2);
      expect(back.riskFactors.canSwallowTablets, isTrue);
    });

    test('Patient tolerates missing optional fields', () {
      final p = Patient.fromJson({'id': 'x', 'alias': 'Casus X', 'bsaM2': null});
      expect(p.bsaM2, isNull);
      expect(p.chemo, isEmpty);
      expect(p.history, isEmpty);
      expect(p.hasAnthropometrics, isFalse);
      expect(p.riskFactors.preferredRoute, 'oral_tablet');
    });

    test('Plan', () {
      final plan = Plan.fromJson(planJson);
      expect(plan.isAwaitingPharmacist, isTrue);
      expect(plan.overallTier, 'high');
      expect(plan.tierRank, 3);
      expect(plan.drugTiers.first.doseMgM2, 1800.0);
      expect(plan.dayTiers, hasLength(2));
      expect(plan.combinationRules.single.source, 'UZA v2 + POGO');
      expect(plan.dexamethasone.blocked, isFalse);
      expect(plan.dexamethasone.reason, isNull);
      expect(plan.antiemetics.first.doseLabel, '7.1 mg');
      expect(plan.antiemetics.first.daysLabel, 'Days 1–6');
      expect(plan.antiemetics[1].steps, isEmpty); // missing → empty
      expect(plan.antiemetics[1].notes, isEmpty);
      expect(plan.antiemetics[1].doseLabel, '4 mg');
      expect(plan.antiemetics[1].daysLabel, 'Days 1, 3');
      expect(plan.breakthrough.single.days, isEmpty);
      expect(plan.alternatives.single.title, 'Palonosetron IV');
      expect(plan.stepUps.single.reason, 'prior nausea day 4');
      expect(plan.hasCriticalInteraction, isTrue);
      expect(plan.interactionsBySeverity.first.isCritical, isTrue);
      expect(plan.interactions[1].alternative, 'Consider an echinocandin');
      expect(plan.hasPogoDifferences, isTrue);
      expect(plan.episodesSummary.currentCycle.single.total, 3);
      expect(plan.episodesSummary.priorNauseaDays, [4]);
      expect(plan.signoffs.oncologist?.by, 'Oncologist (demo)');
      expect(plan.signoffs.pharmacist, isNull);
      expect(plan.signoffs.complete, isFalse);
      expect(plan.comments.single.text, 'Check route');
      expect(plan.advisory, _advisory);
      final back = Plan.fromJson(_rt(plan.toJson()));
      expect(back.antiemetics.length, 2);
      expect(back.signoffs.pharmacist, isNull);
    });

    test('Plan tolerates a refused / minimal payload', () {
      final plan = Plan.fromJson({
        'patientId': 'casus-x',
        'refused': true,
        'refusalReasons': ['BSA missing'],
        'overallTier': null,
        'signoffs': {'oncologist': null, 'pharmacist': null},
      });
      expect(plan.refused, isTrue);
      expect(plan.refusalReasons, ['BSA missing']);
      expect(plan.overallTier, isNull);
      expect(plan.tierLabel, 'Unknown');
      expect(plan.antiemetics, isEmpty);
      expect(plan.isDraft, isTrue);
      expect(plan.advisory, Plan.defaultAdvisory);
    });

    test('Passport', () {
      final p = Passport.fromJson(passportJson);
      expect(p.signedOff, isTrue);
      expect(p.days.single.items, hasLength(2));
      expect(p.days.single.items[1].note, "'s avonds");
      expect(p.days.single.items[0].note, isNull);
      expect(p.resources.single.isLowEffort, isTrue);
      expect(p.wardPhone, '+32 3 000 00 00');
      expect(Passport.fromJson(_rt(p.toJson())).days.single.label, 'Dag 1');
    });

    test('Episode', () {
      final e = Episode.fromJson(episodeJson);
      expect(e.isNausea, isTrue);
      expect(e.severity, 3);
      expect(e.cycleDay, 35);
      expect(e.loggedByFamily, isTrue);
      expect(e.atDate, isNotNull);
      final noSev = Episode.fromJson({...episodeJson}..remove('severity'));
      expect(noSev.severity, isNull);
      expect(noSev.toJson().containsKey('severity'), isFalse);
    });

    test('Tier helpers', () {
      expect(Tier.max(['low', 'high', 'moderate']), 'high');
      expect(Tier.rank('minimal'), 0);
      expect(Tier.rank(null), -1);
      expect(Tier.label('moderate'), 'Moderate');
    });
  });

  group('AimesisApi', () {
    test('login stores token and sends Bearer header', () async {
      final seen = <http.Request>[];
      final client = MockClient((req) async {
        seen.add(req);
        if (req.url.path == '/auth/login') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['email'], 'oncologist@demo.aimesis.app');
          expect(body['password'], 'aimesis-demo');
          expect(req.headers['Content-Type'], startsWith('application/json'));
          return http.Response(jsonEncode({'token': 'tok-123', 'account': accountJson}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path == '/patients') {
          return http.Response(
              jsonEncode([
                {'id': 'casus-1', 'alias': 'Casus 1', 'overallTier': 'high'}
              ]),
              200);
        }
        if (req.url.path == '/patients/casus-1/passport') {
          expect(req.url.queryParameters['lang'], 'fr');
          return http.Response.bytes(utf8.encode(jsonEncode(passportJson)), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final api = AimesisApi(baseUrl: 'http://api.test/', client: client);
      expect(api.baseUrl, 'http://api.test');
      expect(api.token, isNull);
      final acc = await api.login('oncologist@demo.aimesis.app', 'aimesis-demo');
      expect(acc.isClinician, isTrue);
      expect(api.token, 'tok-123');
      expect(api.account?.id, 'acc-onc');
      expect(seen.first.headers.containsKey('Authorization'), isFalse);

      final pts = await api.patients();
      expect(pts.single.alias, 'Casus 1');
      expect(seen.last.headers['Authorization'], 'Bearer tok-123');

      final pp = await api.passport('casus-1', 'fr');
      expect(pp.title, 'CINV-paspoort');

      api.logout();
      expect(api.token, isNull);
      expect(api.account, isNull);
    });

    test('401 → ApiException with server message', () async {
      var unauthorizedCalls = 0;
      final api = AimesisApi(
        baseUrl: 'http://api.test',
        client: MockClient((req) async => http.Response('{"error": "Invalid email or password"}', 401)),
      )..onUnauthorized = () => unauthorizedCalls++;
      await expectLater(
        api.login('x@y.z', 'nope'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'Invalid email or password')
            .having((e) => e.isUnauthorized, 'isUnauthorized', true)),
      );
      expect(api.token, isNull);
      expect(unauthorizedCalls, 1);
    });

    test('403 with non-JSON body still gives an ApiException', () async {
      final api = AimesisApi(
        baseUrl: 'http://api.test',
        client: MockClient((req) async => http.Response('Forbidden', 403)),
      );
      await expectLater(
          api.submitPlan('casus-1'),
          throwsA(isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', 'Forbidden')));
    });

    test('write endpoints send the right method, path and body', () async {
      final calls = <String>[];
      final api = AimesisApi(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          calls.add('${req.method} ${req.url.path} ${req.body}');
          if (req.url.path.endsWith('/episodes')) {
            return http.Response(jsonEncode(episodeJson), 201);
          }
          if (req.url.path == '/pairing') {
            return http.Response(jsonEncode({'id': 'casus-2', 'alias': 'Casus 2'}), 200);
          }
          if (req.url.path == '/resources') {
            return http.Response(jsonEncode(passportJson['resources']), 200);
          }
          return http.Response(jsonEncode(planJson), 200);
        }),
      )..token = 't';

      await api.updateRiskFactors('casus-1', const RiskFactors(canSwallowTablets: false, preferredRoute: 'oral_liquid'));
      await api.submitPlan('casus-1');
      await api.approvePlan('casus-1', comment: 'ok');
      await api.returnPlan('casus-1', 'fix route');
      final ep = await api.logEpisode('casus-1', 'vomiting', severity: 4);
      final pair = await api.pair(' C2-ALL8 ');
      final res = await api.resources(lang: 'nl');

      expect(ep.patientId, 'casus-1');
      expect(pair.id, 'casus-2');
      expect(res.single.language, 'nl');
      expect(calls[0], startsWith('PUT /patients/casus-1/risk-factors'));
      expect(calls[0], contains('"preferredRoute":"oral_liquid"'));
      expect(calls[1], startsWith('POST /patients/casus-1/plan/submit'));
      expect(calls[2], contains('"comment":"ok"'));
      expect(calls[3], contains('"comment":"fix route"'));
      expect(calls[4], contains('"type":"vomiting"'));
      expect(calls[4], contains('"severity":4'));
      expect(calls[5], contains('"code":"C2-ALL8"'));
    });

    test('network errors map to status 0', () async {
      final api = AimesisApi(
        baseUrl: 'http://api.test',
        client: MockClient((req) async => throw http.ClientException('connection refused')),
      );
      await expectLater(api.demoAccounts(),
          throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'network', true)));
    });
  });
}
