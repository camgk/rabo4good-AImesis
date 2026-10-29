import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyMedium;
    return PageFrame(
      title: 'About this demo',
      subtitle: 'AImesis · Solve with Google: Hacking for Good 2026 · use case 3 (BSPHO / UZA)',
      maxWidth: 1000,
      children: [
        SectionCard(
          title: 'What is real and what is mock',
          icon: Icons.science_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bullet(context, 'Patients are fictional demo cases (Casus 1–4). No real patient data anywhere.'),
            _bullet(context,
                'Tiers, doses, dexamethasone gate, interactions and the POGO comparison come from a deterministic '
                'mock rules engine ("UZA v2 (mock rules)"). No language model calculates any dose.'),
            _bullet(context, 'Interaction messages cite "BCFI/CBIP (mock)". Breakthrough doses are labelled "mock dose".'),
            _bullet(context,
                'The live ADK agent over AG-UI / A2UI is stubbed in this build; the app talks to the demo REST API.'),
            _bullet(context, 'Every screen is advisory only and needs oncologist + pharmacist sign-off.'),
            const SizedBox(height: 8),
            Text('API: ${state.config.apiUrl}  (from ${state.config.source})',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Demo accounts',
          subtitle: 'Password for every account: aimesis-demo',
          icon: Icons.badge_outlined,
          child: Table(
            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(4)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _tr(context, 'oncologist@demo.aimesis.app', 'Oncologist', 'Edits risk factors, submits plans', header: false),
              _tr(context, 'nurse@demo.aimesis.app', 'Nurse specialist', 'Edits risk factors, reads everything'),
              _tr(context, 'pharmacist@demo.aimesis.app', 'Pharmacist', 'Approves or returns submitted plans'),
              _tr(context, 'parent.casus2@demo.aimesis.app', 'Parent', 'Family app only (rejected here)'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'User stories → screens',
          icon: Icons.map_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final t in WorkspaceTab.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(t.icon, color: cs.primary),
                title: Text(t.label),
                trailing: StoryTag(t.story),
              ),
            const SizedBox(height: 8),
            Text('Suggested demo run: Casus 1 → 2 → 3, then Casus 4 for interactions.', style: body),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/patients/casus-1/regimen'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start with Casus 1'),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  TableRow _tr(BuildContext context, String a, String b, String c, {bool header = false}) {
    return TableRow(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SelectableText(a, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(c)),
    ]);
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.circle, size: 6, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
