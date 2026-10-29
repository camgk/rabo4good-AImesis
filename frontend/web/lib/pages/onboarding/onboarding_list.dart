import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import 'onboarding_page.dart';

/// Compact list of onboarding drafts (Patients page, pharmacist queue).
class OnboardingList extends StatelessWidget {
  const OnboardingList({super.key, required this.drafts, this.allowDiscard = false});

  final List<OnboardingDraft> drafts;
  final bool allowDiscard;

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
        for (var i = 0; i < drafts.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          _row(context, drafts[i]),
        ],
      ]),
    );
  }

  Widget _row(BuildContext context, OnboardingDraft d) {
    final cs = Theme.of(context).colorScheme;
    final i = d.intake;
    final when = d.isSent && d.approvedAt != null ? d.approvedAt! : d.updatedAt;
    final details = [
      if (i.age != null) '${i.age} yrs',
      if (i.diagnosis.isNotEmpty) i.diagnosis,
      if (i.protocol.isNotEmpty) i.protocol,
      '${d.isSent ? 'Sent' : 'Updated'} ${DateFormat('d MMM, HH:mm').format(when)}',
    ].join(' · ');
    void open() => context.go(OnboardingPage.path(d.id, d.stage));
    return ListTile(
      key: Key('onboarding-row-${d.id}'),
      onTap: open,
      leading: CircleAvatar(
        backgroundColor: d.isSent ? cs.primaryContainer : cs.secondaryContainer,
        child: Icon(d.isSent ? Icons.send_rounded : Icons.person_add_alt_1_outlined,
            size: 20, color: d.isSent ? cs.onPrimaryContainer : cs.onSecondaryContainer),
      ),
      title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _StageChip(d.stage),
        const SizedBox(width: 8),
        TextButton(onPressed: open, child: Text(d.isSent ? 'Open' : 'Continue')),
        if (allowDiscard && !d.isSent)
          IconButton(
            tooltip: 'Discard',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('Discard ${d.displayName}?'),
                  content: const Text('The onboarding inputs entered so far will be removed.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
                  ],
                ),
              );
              if (ok == true && context.mounted) AppScope.read(context).onboarding.remove(d.id);
            },
          ),
      ]),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip(this.stage);
  final OnboardingStage stage;

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
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
