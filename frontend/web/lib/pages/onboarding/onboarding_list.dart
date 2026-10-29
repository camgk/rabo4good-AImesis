import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import 'onboarding_page.dart';

/// Bordered card holding rows separated by dividers.
class _ListCard extends StatelessWidget {
  const _ListCard(this.rows);
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          rows[i],
        ],
      ]),
    );
  }
}

/// Cycles going through (or done with) the flow: Patients page, pharmacist queue.
class CycleList extends StatelessWidget {
  const CycleList({super.key, required this.cycles, this.allowDiscard = false});

  final List<CycleRef> cycles;
  final bool allowDiscard;

  @override
  Widget build(BuildContext context) => _ListCard([for (final r in cycles) _row(context, r)]);

  Widget _row(BuildContext context, CycleRef ref) {
    final cs = Theme.of(context).colorScheme;
    final p = ref.patient, c = ref.cycle;
    final when = c.isSent && c.approvedAt != null ? c.approvedAt! : c.updatedAt;
    final details = [
      if (p.profile.diagnosis.isNotEmpty) p.profile.diagnosis,
      if (c.intake.protocol.isNotEmpty) c.intake.protocol,
      '${c.isSent ? 'Sent' : 'Updated'} ${DateFormat('d MMM, HH:mm').format(when)}',
    ].join(' · ');
    void open() => context.go(OnboardingPage.path(c.id, c.stage));
    return ListTile(
      key: Key('cycle-row-${c.id}'),
      onTap: open,
      leading: CircleAvatar(
        backgroundColor: c.isSent ? cs.primaryContainer : cs.secondaryContainer,
        child: Icon(
          c.isSent ? Icons.send_rounded : Icons.event_repeat_outlined,
          size: 20,
          color: c.isSent ? cs.onPrimaryContainer : cs.onSecondaryContainer,
        ),
      ),
      title: Text('${p.displayName} · ${p.labelOf(c)}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StageChip(c.stage),
        const SizedBox(width: 8),
        TextButton(onPressed: open, child: Text(c.isSent ? 'Open' : 'Continue')),
        if (allowDiscard && !c.isSent)
          IconButton(
            tooltip: 'Discard',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('Discard ${p.labelOf(c).toLowerCase()} for ${p.displayName}?'),
                  content: const Text('The inputs entered for this cycle will be removed. The profile and earlier cycles stay.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Discard')),
                  ],
                ),
              );
              if (ok == true && context.mounted) AppScope.read(context).onboarding.discardCycle(c.id);
            },
          ),
      ]),
    );
  }
}

class StageChip extends StatelessWidget {
  const StageChip(this.stage, {super.key, this.prefix = ''});
  final OnboardingStage stage;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (stage) {
      OnboardingStage.sent => (cs.primaryContainer, cs.onPrimaryContainer),
      OnboardingStage.review => (cs.tertiaryContainer, cs.onTertiaryContainer),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    final label = stage == OnboardingStage.review ? 'Ready for review' : stage.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('$prefix$label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
