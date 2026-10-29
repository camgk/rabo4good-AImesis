import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

/// "Refuse rather than guess": shown when the rules engine refused a plan.
class RefusalCard extends StatelessWidget {
  const RefusalCard({super.key, required this.plan, this.compact = false});
  final Plan plan;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reasons = [
      ...plan.refusalReasons,
      for (final d in plan.unknownDrugs)
        if (!plan.refusalReasons.any((r) => r.toLowerCase().contains(d.toLowerCase()))) 'Drug not in UZA v2: $d',
    ];
    // GOV.UK error-summary pattern: red 5px border, "There is a problem"
    // style heading, then the list of what is missing.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? GovukSpacing.s3 : GovukSpacing.s4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.error, width: GovukLayout.borderWidth),
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text('No doses calculated — missing or unsupported input',
                style: GovukType.style(context, GovukType.p24, bold: true, color: cs.onSurface)),
          ),
          const SizedBox(height: GovukSpacing.s3),
          Text('AImesis refuses rather than guesses. Resolve the items below, then recalculate.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: GovukSpacing.s3),
          for (final r in reasons.isEmpty ? ['Plan refused by the rules engine'] : reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: GovukType.style(context, GovukType.p19, bold: true, color: cs.error)),
                Expanded(child: Text(r, style: GovukType.style(context, GovukType.p19, bold: true, color: cs.error))),
              ]),
            ),
        ]),
      ),
    );
  }
}
