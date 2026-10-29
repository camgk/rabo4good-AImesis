import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:aimesis_ios/app.dart';
import 'package:aimesis_ios/services/episode_service.dart';
import 'package:aimesis_ios/services/offline_queue.dart';
import 'package:aimesis_ios/state/app_state.dart';
import 'package:aimesis_ios/util/cycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _demoAccounts = [
  {'email': 'oncologist@demo.aimesis.app', 'role': 'oncologist', 'displayName': 'Oncologist (demo)'},
  {'email': 'teen.casus1@demo.aimesis.app', 'role': 'patient', 'displayName': 'Casus 1 · teen (demo)'},
  {'email': 'parent.casus2@demo.aimesis.app', 'role': 'parent', 'displayName': 'Casus 2 · parent (demo)'},
];

http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

MockClient _fakeBackend({bool offlineEpisodes = false, bool withDemoAccounts = true}) => MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/demo-accounts') return _json(withDemoAccounts ? _demoAccounts : []);
      if (path == '/auth/login') {
        final body = jsonDecode(req.body) as Map;
        if (body['email'] == 'oncologist@demo.aimesis.app') {
          return _json({
            'token': 't-onc',
            'account': {'id': 'acc-onc', 'email': body['email'], 'role': 'oncologist', 'displayName': 'Oncologist (demo)', 'patientIds': []}
          });
        }
        return _json({
          'token': 't-teen',
          'account': {'id': 'acc-teen1', 'email': body['email'], 'role': 'patient', 'displayName': 'Casus 1 · teen (demo)', 'patientIds': ['PAT-2026-0001']}
        });
      }
      if (path == '/patients') {
        return _json([
          {'id': 'PAT-2026-0001', 'alias': 'Casus 1', 'age': 16, 'cycle': 'B4', 'cycleStart': '2026-09-25', 'language': 'nl', 'tags': ['demo']}
        ]);
      }
      if (path == '/patients/PAT-2026-0001/passport') {
        return _json({
          'patientId': 'PAT-2026-0001', 'alias': 'Casus 1', 'lang': req.url.queryParameters['lang'] ?? 'en',
          'title': 'Passport', 'status': 'draft', 'signedOff': false,
          'days': [
            {'day': 1, 'label': 'Day 1', 'items': [
              {'time': '08:00', 'medicine': 'Ondansetron', 'amount': '7.6 mg', 'route': 'oral_tablet'}
            ]}
          ],
          'warningSigns': ['Vomiting more than 3 times'], 'wardPhone': '+32 3 000 00 00',
          'resources': [], 'disclaimer': 'This schedule was prepared by your care team. Call the ward if you are worried.'
        });
      }
      if (path == '/patients/PAT-2026-0001/episodes') {
        if (offlineEpisodes && req.method == 'POST') {
          throw http.ClientException('offline');
        }
        if (req.method == 'POST') {
          return _json({'id': 'ep1', 'patientId': 'PAT-2026-0001', 'type': 'nausea', 'at': DateTime.now().toUtc().toIso8601String(), 'cycleDay': 1, 'loggedBy': 'acc-teen1', 'loggedByRole': 'patient'});
        }
        return _json([]);
      }
      return _json({'error': 'not found'}, 404);
    });

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<AppState> _state(http.Client client) async {
  SharedPreferences.setMockInitialValues({'aimesis.lang': 'en', 'aimesis.langExplicit': true});
  final prefs = await SharedPreferences.getInstance();
  return AppState(api: AimesisApi(baseUrl: 'http://test', client: client), prefs: prefs);
}

