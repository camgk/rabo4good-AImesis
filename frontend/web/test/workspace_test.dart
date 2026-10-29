import 'dart:convert';
import 'dart:io';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:aimesis_web/app.dart';
import 'package:aimesis_web/config.dart';
import 'package:aimesis_web/router.dart';
import 'package:aimesis_web/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fixtures generated from backend/mock_api rules_mock (Casus 1, 3, 4).
final Map<String, dynamic> cases =
    jsonDecode(File('test/fixtures/demo_cases.json').readAsStringSync()) as Map<String, dynamic>;

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

MockClient fakeBackend(String role, List<String> calls) {
  final plans = {for (final e in cases.entries) e.key: Map<String, dynamic>.from(e.value['plan'] as Map)};
  return MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    final seg = req.url.pathSegments;
    if (req.url.path == '/auth/login') {
      return _json({
        'token': 'fake-token',
        'account': {
          'id': 'acc-$role',
          'email': '$role@demo.aimesis.app',
          'role': role,
          'displayName': '${role[0].toUpperCase()}${role.substring(1)} (demo)',
          'patientIds': cases.keys.toList(),
        },
      });
    }
    if (req.url.path == '/auth/demo-accounts') return _json([]);
    if (req.url.path == '/patients') {
      return _json([
        for (final e in cases.entries)
          {
            for (final k in ['id', 'alias', 'age', 'sex', 'diagnosis', 'protocol', 'cycle', 'cycleStart', 'language'])
              k: (e.value['patient'] as Map)[k],
            'overallTier': plans[e.key]!['overallTier'],
            'planStatus': plans[e.key]!['status'],
          }
      ]);
    }
    if (seg.length >= 2 && seg[0] == 'patients') {
      final id = seg[1];
      final c = cases[id];
      if (c == null) return _json({'error': 'not found'}, 404);
      if (seg.length == 2) return _json(c['patient'] as Object);
      switch (seg.sublist(2).join('/')) {
        case 'plan':
          return _json(plans[id]!);
        case 'risk-factors':
          return _json(plans[id]!);
        case 'plan/submit':
          plans[id]!['status'] = 'awaiting_pharmacist';
          plans[id]!['signoffs'] = {
            'oncologist': {'by': 'Oncologist (demo)', 'at': '2026-10-29T10:00:00Z'},
            'pharmacist': null,
          };
          return _json(plans[id]!);
        case 'plan/approve':
          plans[id]!['status'] = 'approved';
          return _json(plans[id]!);
        case 'episodes':
          return _json([
            {
              'id': 'ep1',
              'patientId': id,
              'type': 'nausea',
              'severity': 3,
              'at': '2026-10-29T09:00:00Z',
              'cycleDay': 1,
              'loggedBy': 'acc-parent2',
              'loggedByRole': 'parent',
            }
          ]);
        case 'passport':
          return _json((c['passport'] ?? {'patientId': id}) as Object);
      }
    }
    return _json({'error': 'not found'}, 404);
  });
}

Future<AppState> pumpLoggedIn(WidgetTester tester, String role, List<String> calls, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  const config = AppConfig(apiUrl: 'http://fake.local');
  final state = AppState(config: config, api: AimesisApi(baseUrl: config.apiUrl, client: fakeBackend(role, calls)));
  await state.login('$role@demo.aimesis.app', 'aimesis-demo');
  await tester.pumpWidget(AimesisWebApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  for (final size in const [Size(1280, 900), Size(800, 1000)]) {
    testWidgets('all workspace tabs render for every case at ${size.width.toInt()} px', (tester) async {
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await pumpLoggedIn(tester, 'oncologist', calls, size);

      expect(find.text('Worklist'), findsWidgets);
      expect(find.text('Casus 1'), findsOneWidget);

      for (final id in cases.keys) {
        final alias = (cases[id]['patient'] as Map)['alias'] as String;
        await tester.tap(find.text('Worklist').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(alias).first);
        await tester.pumpAndSettle();
        expect(find.text('Overall emetogenicity'.toUpperCase()), findsOneWidget, reason: id);
        for (final tab in WorkspaceTab.values) {
          await tester.tap(find.text(tab.label).last);
          await tester.pumpAndSettle();
          final ex = tester.takeException();
          if (ex != null) {
            // ignore: avoid_print
            print('[$id/${tab.path}] ${ex is FlutterError ? ex.toStringDeep() : ex}');
          }
          expect(ex, isNull, reason: '$id/${tab.path}');
          expect(find.textContaining('Advisory only'), findsWidgets, reason: '$id/${tab.path}');
        }
      }
      expect(calls, contains('GET /patients/casus-4/passport'));
      expect(calls, contains('GET /patients/casus-1/episodes'));
    });
  }

  testWidgets('safety gates show the critical azole interaction for Casus 4', (tester) async {
    addTearDown(tester.view.reset);
    await pumpLoggedIn(tester, 'nurse', [], const Size(1280, 900));
    await tester.tap(find.text('Casus 4 · interactions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety gates').last);
    await tester.pumpAndSettle();
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('Voriconazole + Vincristine'), findsOneWidget);
    expect(find.text('Dexamethasone blocked'), findsOneWidget);
  });

  testWidgets('oncologist submits, then plan shows awaiting pharmacist', (tester) async {
    addTearDown(tester.view.reset);
    final calls = <String>[];
    await pumpLoggedIn(tester, 'oncologist', calls, const Size(1280, 900));
    await tester.tap(find.text('Casus 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign-off').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit for pharmacist check'));
    await tester.tap(find.text('Submit for pharmacist check'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /patients/casus-1/plan/submit'));
    expect(find.text('Awaiting pharmacist'), findsWidgets);
  });

  testWidgets('dose line expands to show the calculation', (tester) async {
    addTearDown(tester.view.reset);
    await pumpLoggedIn(tester, 'pharmacist', [], const Size(1280, 900));
    await tester.tap(find.text('Worklist').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casus 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan & doses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('How was this calculated?').first);
    await tester.pumpAndSettle();
    expect(find.text('FORMULA'), findsOneWidget);
    expect(find.text('Hide calculation'), findsOneWidget);
    expect(find.textContaining('1.52 m² × 5 mg/m²'), findsWidgets);
  });
}
