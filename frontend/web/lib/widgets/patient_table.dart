import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import 'common.dart';

/// Dense, clickable patient table used by the worklist and pharmacist queue.
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
      // GOV.UK table: bold sentence-case headers, 1px rules, no card.
      final header = GovukType.style(context, GovukType.p19, bold: true, color: cs.onSurface);
      Widget headerRow() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
            child: Semantics(
              header: true,
              child: Row(children: [
                Expanded(flex: 3, child: Text('Patient', style: header)),
                Expanded(flex: 4, child: Text('Diagnosis and protocol', style: header)),
                if (!narrow) Expanded(flex: 2, child: Text('Cycle', style: header)),
                Expanded(flex: 2, child: Text('Tier', style: header)),
                Expanded(flex: 3, child: Text('Plan status', style: header)),
                const SizedBox(width: 40),
              ]),
            ),
          );
      return Material(
        color: Colors.transparent,
        child: Column(
          children: [
            headerRow(),
            for (var i = 0; i < patients.length; i++) ...[
              _row(context, patients[i], narrow),
              Divider(height: 1, color: cs.outlineVariant),
            ],
          ],
        ),
      );
    });
  }

  Widget _row(BuildContext context, PatientSummary p, bool narrow) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sub = GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant);
    final ageSex = [
      if (p.age != null) '${p.age} y',
      if (p.sex != null && p.sex!.isNotEmpty) p.sex!,
      if (p.language != null) p.language!.toUpperCase(),
    ].join(' · ');
    return GovukFocusRing(
      onTap: () => onOpen(p),
      outline: true,
      semanticLabel: '${actionLabel ?? 'Open patient'} ${p.alias}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.alias,
                            style: GovukType.style(context, GovukType.p19, bold: true, color: GovukColours.link).copyWith(
                              color: Theme.of(context).brightness == Brightness.dark ? GovukColours.darkLink : GovukColours.link,
                              decoration: TextDecoration.underline,
                              decorationColor: Theme.of(context).brightness == Brightness.dark ? GovukColours.darkLink : GovukColours.link,
                            )),
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
                Text(p.diagnosis ?? '—'),
                Text([p.protocol ?? '', if (narrow && p.cycle != null) 'cycle ${p.cycle}'].where((s) => s.isNotEmpty).join(' · '),
                    style: sub, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (!narrow)
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.cycle ?? '—'),
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
              child: Align(alignment: Alignment.centerLeft, child: PlanStatusChip(p.planStatus, dense: true)),
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
