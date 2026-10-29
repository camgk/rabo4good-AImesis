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
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error, width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.block_rounded, color: cs.onErrorContainer, size: compact ? 28 : 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No doses calculated — missing or unsupported input',
                style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                    ?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('AImesis refuses rather than guesses. Resolve the items below, then recalculate.',
                style: TextStyle(color: cs.onErrorContainer)),
            const SizedBox(height: 10),
            for (final r in reasons.isEmpty ? ['Plan refused by the rules engine'] : reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.close_rounded, size: 18, color: cs.onErrorContainer),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(r,
                          style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600, fontSize: compact ? 14 : 16))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
