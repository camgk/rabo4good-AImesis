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
    return PageFrame(
      title: 'About AImesis',
      subtitle: 'Clinical decision support for chemotherapy-induced nausea and vomiting (CINV) in children',
      maxWidth: 1000,
      children: [
        SectionCard(
          title: 'What AImesis does',
          icon: Icons.info_outline_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bullet(context,
                'Classifies the emetogenic risk of each chemotherapy day and of the whole regimen, '
                'following the UZA v2 antiemetic policy and comparing it with POGO.'),
            _bullet(context,
                'Proposes antiemetic prophylaxis with weight- and BSA-based doses. Every line shows its formula '
                'and source; doses come from a deterministic rules engine, never from a language model.'),
            _bullet(context,
                'Checks safety gates: dexamethasone restrictions and interactions with active medication.'),
            _bullet(context,
                'Personalises the plan with risk factors and nausea or vomiting reported by the family, '
                'and produces a printable CINV passport in Dutch, French or English.'),
            _bullet(context,
                'Every recommendation is advisory only and needs oncologist and hospital pharmacist sign-off.'),
            const SizedBox(height: 8),
            Text('Prototype · rules labelled with their source',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('API: ${state.config.apiUrl}  (from ${state.config.source})',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Roles',
          icon: Icons.badge_outlined,
          child: Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(5)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _tr('Oncologist', 'Edits risk factors and submits plans for pharmacist review'),
              _tr('Nurse specialist', 'Edits risk factors and follows up on reported episodes'),
              _tr('Pharmacist', 'Approves or returns submitted plans'),
              _tr('Parent / patient', 'Uses the AImesis Family app (passport, symptom log)'),
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
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/patients'),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Open patients'),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  TableRow _tr(String role, String what) {
    return TableRow(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(role, style: const TextStyle(fontWeight: FontWeight.w600))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(what)),
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
