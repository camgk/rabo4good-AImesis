import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? AimesisTheme.light(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('TierBadge shows the tier label', (tester) async {
    await tester.pumpWidget(_wrap(const TierBadge(tier: 'high')));
    expect(find.text('HIGH'), findsOneWidget);

    await tester.pumpWidget(_wrap(const TierBadge(tier: 'moderate', compact: true)));
    expect(find.text('Moderate'), findsOneWidget);
  });

  testWidgets('TierBadge renders in dark theme and for unknown tiers', (tester) async {
    await tester.pumpWidget(_wrap(const TierBadge(tier: 'whatever'), theme: AimesisTheme.dark()));
    expect(find.text('UNKNOWN'), findsOneWidget);
  });

  testWidgets('AdvisoryBanner defaults to the advisory text', (tester) async {
    await tester.pumpWidget(_wrap(const AdvisoryBanner()));
    expect(find.text(AimesisTheme.advisoryText), findsOneWidget);
  });

  testWidgets('DexStatusBanner shows block reason', (tester) async {
    await tester.pumpWidget(
        _wrap(const DexStatusBanner(blocked: true, reason: 'GEEN dexamethasone bij ALL (UZA v2)')));
    expect(find.text('Dexamethasone blocked'), findsOneWidget);
    expect(find.text('GEEN dexamethasone bij ALL (UZA v2)'), findsOneWidget);
  });

  test('tier colours differ per tier and theme', () {
    final tiers = ['minimal', 'low', 'moderate', 'high'];
    for (final b in Brightness.values) {
      expect(tiers.map((t) => AimesisTheme.tierColor(t, b)).toSet().length, 4);
    }
    expect(AimesisCatalog.components, contains('TierBadge'));
  });
}
