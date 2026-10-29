import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:aimesis_web/app.dart';
import 'package:aimesis_web/config.dart';
import 'package:aimesis_web/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fake backend: just enough of the mock API for the login page.
MockClient fakeBackend() => MockClient((req) async {
      switch (req.url.path) {
        case '/auth/demo-accounts':
          return http.Response(
            jsonEncode([
              {'email': 'oncologist@demo.aimesis.app', 'role': 'oncologist', 'displayName': 'Oncologist (demo)'},
              {'email': 'nurse@demo.aimesis.app', 'role': 'nurse', 'displayName': 'Nurse specialist (demo)'},
              {'email': 'pharmacist@demo.aimesis.app', 'role': 'pharmacist', 'displayName': 'Hospital pharmacist (demo)'},
              {'email': 'parent.casus2@demo.aimesis.app', 'role': 'parent', 'displayName': 'Casus 2 · parent (demo)'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case '/auth/login':
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['email'] == 'parent.casus2@demo.aimesis.app') {
            return http.Response(
              jsonEncode({
                'token': 'fake',
                'account': {
                  'id': 'acc-parent2',
                  'email': body['email'],
                  'role': 'parent',
                  'displayName': 'Casus 2 · parent (demo)',
                  'patientIds': ['casus-2'],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(jsonEncode({'error': 'Invalid credentials'}), 401);
        default:
          return http.Response(jsonEncode({'error': 'not found'}), 404);
      }
    });

AppState fakeState() {
  const config = AppConfig(apiUrl: 'http://fake.local');
  return AppState(config: config, api: AimesisApi(baseUrl: config.apiUrl, client: fakeBackend()));
}

void main() {
  testWidgets('login page shows wordmark, fields and clinician demo accounts', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AimesisWebApp(state: fakeState()));
    await tester.pumpAndSettle();

    expect(find.text('Care team'), findsWidgets);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.text('Oncologist (demo)'), findsOneWidget);
    expect(find.text('Hospital pharmacist (demo)'), findsOneWidget);
    // Family accounts are not offered as quick-picks.
    expect(find.text('Casus 2 · parent (demo)'), findsNothing);
    expect(find.textContaining('Advisory only'), findsWidgets);

    // Quick-pick fills the form.
    await tester.tap(find.text('Nurse specialist (demo)'));
    await tester.pump();
    expect(find.text('nurse@demo.aimesis.app'), findsOneWidget);
  });

  testWidgets('family account is rejected with a friendly message', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AimesisWebApp(state: fakeState()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'parent.casus2@demo.aimesis.app');
    await tester.enterText(find.byKey(const Key('login-password')), 'aimesis-demo');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('This is the care-team app. Families use the AImesis Family app.'), findsOneWidget);
  });
}
