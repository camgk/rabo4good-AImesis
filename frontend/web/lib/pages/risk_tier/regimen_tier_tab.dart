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
                          Expanded(
                            child: GovukInsetText(
                              borderColor: GovukColours.brand,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.rule, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 5),
                                SourceLabel(r.source),
                              ]),
                            ),
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
      Text(cap(c.drug), style: const TextStyle(fontWeight: FontWeight.w700)),
      Text('${fmtNum(c.doseMgM2)} mg/m²'),
      Text(formatDays(c.days)),
      isUnknown
          ? const Align(alignment: Alignment.centerLeft, child: GovukTag('Not in UZA v2', colour: GovukTagColour.red, small: true))
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

/// Overall tier: GOV.UK summary-card style box with a brand-tint title bar
/// and the tier tag; the explanation sits beside it as body text.
class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tier = plan.overallTier;
    final accent = tier == null ? cs.outlineVariant : AimesisTheme.tierAccent(tier);
    return Container(
      padding: const EdgeInsets.all(GovukSpacing.s4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: accent, width: GovukLayout.borderWidthWide),
          top: BorderSide(color: cs.outlineVariant),
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Wrap(
        spacing: GovukSpacing.s7,
        runSpacing: GovukSpacing.s3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Overall emetogenicity', style: GovukType.style(context, GovukType.p19, bold: true, color: cs.onSurface)),
            const SizedBox(height: GovukSpacing.s2),
            if (tier != null)
              GovukTag.tier(tier, prefix: true)
            else
              Text('Not classified', style: theme.textTheme.titleLarge),
          ]),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(_explain(plan), style: theme.textTheme.bodyMedium),
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

/// Per-day tiers as a GOV.UK table: day, tier tag, drugs. Colour is never the
/// only signal: the tag carries the tier name.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days});
  final List<DayTier> days;

  @override
  Widget build(BuildContext context) {
    final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
    return GovukTable(
      columns: const [
        GovukTableColumn('Day', width: 90),
        GovukTableColumn('Tier', width: 150),
        GovukTableColumn('Chemotherapy that day'),
      ],
      rows: [
        for (final d in sorted)
          ['Day ${d.day}', Align(alignment: Alignment.topLeft, child: GovukTag.tier(d.tier, small: true)), d.drugs.map(cap).join(' + ')],
      ],
    );
  }
}
