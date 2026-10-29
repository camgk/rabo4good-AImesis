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

import 'workspace_test.dart' show cases, fakeBackend;

Future<AppState> _pump(WidgetTester tester, String role, {OnboardingStore? store}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const config = AppConfig(apiUrl: 'http://fake.local');
  final state = AppState(
    config: config,
    api: AimesisApi(baseUrl: config.apiUrl, client: fakeBackend(role, [])),
    onboarding: store ?? OnboardingStore(persist: false),
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

void _go(WidgetTester tester, String path) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);

/// Session → processing → review → send, from the start of step 2.
Future<void> _finishCycle(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('onboarding-run-models')));
  expect(find.text('Suggestion ready'), findsOneWidget);
  await _tap(tester, find.byKey(const Key('onboarding-review')));
  await _tap(tester, find.byKey(const Key('onboarding-reviewed')));
  await _tap(tester, find.byKey(const Key('onboarding-send')));
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

  test('records survive a JSON round-trip', () {
    final store = OnboardingStore(persist: false);
    final ref = store.createPatient(createdBy: 'Dr A');
    ref.patient.profile.alias = 'Casus 9';
    ref.cycle.intake.chemo = [const ChemoRow(drug: 'ifosfamide', doseMgM2: 1800, days: [1, 2])];
    final back = PatientRecord.fromJson(ref.patient.toJson());
    expect(back.profile.alias, 'Casus 9');
    expect(back.cycles.single.intake.chemo.single.days, [1, 2]);
  });

  testWidgets('new patient, then a second cycle on the same profile', (tester) async {
    final state = await _pump(tester, 'oncologist');

    await _tap(tester, find.byKey(const Key('new-patient')));
    expect(find.text('Chemotherapy'), findsOneWidget);

    // Step 1 refuses to continue while required fields are empty.
    await _tap(tester, find.byKey(const Key('onboarding-continue')));
    expect(find.text('Required'), findsWidgets);

    await _type(tester, 'field-alias', 'Casus 9');
    await _type(tester, 'field-age', '7');
    await _type(tester, 'field-diagnosis', 'Ewing sarcoma');
    await _type(tester, 'field-weight', '24');
    await _type(tester, 'field-height', '120');
    await _type(tester, 'chemo-drug-0', 'ifosfamide');
    await _type(tester, 'chemo-dose-0', '1800');
    await _type(tester, 'chemo-days-0', '1-5');
    await _tap(tester, find.byKey(const Key('onboarding-continue')));

    // Step 2: no history yet; cannot swallow tablets.
    expect(find.text('Who is here'), findsOneWidget);
    expect(find.text('Previous cycles'), findsNothing);
    await _tap(tester, find.byKey(const Key('session-swallow')));
    await _tap(tester, find.byKey(const Key('onboarding-run-models')));
    expect(find.text('6 of 6 complete'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('onboarding-review')));
    expect(find.text('Oral liquid'), findsWidgets);
    final send = find.byKey(const Key('onboarding-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'needs the reviewed tick first');
    await _tap(tester, find.byKey(const Key('onboarding-reviewed')));
    await _tap(tester, send);

    // Lands on the profile with one cycle.
    expect(find.text('Patient profile · 1 cycle'), findsOneWidget);
    expect(find.textContaining('Approved by Oncologist (demo)'), findsOneWidget);

    // Second cycle: chemo and route carried over, weight must be measured again.
    await _tap(tester, find.byKey(const Key('new-cycle')));
    expect(find.text('Casus 9 · Cycle 2'), findsOneWidget);
    expect(find.text('Last: 24 kg'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ifosfamide'), findsOneWidget);
    expect(find.byKey(const Key('field-alias')), findsNothing, reason: 'profile is not re-entered');
    await _tap(tester, find.byKey(const Key('onboarding-continue')));
    expect(find.text('Who is here'), findsNothing);
    await _type(tester, 'field-weight', '25');
    await _type(tester, 'field-height', '121');
    await _tap(tester, find.byKey(const Key('onboarding-continue')));

    expect(find.text('Previous cycles'), findsOneWidget);
    expect(find.text('How did the last cycle go?'), findsOneWidget);
    await _finishCycle(tester);

    expect(find.text('Patient profile · 2 cycles'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('crumb-Patients')));
    expect(find.text('Casus 9'), findsOneWidget, reason: 'new patients are in the main table');
    final p = state.onboarding.localPatients.single;
    expect(p.cycles.map((c) => c.intake.weightKg), [24, 25]);
    expect(p.cycles.last.session.canSwallowTablets, isFalse);
    expect(state.onboarding.sent, hasLength(2));
  });

  testWidgets('existing patient: new cycle builds on the record history', (tester) async {
    final state = await _pump(tester, 'oncologist');
    final id = cases.keys.first;
    final api = cases[id]['patient'] as Map;
    final drug = ((api['chemo'] as List).first as Map)['drug'] as String;

    _go(tester, '/patients/$id/cycles');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('current-cycle-tile')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('new-cycle')));
    expect(find.widgetWithText(TextFormField, drug), findsOneWidget);
    await _type(tester, 'field-weight', '30');
    await _type(tester, 'field-height', '130');
    await _tap(tester, find.byKey(const Key('onboarding-continue')));
    expect(find.text('Previous cycles'), findsOneWidget);
    await _finishCycle(tester);

    final rec = state.onboarding.patient(id)!;
    expect(rec.isLocal, isFalse);
    expect(rec.imported, isNotEmpty);
    expect(rec.cycles.single.isSent, isTrue);
    expect(find.text('Patient profile · ${rec.cycleCount} cycles'), findsOneWidget);
  });

  testWidgets('clicking a patient opens the profile; the plan is one level down', (tester) async {
    await _pump(tester, 'oncologist');
    final id = cases.keys.first;
    final alias = (cases[id]['patient'] as Map)['alias'] as String;
    await _tap(tester, find.text(alias).first);
    expect(find.textContaining('Patient profile'), findsOneWidget);
    await _tap(tester, find.text('Open plan'));
    expect(find.text('Overall emetogenicity'.toUpperCase()), findsOneWidget);
    await _tap(tester, find.byKey(Key('crumb-$alias')));
    expect(find.textContaining('Patient profile'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('crumb-Patients')));
    expect(find.text('Patients starting or in a chemotherapy cycle'), findsOneWidget);
  });

  testWidgets('pharmacist sees sent cycles and cannot start one', (tester) async {
    final store = OnboardingStore(persist: false);
    final ref = store.createPatient(createdBy: 'Oncologist (demo)');
    ref.patient.profile.alias = 'Casus 10';
    ref.cycle.stage = OnboardingStage.sent;
    store.save(ref.patient, ref.cycle);

    await _pump(tester, 'pharmacist', store: store);
    expect(find.byKey(const Key('new-patient')), findsNothing);
    _go(tester, '/pharmacist');
    await tester.pumpAndSettle();
    expect(find.text('Cycles from onboarding (1)'), findsOneWidget);
    expect(find.text('Casus 10 · Cycle 1'), findsOneWidget);
  });
}
