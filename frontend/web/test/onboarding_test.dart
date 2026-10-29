import 'package:aimesis_client/aimesis_client.dart';
import 'package:aimesis_web/app.dart';
import 'package:aimesis_web/config.dart';
import 'package:aimesis_web/onboarding/onboarding_models.dart';
import 'package:aimesis_web/onboarding/onboarding_store.dart';
import 'package:aimesis_web/onboarding/suggestion_engine.dart';
import 'package:aimesis_web/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'workspace_test.dart' show fakeBackend;

Future<AppState> _pump(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const config = AppConfig(apiUrl: 'http://fake.local');
  final state = AppState(
    config: config,
    api: AimesisApi(baseUrl: config.apiUrl, client: fakeBackend(role, [])),
    onboarding: OnboardingStore(persist: false),
    suggestionEngine: PlaceholderSuggestionEngine(stepDelay: Duration.zero),
  );
  await state.login('$role@demo.aimesis.app', 'aimesis-demo');
  await tester.pumpWidget(AimesisWebApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

void main() {
  test('parseDays and daysText round-trip', () {
    expect(parseDays('1-3, 8'), [1, 2, 3, 8]);
    expect(parseDays('1–3'), [1, 2, 3]);
    expect(parseDays('2 1'), [1, 2]);
    expect(parseDays('x'), isNull);
    expect(parseDays(''), isNull);
    expect(daysText([1, 2, 3, 8, 15, 16]), '1–3, 8, 15–16');
  });

  testWidgets('oncologist onboards a patient through to the pharmacist', (tester) async {
    final state = await _pump(tester, 'oncologist');

    await _tap(tester, find.byKey(const Key('new-patient')));
    expect(find.text('Chemotherapy'), findsOneWidget);

    // Step 1 refuses to continue while required fields are empty.
    await _tap(tester, find.byKey(const Key('onboarding-continue')));
    expect(find.text('Required'), findsWidgets);
    expect(find.text('Who is here'), findsNothing);

    await _type(tester, 'field-alias', 'Casus 9');
    await _type(tester, 'field-age', '7');
    await _type(tester, 'field-weight', '24');
    await _type(tester, 'field-height', '120');
    await _type(tester, 'field-diagnosis', 'Ewing sarcoma');
    await _type(tester, 'chemo-drug-0', 'ifosfamide');
    await _type(tester, 'chemo-dose-0', '1800');
    await _type(tester, 'chemo-days-0', '1-5');
    await _tap(tester, find.byKey(const Key('onboarding-continue')));

    // Step 2: patient session.
    expect(find.text('Who is here'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('session-swallow')));
    await _tap(tester, find.byKey(const Key('onboarding-run-models')));

    // Step 3: processing finishes.
    expect(find.text('Suggestion ready'), findsOneWidget);
    expect(find.text('6 of 6 complete'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('onboarding-review')));

    // Step 4: review. Cannot swallow tablets → liquid in the suggestion.
    expect(find.text('Suggested antiemetic plan'), findsOneWidget);
    expect(find.text('Oral liquid'), findsWidgets);
    final send = find.byKey(const Key('onboarding-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'needs the reviewed tick first');
    await _tap(tester, find.byKey(const Key('onboarding-reviewed')));
    await _tap(tester, send);

    // Back on Patients with the onboarded patient marked as sent.
    expect(find.text('Onboarding (1)'), findsOneWidget);
    expect(find.text('Casus 9'), findsOneWidget);
    expect(find.text('Sent to pharmacist'), findsOneWidget);
    expect(state.onboarding.sent.single.intake.chemo.single.days, [1, 2, 3, 4, 5]);
    expect(state.onboarding.sent.single.approvedBy, 'Oncologist (demo)');
  });

  testWidgets('pharmacist sees sent onboarding patients and cannot start one', (tester) async {
    final store = OnboardingStore(persist: false);
    final d = store.create(createdBy: 'Oncologist (demo)')
      ..intake.alias = 'Casus 10'
      ..stage = OnboardingStage.sent;
    store.save(d);

    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const config = AppConfig(apiUrl: 'http://fake.local');
    final state = AppState(
      config: config,
      api: AimesisApi(baseUrl: config.apiUrl, client: fakeBackend('pharmacist', [])),
      onboarding: store,
    );
    await state.login('pharmacist@demo.aimesis.app', 'aimesis-demo');
    await tester.pumpWidget(AimesisWebApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-patient')), findsNothing);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/pharmacist');
    await tester.pumpAndSettle();
    expect(find.text('New patients from onboarding (1)'), findsOneWidget);
    expect(find.text('Casus 10'), findsOneWidget);
  });
}
