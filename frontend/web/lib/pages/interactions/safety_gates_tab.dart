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
        Row(children: [
          if (crit > 0)
            Expanded(
              child: Text(
                '$crit critical interaction${crit == 1 ? '' : 's'}: review with the team before the plan is submitted.',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
              ),
            )
          else
            const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/patients/${ws.patientId}/plan'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue to plan & doses'),
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
    final bg = dark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
    final fg = dark ? const Color(0xFFDCFCE7) : const Color(0xFF14532D);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: fg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No interactions found', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Screened against BCFI/CBIP (mock) interaction rules.', style: TextStyle(color: fg, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

/// One interaction, coloured by severity (critical red, warning amber, info blue).
class InteractionCard extends StatelessWidget {
  const InteractionCard({super.key, required this.interaction});
  final Interaction interaction;

  static (Color bg, Color border, Color fg, IconData icon, String label) style(String severity, bool dark) {
    switch (severity) {
      case Severity.critical:
        return dark
            ? (const Color(0xFF450A0A), const Color(0xFFEF4444), const Color(0xFFFECACA), Icons.dangerous_rounded, 'CRITICAL')
            : (const Color(0xFFFEF2F2), const Color(0xFFDC2626), const Color(0xFF7F1D1D), Icons.dangerous_rounded, 'CRITICAL');
      case Severity.warning:
        return dark
            ? (const Color(0xFF451A03), const Color(0xFFF59E0B), const Color(0xFFFDE68A), Icons.warning_amber_rounded, 'WARNING')
            : (const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFF78350F), Icons.warning_amber_rounded, 'WARNING');
      default:
        return dark
            ? (const Color(0xFF172554), const Color(0xFF60A5FA), const Color(0xFFBFDBFE), Icons.info_rounded, 'INFO')
            : (const Color(0xFFEFF6FF), const Color(0xFF2563EB), const Color(0xFF1E3A8A), Icons.info_rounded, 'INFO');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = interaction;
    final (bg, border, fg, icon, label) = style(i.severity, Theme.of(context).brightness == Brightness.dark);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: border, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: border, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(4)),
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              Text(i.drugs.map(cap).join(' + '), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 6),
            Text(i.message, style: TextStyle(color: fg)),
            if (i.alternative != null && i.alternative!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: fg),
                const SizedBox(width: 6),
                Expanded(child: Text(i.alternative!, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
              ]),
            ],
            const SizedBox(height: 6),
            Text(i.source, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }
}

/// Small helper: tier colour swatch (used in other tabs too).
Color tierSwatch(BuildContext context, String tier) => AimesisTheme.tierColor(tier, Theme.of(context).brightness);
