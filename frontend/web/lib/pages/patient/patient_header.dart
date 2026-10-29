import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common.dart';

class PatientHeader extends StatelessWidget {
  const PatientHeader({
    super.key,
    required this.patient,
    required this.plan,
    this.refreshing = false,
    this.onRefresh,
  });
  final Patient patient;
  final Plan plan;
  final bool refreshing;
  final VoidCallback? onRefresh;

  String _n(double? v, String unit, {int decimals = 1}) => v == null ? 'missing' : '${fmtNum(v, decimals: decimals)} $unit';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = patient;
    final sexLabel = switch (p.sex) { 'F' => 'female', 'M' => 'male', _ => p.sex ?? '' };
    final details = <GovukSummaryRow>[
      GovukSummaryRow(key: 'Weight', value: _n(p.weightKg, 'kg')),
      GovukSummaryRow(key: 'Height', value: _n(p.heightCm, 'cm', decimals: 0)),
      GovukSummaryRow(key: 'BSA', value: p.bsaM2 == null ? 'missing' : '${p.bsaM2!.toStringAsFixed(2)} m²'),
      GovukSummaryRow(key: 'Diagnosis', value: p.diagnosis ?? '—'),
      GovukSummaryRow(key: 'Protocol', value: p.protocol ?? '—'),
      GovukSummaryRow(key: 'Cycle', value: [p.cycle ?? '—', if (p.cycleStart != null) 'from ${p.cycleStart}'].join(' · ')),
      GovukSummaryRow(key: 'Active meds', value: p.activeMeds.isEmpty ? 'none' : p.activeMeds.map(cap).join(', ')),
      GovukSummaryRow(key: 'Language', value: (p.language ?? '—').toUpperCase()),
    ];
    final gutter = GovukLayout.isTablet(context) ? GovukSpacing.s6 : GovukSpacing.s3;
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, GovukSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            GovukBackLink(label: 'Back to worklist', onTap: () => context.go('/worklist')),
            const Spacer(),
            refreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Reload patient and plan',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ]),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: GovukSpacing.s3,
            runSpacing: GovukSpacing.s2,
            children: [
              Semantics(
                header: true,
                child: Text(p.alias, style: GovukType.style(context, GovukType.p36, bold: true, color: cs.onSurface)),
              ),
              Text(
                [if (p.age != null) '${p.age} years', sexLabel].where((s) => s.isNotEmpty).join(', '),
                style: GovukType.style(context, GovukType.p24, color: cs.onSurfaceVariant),
              ),
              for (final t in p.tags) TagChip(t),
              if (!plan.refused && plan.overallTier != null) TierBadge(tier: plan.overallTier!),
              PlanStatusChip(plan.status),
            ],
          ),
          const SizedBox(height: GovukSpacing.s2),
          LayoutBuilder(builder: (context, c) {
            // Two summary-list columns on wide screens keep the header short.
            if (c.maxWidth < 900) {
              return GovukDetails(
                summary: 'Patient details',
                child: GovukSummaryList(rows: details),
              );
            }
            final half = (details.length / 2).ceil();
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: GovukSummaryList(rows: details.sublist(0, half), keyWidthFraction: 0.35)),
              const SizedBox(width: GovukSpacing.s6),
              Expanded(child: GovukSummaryList(rows: details.sublist(half), keyWidthFraction: 0.35)),
            ]);
          }),
        ],
      ),
    );
  }
}
