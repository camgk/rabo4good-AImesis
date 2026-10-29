import 'dart:math' as math;

import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? GovukTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('tokens', () {
    test('spacing scale matches GOV.UK', () {
      expect(GovukSpacing.static_, [0, 5, 10, 15, 20, 25, 30, 40, 50, 60]);
      expect(GovukSpacing.responsive(4, 320), 15);
      expect(GovukSpacing.responsive(4, 1024), 20);
    });

    test('type scale: 19px body everywhere, 16px small', () {
      expect(GovukType.p19.size(false), 19);
      expect(GovukType.p19.size(true), 19);
      expect(GovukType.p16.size(false), 16);
      expect(GovukType.p48.size(false), 32);
      expect(GovukType.p48.size(true), 48);
    });

    test('text colours meet WCAG AA (4.5:1) in light and dark', () {
      const white = GovukColours.white;
      for (final c in [
        GovukColours.text,
        GovukColours.secondaryText,
        GovukColours.link,
        GovukColours.linkVisited,
        GovukColours.error,
        GovukColours.success,
        GovukColours.brand,
      ]) {
        expect(contrast(c, white), greaterThanOrEqualTo(4.5), reason: '$c on white');
      }
      expect(contrast(GovukColours.white, GovukColours.brand), greaterThanOrEqualTo(4.5));
      expect(contrast(GovukColours.focusText, GovukColours.focus), greaterThanOrEqualTo(4.5));
      expect(contrast(GovukColours.text, GovukColours.brandTint), greaterThanOrEqualTo(4.5));
      for (final c in [
        GovukColours.darkText,
        GovukColours.darkSecondaryText,
        GovukColours.darkLink,
        GovukColours.darkLinkVisited,
        GovukColours.darkError,
        GovukColours.darkSuccess,
        GovukColours.brandOnDark,
      ]) {
        expect(contrast(c, GovukColours.darkBackground), greaterThanOrEqualTo(4.5), reason: '$c on dark');
        expect(contrast(c, GovukColours.darkSurface), greaterThanOrEqualTo(4.5), reason: '$c on dark surface');
      }
      for (final t in GovukTagColour.values) {
        expect(contrast(t.foreground, t.background), greaterThanOrEqualTo(4.5), reason: 'tag $t');
      }
    });

    test('tier and severity mapping', () {
      expect(GovukMapping.tierTag('minimal'), GovukTagColour.grey);
      expect(GovukMapping.tierTag('low'), GovukTagColour.green);
      expect(GovukMapping.tierTag('moderate'), GovukTagColour.yellow);
      expect(GovukMapping.tierTag('HIGH'), GovukTagColour.red);
      expect(GovukMapping.severityTag('critical'), GovukTagColour.red);
      expect(GovukMapping.severityTag('warning'), GovukTagColour.orange);
      expect(GovukMapping.severityTag('info'), GovukTagColour.blue);
      expect(GovukMapping.patientTag('ALL'), GovukMapping.patientTag('all'));
    });
  });

  group('theme', () {
    test('light and dark build with Arial and the brand primary', () {
      final l = GovukTheme.light();
      final d = GovukTheme.dark(largeScreen: false);
      expect(l.colorScheme.primary, GovukColours.brand);
      expect(l.textTheme.bodyMedium?.fontSize, 19);
      expect(l.textTheme.bodyMedium?.fontFamily, 'Arial');
      expect(d.brightness, Brightness.dark);
      expect(d.textTheme.bodyMedium?.fontSize, 19);
      expect(d.textTheme.headlineMedium?.fontSize, 21);
    });

    testWidgets('Material buttons render under the theme', (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        FilledButton(onPressed: () {}, child: const Text('Save')),
        OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
        TextButton(onPressed: () {}, child: const Text('Link')),
        const TextField(decoration: InputDecoration(labelText: 'Name')),
      ])));
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('GovukButton', () {
    testWidgets('variants render, tap and keyboard activate', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(Column(children: [
        GovukButton(label: 'Save and continue', onPressed: () => taps++),
        GovukButton.secondary(label: 'Cancel', onPressed: () {}),
        GovukButton.warning(label: 'Delete', onPressed: () {}),
        GovukButton.start(label: 'Start now', onPressed: () {}),
        const GovukButton(label: 'Disabled', onPressed: null),
      ])));
      await tester.tap(find.text('Save and continue'));
      expect(taps, 1);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      // Keyboard: Tab to the first button, it shows yellow focus, Enter taps.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusedBox = find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == GovukColours.focus);
      expect(focusedBox, findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('large full-width button meets touch target', (tester) async {
      await tester.pumpWidget(_wrap(GovukButton(label: 'Log nausea', onPressed: () {}, large: true, fullWidth: true)));
      final size = tester.getSize(find.byType(GovukButton));
      expect(size.height, greaterThanOrEqualTo(GovukLayout.touchTargetLarge));
    });
  });

  group('content components', () {
    testWidgets('tag, tier tag and severity tag', (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        const GovukTag('Prototype', colour: GovukTagColour.brand),
        GovukTag.tier('high'),
        GovukTag.tier('moderate', prefix: true),
        GovukTag.severity('critical'),
        const GovukTagList(tags: ['ALL', 'Relapse']),
      ])));
      expect(find.text('Prototype'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Moderate risk'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Relapse'), findsOneWidget);
    });

    testWidgets('summary list, table, inset, warning, panel', (tester) async {
      var changed = false;
      await tester.pumpWidget(_wrap(Column(children: [
        GovukSummaryList(rows: [
          const GovukSummaryRow(key: 'Weight', value: '24 kg'),
          GovukSummaryRow(key: 'BSA', value: '0.92 m²', onAction: () => changed = true),
        ]),
        const GovukTable(
          caption: 'Doses',
          columns: [GovukTableColumn('Drug'), GovukTableColumn('Dose', numeric: true)],
          rows: [
            ['Ondansetron', '4.6 mg'],
          ],
        ),
        const GovukInsetText(text: '5 mg/m² × 0.92 m² = 4.6 mg'),
        const GovukWarningText('Dexamethasone blocked'),
        const GovukPanel(title: 'Plan signed off', body: 'Both sign-offs recorded'),
      ])));
      expect(find.text('24 kg'), findsOneWidget);
      expect(find.text('Ondansetron'), findsOneWidget);
      expect(find.text('Doses'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
      expect(find.bySemanticsLabel('Warning: Dexamethasone blocked'), findsOneWidget);
      expect(find.text('Plan signed off'), findsOneWidget);
      await tester.tap(find.text('Change'));
      expect(changed, isTrue);
    });

    testWidgets('error summary links to field and takes focus', (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(_wrap(Column(children: [
        GovukErrorSummary(errors: [GovukErrorItem('Enter your email address', onTap: node.requestFocus)]),
        GovukTextInput(label: 'Email address', focusNode: node, errorMessage: 'Enter your email address'),
      ])));
      await tester.pump();
      expect(find.text('There is a problem'), findsOneWidget);
      expect(find.text('Enter your email address'), findsNWidgets(2));
      await tester.tap(find.text('Enter your email address').first);
      await tester.pump();
      expect(node.hasFocus, isTrue);
      node.dispose();
    });

    testWidgets('notification banners, details, back link, tabs', (tester) async {
      var back = false;
      var tab = 0;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => Column(children: [
          const GovukNotificationBanner(text: 'Plan recalculated'),
          const GovukNotificationBanner.success(heading: 'Approved'),
          const GovukDetails(summary: 'Where does this come from?', child: Text('UZA v2 p.2')),
          GovukBackLink(onTap: () => back = true),
          GovukTabs(labels: const ['Regimen', 'Doses'], selected: tab, onSelect: (i) => setState(() => tab = i)),
        ]),
      )));
      expect(find.text('Important'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('UZA v2 p.2'), findsNothing);
      await tester.tap(find.text('Where does this come from?'));
      await tester.pump();
      expect(find.text('UZA v2 p.2'), findsOneWidget);
      await tester.tap(find.text('Back'));
      expect(back, isTrue);
      await tester.tap(find.text('Doses'));
      await tester.pump();
      expect(tab, 1);
    });

    testWidgets('radios and checkboxes', (tester) async {
      String? picked;
      var ticks = <String>{};
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => Column(children: [
          GovukRadios<String>(
            legend: 'Route',
            options: const [GovukOption(value: 'iv', label: 'IV'), GovukOption(value: 'po', label: 'Oral')],
            value: picked,
            onChanged: (v) => setState(() => picked = v),
          ),
          GovukCheckboxes<String>(
            legend: 'Risk factors',
            options: const [GovukOption(value: 'prev', label: 'Previous CINV')],
            values: ticks,
            onChanged: (v) => setState(() => ticks = v),
            errorMessage: 'Select a risk factor',
          ),
        ]),
      )));
      await tester.tap(find.text('Oral'));
      await tester.pump();
      expect(picked, 'po');
      await tester.tap(find.text('Previous CINV'));
      await tester.pump();
      expect(ticks, {'prev'});
      expect(find.text('Select a risk factor'), findsOneWidget);
    });

    testWidgets('header, phase banner and footer (no GOV.UK branding)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: GovukTheme.light(),
        home: Scaffold(
          appBar: GovukHeader(serviceName: 'Care team', logo: AimesisBrand.logo(height: 32), onHomeTap: () {}),
          body: const Column(children: [GovukPhaseBanner(), GovukFooter()]),
        ),
      ));
      await tester.pump();
      expect(find.text('Care team'), findsOneWidget);
      expect(find.text('Prototype'), findsOneWidget);
      expect(find.textContaining('GOV.UK Design System'), findsOneWidget);
      expect(find.text('GOV.UK'), findsNothing);
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(_wrap(
        Column(children: [
          GovukButton(label: 'Go', onPressed: () {}),
          const GovukWarningText('Check'),
          const GovukInsetText(text: 'Formula'),
          AimesisBrand.mark(size: 40),
        ]),
        theme: GovukTheme.dark(),
      ));
      await tester.pump();
      expect(find.text('Go'), findsOneWidget);
    });
  });
}
