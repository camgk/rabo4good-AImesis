import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';
import '../../widgets/refusal_card.dart';

/// Story 1 — emetogenicity classification.
class RegimenTierTab extends StatelessWidget {
  const RegimenTierTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  Widget build(BuildContext context) {
    final patient = ws.patient!;
    final plan = ws.plan!;
    final tiers = {for (final t in plan.drugTiers) t.drug.toLowerCase(): t};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.refused) ...[
          RefusalCard(plan: plan, compact: true),
          const SizedBox(height: 16),
        ],
        _OverallCard(plan: plan),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Chemotherapy regimen',
          subtitle: '${patient.protocol ?? ''} · cycle ${patient.cycle ?? '—'}',
          icon: Icons.science_outlined,
          story: 'Story 1',
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
          child: DenseTable(
            columns: const [
              DenseColumn('Drug', flex: 3),
              DenseColumn('Dose', flex: 2),
              DenseColumn('Days', flex: 2),
              DenseColumn('Tier', flex: 2),
              DenseColumn('Rule · source', flex: 6),
            ],
            rows: [
              for (final c in patient.chemo)
                _chemoRow(context, c, tiers[c.drug.toLowerCase()], plan.unknownDrugs),
            ],
            empty: const EmptyView(icon: Icons.science_outlined, title: 'No chemotherapy on this cycle'),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Per-day emetogenicity',
          subtitle: 'Highest tier per chemo day, after combination rules',
          icon: Icons.calendar_view_week_outlined,
          child: plan.dayTiers.isEmpty
              ? const EmptyView(icon: Icons.calendar_today_outlined, title: 'No chemo days computed')
              : _DayStrip(days: plan.dayTiers),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Combination rules applied',
          icon: Icons.merge_type_rounded,
          child: plan.combinationRules.isEmpty
              ? Text('No combination rule raised the tier. Overall = highest single-drug tier.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in plan.combinationRules)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.arrow_upward_rounded, size: 18, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.rule, style: const TextStyle(fontWeight: FontWeight.w600)),
                              SourceLabel(r.source),
                            ]),
                          ),
                        ]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _chemoRow(BuildContext context, ChemoRow c, DrugTier? t, List<String> unknown) {
    final isUnknown = unknown.map((e) => e.toLowerCase()).contains(c.drug.toLowerCase()) || t == null;
    return [
      Text(cap(c.drug), style: const TextStyle(fontWeight: FontWeight.w600)),
      Text('${fmtNum(c.doseMgM2)} mg/m²'),
      Text(formatDays(c.days)),
      isUnknown
          ? Text('Not in UZA v2', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))
          : Align(alignment: Alignment.centerLeft, child: TierBadge(tier: t.tier, compact: true)),
      isUnknown
          ? const Text('Unknown drug — refuse rather than guess')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.rule),
              SourceLabel(t.source),
            ]),
    ];
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tier = plan.overallTier;
    final b = theme.brightness;
    final accent = tier == null ? cs.outline : AimesisTheme.tierColor(tier, b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), cs.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('OVERALL EMETOGENICITY',
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (tier != null)
              Transform.scale(scale: 1.35, alignment: Alignment.centerLeft, child: TierBadge(tier: tier))
            else
              Text('Not classified', style: theme.textTheme.titleLarge),
          ]),
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              _explain(plan),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _explain(Plan p) {
    if (p.overallTier == null) return 'No tier could be computed.';
    final drivers = p.drugTiers.where((d) => d.tier == p.overallTier).map((d) => cap(d.drug)).toList();
    final parts = <String>[];
    if (drivers.isNotEmpty) {
      parts.add('Highest single-drug tier: ${drivers.join(', ')} (${Tier.label(p.overallTier)}).');
    }
    if (p.combinationRules.isNotEmpty) {
      parts.add('Raised by ${p.combinationRules.length} combination rule${p.combinationRules.length == 1 ? '' : 's'}.');
    }
    parts.add('Antiemetic regimen follows the ${Tier.label(p.overallTier).toLowerCase()}-tier scheme of UZA v2.');
    return parts.join(' ');
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days});
  final List<DayTier> days;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in sorted)
            Container(
              width: 150,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AimesisTheme.tierColor(d.tier, b),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Day ${d.day}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AimesisTheme.onTierColor(d.tier, b))),
                Text(Tier.label(d.tier),
                    style: TextStyle(fontWeight: FontWeight.w600, color: AimesisTheme.onTierColor(d.tier, b))),
                const SizedBox(height: 6),
                Text(d.drugs.map(cap).join(' + '),
                    style: TextStyle(fontSize: 12, color: AimesisTheme.onTierColor(d.tier, b))),
              ]),
            ),
        ],
      ),
    );
  }
}