void main() {
  testWidgets('login page shows family demo accounts only', (tester) async {
    _phone(tester);
    final state = await _state(_fakeBackend());
    await tester.pumpWidget(AimesisFamilyApp(state: state));
    await state.restore();
    await tester.pumpAndSettle();

    expect(find.text('AImesis'), findsOneWidget);
    expect(find.text('For families'), findsOneWidget);
    expect(find.text('Casus 1 · teen (demo)'), findsOneWidget);
    expect(find.text('Casus 2 · parent (demo)'), findsOneWidget);
    expect(find.text('Oncologist (demo)'), findsNothing);
    expect(find.text('Demo accounts'), findsOneWidget);
    expect(find.textContaining('not for medical use'), findsNothing);
  });

  testWidgets('no demo accounts from the API → no quick-pick', (tester) async {
    _phone(tester);
    final state = await _state(_fakeBackend(withDemoAccounts: false));
    await tester.pumpWidget(AimesisFamilyApp(state: state));
    await state.restore();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signIn')), findsOneWidget);
    expect(find.byKey(const Key('demoAccounts')), findsNothing);
    expect(find.text('Demo accounts'), findsNothing);
    expect(find.textContaining('Demo password'), findsNothing);
  });

  testWidgets('tapping a demo chip fills credentials and signs in', (tester) async {
    _phone(tester);
    final state = await _state(_fakeBackend());
    await tester.pumpWidget(AimesisFamilyApp(state: state));
    await state.restore();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casus 1 · teen (demo)'));
    await tester.pump();
    expect(find.text('teen.casus1@demo.aimesis.app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('signIn')));
    await tester.pumpAndSettle();
    expect(state.loggedIn, isTrue);
    expect(find.byKey(const Key('cycleDay')), findsOneWidget);
  });

  testWidgets('clinician account is turned away with a friendly message', (tester) async {
    _phone(tester);
    final state = await _state(_fakeBackend());
    await tester.pumpWidget(AimesisFamilyApp(state: state));
    await state.restore();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'oncologist@demo.aimesis.app');
    await tester.enterText(find.byKey(const Key('password')), 'aimesis-demo');
    await tester.tap(find.byKey(const Key('signIn')));
    await tester.pumpAndSettle();
    expect(state.loggedIn, isFalse);
    expect(find.textContaining('This app is for families'), findsOneWidget);
  });

  testWidgets('one tap logs an episode; all tabs render', (tester) async {
    _phone(tester);
    final state = await _state(_fakeBackend());
    await tester.pumpWidget(AimesisFamilyApp(state: state));
    await state.restore();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casus 1 · teen (demo)'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signIn')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logNausea')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
    // Severity sheet is optional: pick 3.
    await tester.tap(find.byKey(const Key('severity-3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('the care team will see this'), findsOneWidget);
    expect(state.queue.length, 0);

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passport').last);
    await tester.pumpAndSettle();
    expect(find.text('Call the ward if…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pumpAndSettle();
    expect(find.text('Connect another child'), findsOneWidget);
    // let the snackbar timer finish
    await tester.pump(const Duration(seconds: 5));
  });

  test('offline log is queued and sent on the next flush', () async {
    var offline = true;
    final client = MockClient((req) async {
      if (offline) throw http.ClientException('offline');
      return _json({'id': 'ep1', 'patientId': 'PAT-2026-0001', 'type': 'vomiting', 'at': '2026-10-29T10:00:00Z', 'cycleDay': 35, 'loggedBy': 'a', 'loggedByRole': 'parent'});
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = AimesisApi(baseUrl: 'http://test', client: client)..token = 't';
    final service = EpisodeService(api: api, queue: OfflineQueue(prefs));

    final r = await service.logNow('PAT-2026-0001', 'vomiting', severity: 3);
    expect(r.outcome, LogOutcome.savedOffline);
    expect(OfflineQueue(prefs).length, 1);

    offline = false;
    expect(await service.flush(), 0);
  });

  test('cycle day counts from cycle start', () {
    expect(cycleDayFor(DateTime(2026, 10, 29), DateTime(2026, 10, 29, 14)), 1);
    expect(cycleDayFor(DateTime(2026, 10, 29), DateTime(2026, 10, 30, 1)), 2);
    expect(cycleDayFor(DateTime(2026, 10, 29), DateTime(2026, 10, 20)), 1);
    expect(compactDays([1, 2, 3, 5]), '1–3, 5');
  });
}
