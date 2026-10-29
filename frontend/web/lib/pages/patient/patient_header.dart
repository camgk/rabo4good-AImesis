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
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to worklist',
                onPressed: () => context.go('/worklist'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(p.alias, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [if (p.age != null) '${p.age} years', sexLabel].where((s) => s.isNotEmpty).join(', '),
                      style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outline),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Demo data',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (!plan.refused && plan.overallTier != null) ...[
                TierBadge(tier: plan.overallTier!),
                const SizedBox(width: 10),
              ],
              PlanStatusChip(plan.status),
              const SizedBox(width: 4),
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
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Wrap(
              spacing: 28,
              runSpacing: 10,
              children: [
                KeyValue('Weight', _n(p.weightKg, 'kg')),
                KeyValue('Height', _n(p.heightCm, 'cm', decimals: 0)),
                KeyValue('BSA', p.bsaM2 == null ? 'missing' : '${p.bsaM2!.toStringAsFixed(2)} m²'),
                KeyValue('Diagnosis', p.diagnosis ?? '—'),
                KeyValue('Protocol', p.protocol ?? '—'),
                KeyValue('Cycle', [p.cycle ?? '—', if (p.cycleStart != null) 'from ${p.cycleStart}'].join(' · ')),
                KeyValue('Active meds', p.activeMeds.isEmpty ? 'none' : p.activeMeds.map(cap).join(', ')),
                KeyValue('Language', (p.language ?? '—').toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
