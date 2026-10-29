import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import 'common.dart';

/// Dense, clickable patient table used by the patient list and pharmacist queue.
class PatientTable extends StatelessWidget {
  const PatientTable({super.key, required this.patients, required this.onOpen, this.actionLabel});

  final List<PatientSummary> patients;
  final ValueChanged<PatientSummary> onOpen;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 900;
      final header = TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: cs.onSurfaceVariant);
      Widget headerRow() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(children: [
              Expanded(flex: 3, child: Text('PATIENT', style: header)),
              Expanded(flex: 4, child: Text('DIAGNOSIS · PROTOCOL', style: header)),
              if (!narrow) Expanded(flex: 2, child: Text('CYCLE', style: header)),
              Expanded(flex: 2, child: Text('TIER', style: header)),
              Expanded(flex: 3, child: Text('PLAN STATUS', style: header)),
              const SizedBox(width: 40),
            ]),
          );
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            headerRow(),
            for (var i = 0; i < patients.length; i++) ...[
              if (i > 0) Divider(height: 1, color: cs.outlineVariant),
              _row(context, patients[i], narrow),
            ],
          ],
        ),
      );
    });
  }

  Widget _row(BuildContext context, PatientSummary p, bool narrow) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sub = TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant);
    final ageSex = [
      if (p.age != null) '${p.age} y',
      if (p.sex != null && p.sex!.isNotEmpty) p.sex!,
      if (p.language != null) p.language!.toUpperCase(),
    ].join(' · ');
    return InkWell(
      onTap: () => onOpen(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    p.alias.replaceAll(RegExp(r'[^0-9]'), '').isEmpty
                        ? p.alias.characters.first
                        : p.alias.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 1),
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.alias, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                        for (final t in p.tags) TagChip(t, dense: true),
                      ],
                    ),
                    Text(ageSex, style: sub),
                  ]),
                ),
              ]),
            ),
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.diagnosis ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text([p.protocol ?? '', if (narrow && p.cycle != null) 'cycle ${p.cycle}'].where((s) => s.isNotEmpty).join(' · '),
                    style: sub, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (!narrow)
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.cycle ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (p.cycleStart != null) Text('from ${p.cycleStart}', style: sub),
                ]),
              ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: p.overallTier == null
                    ? Text('—', style: sub)
                    : TierBadge(tier: p.overallTier!, compact: true),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: p.planStatus == null ? Text('No cycle yet', style: sub) : PlanStatusChip(p.planStatus, dense: true),
              ),
            ),
            SizedBox(
              width: 40,
              child: Tooltip(
                message: actionLabel ?? 'Open patient',
                child: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
