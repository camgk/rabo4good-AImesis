import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
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
                style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('API: ${state.config.apiUrl}  (from ${state.config.source})',
                style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: 'Roles',
          icon: Icons.badge_outlined,
          child: GovukSummaryList(rows: [
            GovukSummaryRow(key: 'Oncologist', value: 'Edits risk factors and submits plans for pharmacist review'),
            GovukSummaryRow(key: 'Nurse specialist', value: 'Edits risk factors and follows up on reported episodes'),
            GovukSummaryRow(key: 'Pharmacist', value: 'Approves or returns submitted plans'),
            GovukSummaryRow(key: 'Parent / patient', value: 'Uses the AImesis Family app (passport, symptom log)'),
          ]),
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
            Align(
              alignment: Alignment.centerLeft,
              child: GovukButton.secondary(
                label: 'Open the worklist',
                icon: Icons.people_alt_outlined,
                onPressed: () => context.go('/worklist'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Design and accessibility',
          icon: Icons.accessibility_new_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bullet(context,
                'Design based on the GOV.UK Design System (MIT licence): layout, type scale, spacing, '
                'focus states and components. AImesis is not a government service and uses its own brand.'),
            _bullet(context, 'Aiming for WCAG 2.2 AA: visible keyboard focus, 44 px touch targets, and status shown in words, not colour alone.'),
          ]),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•', style: GovukType.style(context, GovukType.p19, bold: true, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
