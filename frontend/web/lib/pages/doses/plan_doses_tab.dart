import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:go_router/go_router.dart';

import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';
import '../../widgets/refusal_card.dart';

/// Stories 2 & 3 — antiemetic plan with doses, formula, steps and source.
class PlanDosesTab extends StatelessWidget {
  const PlanDosesTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  Widget build(BuildContext context) {
    final plan = ws.plan!;
    final patient = ws.patient!;
    if (plan.refused) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [RefusalCard(plan: plan)]);
    }
    final crit = plan.interactions.where((i) => i.isCritical).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (crit.isNotEmpty) ...[
          _GateReminder(
            text: '${crit.length} critical interaction${crit.length == 1 ? '' : 's'} '
                '(${crit.map((i) => i.drugs.map(cap).join(' + ')).join('; ')}). Review safety gates first.',
            onTap: () => context.go('/patients/${ws.patientId}/safety'),
          ),
          const SizedBox(height: 12),
        ],
        if (plan.dexamethasone.blocked) ...[
          DexStatusBanner(
            blocked: true,
            reason: plan.dexamethasone.reason,
            source: plan.dexamethasone.source.isEmpty ? null : plan.dexamethasone.source,
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          title: 'Antiemetic prophylaxis',
          subtitle: 'BSA ${patient.bsaM2?.toStringAsFixed(2) ?? '?'} m² · '
              '${patient.weightKg != null ? fmtNum(patient.weightKg!) : '?'} kg · ${patient.age ?? '?'} y · '
              'route ${Route.label(patient.riskFactors.preferredRoute).toLowerCase()}',
          icon: Icons.medication_liquid_outlined,
          story: 'Story 2',
          trailing: plan.overallTier == null ? null : TierBadge(tier: plan.overallTier!, compact: true),
          padding: const EdgeInsets.only(bottom: 4),
          child: plan.antiemetics.isEmpty
              ? const EmptyView(
                  icon: Icons.medication_outlined,
                  title: 'No prophylaxis for this tier',
                  message: 'Minimal emetogenic risk: breakthrough medication only.',
                )
              : DoseTable(lines: plan.antiemetics),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final a = _stepUps(context, plan);
          final b = _alternatives(context, plan);
          if (c.maxWidth >= 1000) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 16),
              Expanded(child: b),
            ]);
          }
          return Column(children: [a, const SizedBox(height: 16), b]);
        }),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Breakthrough',
          subtitle: 'If nausea or vomiting despite prophylaxis',
          icon: Icons.emergency_outlined,
          story: 'Story 3',
          padding: const EdgeInsets.only(bottom: 4),
          child: plan.breakthrough.isEmpty
              ? const EmptyView(icon: Icons.emergency_outlined, title: 'No breakthrough medication proposed')
              : DoseTable(lines: plan.breakthrough, showDays: false),
        ),
      ],
    );
  }

  Widget _stepUps(BuildContext context, Plan plan) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Step-ups',
      subtitle: 'From previous cycles and the companion log',
      icon: Icons.trending_up_rounded,
      story: 'Story 3',
      child: plan.stepUps.isEmpty
          ? Text('No step-up needed: no prior nausea recorded.', style: TextStyle(color: cs.onSurfaceVariant))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in plan.stepUps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.north_east_rounded, size: 18, color: cs.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (s.reason.isNotEmpty) Text(s.reason),
                        SourceLabel(s.source),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Widget _alternatives(BuildContext context, Plan plan) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Alternatives',
      subtitle: 'Clinician options — not applied automatically',
      icon: Icons.alt_route_rounded,
      child: plan.alternatives.isEmpty
          ? Text('No alternatives suggested for this plan.', style: TextStyle(color: cs.onSurfaceVariant))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final a in plan.alternatives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.radio_button_unchecked_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (a.detail.isNotEmpty) Text(a.detail),
                        SourceLabel(a.source),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class _GateReminder extends StatelessWidget {
  const _GateReminder({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.dangerous_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600))),
            Text('Open safety gates', style: TextStyle(color: cs.onErrorContainer, decoration: TextDecoration.underline)),
          ]),
        ),
      ),
    );
  }
}

/// Dose table with an expandable "How was this calculated?" row per line.
class DoseTable extends StatefulWidget {
  const DoseTable({super.key, required this.lines, this.showDays = true});
  final List<AntiemeticLine> lines;
  final bool showDays;

  @override
  State<DoseTable> createState() => _DoseTableState();
}

class _DoseTableState extends State<DoseTable> {
  final Set<int> _open = {};

  bool _narrow = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _narrow = c.maxWidth < 900;
      return _table(context);
    });
  }

  Widget _table(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final header = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: cs.onSurfaceVariant);
    final cols = <(String, int)>[
      ('DRUG', 3),
      ('DOSE', 2),
      ('FREQUENCY', 2),
      ('ROUTE', 2),
      if (widget.showDays) ('DAYS', 2),
      ('', _narrow ? 2 : 3),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(children: [for (final c in cols) Expanded(flex: c.$2, child: Text(c.$1, style: header))]),
        ),
        for (var i = 0; i < widget.lines.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          _row(context, i, widget.lines[i]),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, int i, AntiemeticLine l) {
    final cs = Theme.of(context).colorScheme;
    final open = _open.contains(i);
    final mock = l.notes.any((n) => n.toLowerCase().contains('mock dose')) || l.source.toLowerCase().contains('mock dose');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cap(l.drug), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                if (mock)
                  Text('indicative dose', style: TextStyle(fontSize: 11.5, color: cs.tertiary, fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              flex: 2,
              child: Text(l.doseMg == null ? '—' : '${fmtNum(l.doseMg!)} ${l.unit}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: cs.primary)),
            ),
            Expanded(flex: 2, child: Text(l.frequency)),
            Expanded(flex: 2, child: Text(Route.label(l.route))),
            if (widget.showDays) Expanded(flex: 2, child: Text(formatDays(l.days))),
            Expanded(
              flex: _narrow ? 2 : 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => open ? _open.remove(i) : _open.add(i)),
                  icon: Icon(open ? Icons.expand_less_rounded : Icons.calculate_outlined, size: 18),
                  label: Text(open
                      ? (_narrow ? 'Hide' : 'Hide calculation')
                      : (_narrow ? 'How?' : 'How was this calculated?')),
                ),
              ),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: open ? _Calculation(line: l) : const SizedBox(width: double.infinity),
      ),
      if (!open)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Flexible(
              child: Text(l.formula,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            Flexible(child: SourceLabel(l.source)),
          ]),
        ),
    ]);
  }
}

class _Calculation extends StatelessWidget {
  const _Calculation({required this.line});
  final AntiemeticLine line;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: cs.onSurface);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FORMULA', style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        SelectableText(line.formula.isEmpty ? '—' : line.formula, style: mono.copyWith(fontWeight: FontWeight.w600)),
        if (line.steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('STEPS', style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          for (var i = 0; i < line.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text('${i + 1}.', style: mono.copyWith(color: cs.onSurfaceVariant))),
                Expanded(child: SelectableText(line.steps[i], style: mono)),
              ]),
            ),
        ],
        if (line.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('NOTES', style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          for (final n in line.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.sticky_note_2_outlined, size: 15, color: cs.tertiary),
                const SizedBox(width: 6),
                Expanded(child: Text(n)),
              ]),
            ),
        ],
        const SizedBox(height: 10),
        SourceLabel(line.source),
      ]),
    );
  }
}
