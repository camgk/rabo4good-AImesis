import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';

/// Story 6 — safety gates shown BEFORE the plan: dexamethasone block and
/// drug–drug interactions.
class SafetyGatesTab extends StatelessWidget {
  const SafetyGatesTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  Widget build(BuildContext context) {
    final plan = ws.plan!;
    final patient = ws.patient!;
    final interactions = plan.interactionsBySeverity;
    final crit = interactions.where((i) => i.isCritical).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Dexamethasone gate',
          subtitle: 'Checked before any dose is proposed',
          icon: Icons.do_not_disturb_on_outlined,
          story: 'Story 3',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DexStatusBanner(
              blocked: plan.dexamethasone.blocked,
              reason: plan.dexamethasone.reason,
              source: plan.dexamethasone.source.isEmpty ? null : plan.dexamethasone.source,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Drug interactions & contraindications',
          subtitle: 'Active meds (${patient.activeMeds.isEmpty ? 'none' : patient.activeMeds.map(cap).join(', ')})'
              ' × chemotherapy × proposed antiemetics',
          icon: Icons.shield_outlined,
          story: 'Story 6',
          child: interactions.isEmpty
              ? const _NoInteractions()
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final i in interactions) ...[
                    InteractionCard(interaction: i),
                    const SizedBox(height: 10),
                  ],
                ]),
        ),
        const SizedBox(height: 16),
        if (crit > 0)
          GovukWarningText(
            '$crit critical interaction${crit == 1 ? '' : 's'}: review with the team before the plan is submitted.',
          ),
        const SizedBox(height: GovukSpacing.s3),
        GovukButtonGroup(children: [
          GovukButton(
            label: 'Continue to plan & doses',
            onPressed: () => context.go('/patients/${ws.patientId}/plan'),
          ),
        ]),
      ],
    );
  }
}

class _NoInteractions extends StatelessWidget {
  const _NoInteractions();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GovukInsetText(
      borderColor: dark ? GovukColours.darkSuccess : GovukColours.success,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('No interactions found', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('Screened against BCFI/CBIP (mock) interaction rules.',
            style: GovukType.style(context, GovukType.p16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// One interaction. GOV.UK pattern: severity tag (critical red, warning
/// orange, info blue) with a matching 5px left border; critical ones use
/// warning text. Severity is always written, never colour alone.
class InteractionCard extends StatelessWidget {
  const InteractionCard({super.key, required this.interaction});
  final Interaction interaction;

  static (Color bg, Color border, Color fg, IconData icon, String label) style(String severity, bool dark) {
    final tag = GovukMapping.severityTag(severity);
    final icon = switch (severity) {
      Severity.critical => Icons.dangerous_rounded,
      Severity.warning => Icons.warning_amber_rounded,
      _ => Icons.info_rounded,
    };
    final border = switch (severity) {
      Severity.critical => GovukColours.red,
      Severity.warning => GovukColours.orange,
      _ => GovukColours.blue,
    };
    return (tag.background, border, tag.foreground, icon, GovukMapping.severityLabel(severity));
  }

  @override
  Widget build(BuildContext context) {
    final i = interaction;
    final cs = Theme.of(context).colorScheme;
    final (_, border, _, _, label) = style(i.severity, Theme.of(context).brightness == Brightness.dark);
    final drugs = i.drugs.map(cap).join(' + ');
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: border, width: GovukLayout.borderWidthWide),
          top: BorderSide(color: cs.outlineVariant),
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.all(GovukSpacing.s3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          GovukTag(label, colour: GovukMapping.severityTag(i.severity), small: true, semanticLabel: 'Severity: $label'),
          Text(drugs, style: GovukType.style(context, GovukType.p19, bold: true, color: cs.onSurface)),
        ]),
        const SizedBox(height: GovukSpacing.s2),
        if (i.isCritical)
          GovukWarningText(i.message)
        else
          Text(i.message, style: Theme.of(context).textTheme.bodyMedium),
        if (i.alternative != null && i.alternative!.isNotEmpty) ...[
          const SizedBox(height: GovukSpacing.s2),
          GovukInsetText(
            borderColor: GovukColours.brand,
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Alternative: ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: i.alternative!),
            ])),
          ),
        ],
        const SizedBox(height: GovukSpacing.s2),
        SourceLabel(i.source),
      ]),
    );
  }
}

/// Small helper: tier colour swatch (used in other tabs too).
Color tierSwatch(BuildContext context, String tier) => AimesisTheme.tierColor(tier, Theme.of(context).brightness);
