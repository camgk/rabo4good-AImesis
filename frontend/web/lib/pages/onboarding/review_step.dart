import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'onboarding_page.dart';

/// Step 4 — the doctor checks the suggestion, approves it and sends it on.
class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key, required this.cycleRef});
  final CycleRef cycleRef;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  late final PatientRecord _p = widget.cycleRef.patient;
  late final CycleRecord _c = widget.cycleRef.cycle;
  late final _note = TextEditingController(text: _c.reviewNote);
  bool _reviewed = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final app = AppScope.read(context);
    final d = _c
      ..reviewNote = _note.text.trim()
      ..approvedBy = app.account?.displayName ?? 'Oncologist'
      ..approvedAt = DateTime.now()
      ..stage = OnboardingStage.sent;
    app.onboarding.save(_p, d);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('${_p.displayName} · ${_p.labelOf(d)} sent to the pharmacist'),
    ));
    context.go('/patients/${_p.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.suggestion;
    if (s == null) {
      return const EmptyView(icon: Icons.hourglass_empty_rounded, title: 'No suggestion yet');
    }
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _planCard(context, s),
        const SizedBox(height: 16),
        _modelsCard(context, s),
      ]);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _approvalCard(context),
        const SizedBox(height: 16),
        _inputsCard(context),
      ]);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: right),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [right, const SizedBox(height: 16), left]);
    });
  }

  Widget _planCard(BuildContext context, Suggestion s) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Suggested antiemetic plan',
      subtitle: 'Generated ${DateFormat('d MMM, HH:mm').format(s.generatedAt)}',
      icon: Icons.medication_liquid_outlined,
      trailing: _tierChip(context, s.overallTier),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.placeholder)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: cs.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Model APIs not connected yet: drug selection, tier and doses are placeholders.',
                  style: TextStyle(fontSize: 12.5, color: cs.onTertiaryContainer),
                ),
              ),
            ]),
          ),
        Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(3)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
              children: [
                for (final h in ['Drug', 'Route', 'Days', 'Dose'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(h, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
            for (final l in s.antiemetics)
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(cap(l.drug), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(DoseRoute.label(l.route)),
                  Text(l.days.isEmpty ? '—' : daysText(l.days)),
                  Text(l.dose ?? 'From dosing model',
                      style: l.dose == null ? TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic) : null),
                ],
              ),
          ],
        ),
      ]),
    );
  }

  Widget _tierChip(BuildContext context, String? tier) {
    final cs = Theme.of(context).colorScheme;
    final known = Tier.isKnown(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: known ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        known ? '${Tier.label(tier)} emetogenic' : 'Tier pending',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: known ? cs.onSecondaryContainer : cs.onSurfaceVariant),
      ),
    );
  }

  Widget _modelsCard(BuildContext context, Suggestion s) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'How the suggestion was built',
      subtitle: 'One entry per model',
      icon: Icons.account_tree_outlined,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(children: [
        for (final o in s.outputs)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(o.summary),
              children: [
                for (final line in o.details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $line'),
                  ),
                if (o.source.isNotEmpty) SourceLabel(o.source),
              ],
            ),
          ),
        if (s.outputs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No model outputs.', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }

  Widget _approvalCard(BuildContext context) {
    final d = _c;
    final cs = Theme.of(context).colorScheme;
    final acc = AppScope.of(context).account;
    final canApprove = acc?.canSubmitPlan ?? false;
    if (d.isSent) {
      return SectionCard(
        title: 'Sent to pharmacist',
        icon: Icons.verified_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KeyValue('Approved by', d.approvedBy ?? '—'),
          const SizedBox(height: 8),
          KeyValue('On', d.approvedAt == null ? '—' : DateFormat('d MMM yyyy, HH:mm').format(d.approvedAt!)),
          if (d.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note for the pharmacist', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(d.reviewNote),
          ],
        ]),
      );
    }
    return SectionCard(
      title: 'Approve',
      subtitle: canApprove ? 'Your approval sends the plan to the pharmacist' : 'Only the oncologist can approve',
      icon: Icons.how_to_reg_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _note,
          enabled: canApprove,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Note for the pharmacist (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('onboarding-reviewed'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _reviewed,
          onChanged: canApprove ? (v) => setState(() => _reviewed = v ?? false) : null,
          title: const Text('I have reviewed the suggestion and the patient inputs'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('onboarding-send'),
          onPressed: canApprove && _reviewed ? _send : null,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Approve and send to pharmacist'),
        ),
        if (!canApprove)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Signed in as ${acc?.displayName ?? 'unknown'}.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }

  Widget _inputsCard(BuildContext context) {
    final d = _c;
    final pr = _p.profile, i = d.intake, p = d.session;
    final cs = Theme.of(context).colorScheme;
    final previous = _p.imported.length + _p.before(d).length;
    Widget section(String title, OnboardingStage step, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.labelLarge)),
              if (!d.isSent)
                TextButton(
                  onPressed: () => context.go(OnboardingPage.path(d.id, step)),
                  child: const Text('Edit'),
                ),
            ]),
            for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: r),
          ]),
        );
    String text(String v) => v.trim().isEmpty ? '—' : v.trim();
    return SectionCard(
      title: 'Inputs',
      subtitle: 'Editing an input re-runs the models',
      icon: Icons.fact_check_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        section('Treatment & patient', OnboardingStage.treatment, [
          KeyValue('Patient', '${pr.alias}${pr.age == null ? '' : ', ${pr.age} yrs'}${pr.sex == null ? '' : ', ${pr.sex}'}'),
          KeyValue('Diagnosis', text(pr.diagnosis)),
          KeyValue('Cycle', '${_p.labelOf(d)} · ${previous == 0 ? 'no previous cycles on the profile' : '$previous previous on the profile'}'),
          KeyValue('Weight / height', '${fmtNum(i.weightKg ?? 0)} kg · ${fmtNum(i.heightCm ?? 0)} cm'),
          KeyValue('Protocol', '${text(i.protocol)}${i.cycle.isEmpty ? '' : ' · cycle ${i.cycle}'}'),
          KeyValue('Chemotherapy',
              i.chemo.map((c) => '${c.drug} ${fmtNum(c.doseMgM2)} mg/m² d${daysText(c.days)}').join('\n')),
          KeyValue('Other medications', i.activeMeds.isEmpty ? 'None' : i.activeMeds.join(', ')),
        ]),
        Divider(color: cs.outlineVariant),
        section('Patient session', OnboardingStage.session, [
          KeyValue('Tablets', p.canSwallowTablets ? 'Can swallow' : 'Cannot swallow'),
          KeyValue('Preferred route', DoseRoute.label(p.preferredRoute)),
          KeyValue('Anticipatory nausea', p.anticipatory ? 'Yes' : 'No'),
          KeyValue('Nausea history', text(p.priorNausea)),
          KeyValue('Formulation', text(pr.formulationPreference)),
          KeyValue('What helps', text(pr.whatHelps)),
          KeyValue('Worries', text(p.concerns)),
        ]),
      ]),
    );
  }
}
