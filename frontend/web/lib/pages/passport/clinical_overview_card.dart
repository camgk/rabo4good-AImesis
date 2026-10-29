import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:intl/intl.dart';

import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';

String _fmtTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? iso : DateFormat('d MMM yyyy, HH:mm').format(d);
}

/// Doctor clinical overview card shown on the Passport page.
///
/// Summarises in one clear view:
///  1. Chemo history of the patient (previous cycles, antiemetics, nausea/vomiting days, ward notes)
///  2. Current treatment regimen with corresponding emetogenicity risk profile
///  3. Patient intake preferences (swallowing ability, preferred route)
///  4. Doctor and care-team clinical notes & sign-off comments
class ClinicalOverviewCard extends StatefulWidget {
  const ClinicalOverviewCard({super.key, required this.ws});

  final PatientWorkspace ws;

  @override
  State<ClinicalOverviewCard> createState() => _ClinicalOverviewCardState();
}

class _ClinicalOverviewCardState extends State<ClinicalOverviewCard> {
  bool _expanded = true;
  bool _editingNote = false;
  bool _savingNote = false;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.ws.patient?.riskFactors.priorNauseaNote ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant ClinicalOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingNote && widget.ws.patient?.riskFactors.priorNauseaNote != _noteController.text) {
      _noteController.text = widget.ws.patient?.riskFactors.priorNauseaNote ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final current = widget.ws.patient!.riskFactors;
      final updated = current.copyWith(
        priorNauseaNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      await widget.ws.mutate((api) => api.updateRiskFactors(widget.ws.patientId, updated));
      await widget.ws.refreshPatient();
      if (!mounted) return;
      setState(() => _editingNote = false);
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Doctor note saved · clinical overview updated'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(errorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final patient = widget.ws.patient;
    final plan = widget.ws.plan;

    if (patient == null || plan == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      color: cs.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with collapse/expand toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_expanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.medical_information_outlined, size: 22, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Doctor Clinical Overview',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (plan.overallTier != null)
                              TierBadge(tier: plan.overallTier!, compact: true),
                            const SizedBox(width: 8),
                            PlanStatusChip(plan.status, dense: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chemotherapy history, active regimen, emetic risk profile, medicine intake preference & doctor notes',
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                    tooltip: _expanded ? 'Collapse clinical overview' : 'Expand clinical overview',
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final col1 = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTreatmentCard(context, patient, plan),
                      const SizedBox(height: 16),
                      _buildPreferenceCard(context, patient),
                    ],
                  );
                  final col2 = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHistoryCard(context, patient),
                      const SizedBox(height: 16),
                      _buildNotesCard(context, patient, plan),
                    ],
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: col1),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: col2),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [col1, const SizedBox(height: 16), col2],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Current Treatment & Risk Profile
  // ---------------------------------------------------------------------------
  Widget _buildTreatmentCard(BuildContext context, Patient patient, Plan plan) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tiers = {for (final t in plan.drugTiers) t.drug.toLowerCase(): t};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Current Treatment & Emetogenicity Risk Profile',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (plan.overallTier != null)
                TierBadge(tier: plan.overallTier!),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              KeyValue('Protocol', patient.protocol ?? '—'),
              KeyValue('Cycle', patient.cycle ?? '—'),
              if (patient.cycleStart != null)
                KeyValue('Cycle start', patient.cycleStart!),
              KeyValue('Risk level', plan.overallTier != null ? Tier.label(plan.overallTier) : 'Pending'),
            ],
          ),
          if (plan.dexamethasone.blocked) ...[
            const SizedBox(height: 12),
            DexStatusBanner(
              blocked: true,
              reason: plan.dexamethasone.reason,
              source: plan.dexamethasone.source,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Chemotherapy Agents in Cycle',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (patient.chemo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No active chemotherapy drugs recorded.', style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            Column(
              children: [
                for (final c in patient.chemo) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cap(c.drug),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${fmtNum(c.doseMgM2)} mg/m² · ${formatDays(c.days)}',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (tiers.containsKey(c.drug.toLowerCase()))
                            TierBadge(tier: tiers[c.drug.toLowerCase()]!.tier, compact: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          if (plan.combinationRules.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final r in plan.combinationRules)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 16, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Combination escalation: ${r.rule}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Patient Medicine Administration Preference
  // ---------------------------------------------------------------------------
  Widget _buildPreferenceCard(BuildContext context, Patient patient) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rf = patient.riskFactors;

    final routeIcon = switch (rf.preferredRoute) {
      DoseRoute.oralLiquid => Icons.water_drop_outlined,
      DoseRoute.oralTablet => Icons.medication_outlined,
      DoseRoute.ngTube => Icons.cable_outlined,
      DoseRoute.iv => Icons.vaccines_outlined,
      _ => Icons.medication_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Medicine Administration Preference',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              // Preferred Route Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(routeIcon, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFERRED ROUTE',
                          style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: cs.primary),
                        ),
                        Text(
                          rf.routeLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Swallowing Tablets Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: rf.canSwallowTablets
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rf.canSwallowTablets ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rf.canSwallowTablets ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                      size: 18,
                      color: rf.canSwallowTablets ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SWALLOWS TABLETS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: rf.canSwallowTablets ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                        Text(
                          rf.canSwallowTablets ? 'Yes (Tablets allowed)' : 'No (Requires liquid/syrup)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: rf.canSwallowTablets ? const Color(0xFF14532D) : const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Anticipatory Nausea Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: rf.anticipatory ? const Color(0xFFFEE2E2) : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rf.anticipatory ? const Color(0xFFFCA5A5) : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rf.anticipatory ? Icons.warning_amber_rounded : Icons.sentiment_satisfied_outlined,
                      size: 18,
                      color: rf.anticipatory ? const Color(0xFFB91C1C) : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANTICIPATORY RISK',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: rf.anticipatory ? const Color(0xFFB91C1C) : cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          rf.anticipatory ? 'Present · Lorazepam / behavioral step-up' : 'None reported',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: rf.anticipatory ? const Color(0xFF7F1D1D) : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rf.canSwallowTablets
                ? 'Standard oral tablets and capsules are permitted in passport intake schedule.'
                : 'All oral medications are automatically converted to liquid, suspension, or dispersible formulations in the passport.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Chemotherapy & CINV History
  // ---------------------------------------------------------------------------
  Widget _buildHistoryCard(BuildContext context, Patient patient) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final history = patient.history;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Chemotherapy & CINV History',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Cycle 1 · No prior chemotherapy cycles on record.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final h in history) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (h.hadNausea || h.hadVomiting)
                            ? const Color(0xFFFED7AA)
                            : cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Cycle ${h.cycle}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            if (h.date != null) ...[
                              const SizedBox(width: 8),
                              Text(h.date!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ],
                            const Spacer(),
                            if (h.hadNausea)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDD5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nausea: ${formatDays(h.nauseaDays).toLowerCase()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ),
                            if (h.hadVomiting)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Vomiting: ${formatDays(h.vomitingDays).toLowerCase()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            if (!h.hadNausea && !h.hadVomiting)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'No emesis',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (h.antiemetics != null && h.antiemetics!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Prior antiemetics: ${h.antiemetics}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                        if (h.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.note_alt_outlined, size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    h.note,
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Doctor & Care Team Clinical Notes
  // ---------------------------------------------------------------------------
  Widget _buildNotesCard(BuildContext context, Patient patient, Plan plan) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final priorNote = patient.riskFactors.priorNauseaNote;
    final comments = plan.comments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Doctor & Care Team Clinical Notes',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (!_editingNote)
                TextButton.icon(
                  onPressed: () => setState(() => _editingNote = true),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(priorNote == null || priorNote.isEmpty ? 'Add note' : 'Edit note'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Editing field
          if (_editingNote) ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Document doctor observations on tolerance, breakthrough nausea, or adaptations…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _savingNote ? null : () => setState(() => _editingNote = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _savingNote ? null : _saveNote,
                  icon: _savingNote
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Note'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else if (priorNote != null && priorNote.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doctor Observation Note',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(priorNote, style: const TextStyle(fontSize: 13, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Care-team comments / sign-off notes
          if (comments.isNotEmpty) ...[
            Text(
              'Sign-Off & Multidisciplinary Comments',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: [
                for (final c in comments) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.comment_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.by,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                    ),
                                    if (c.role.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${RoleChip.label(c.role)})',
                                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (c.at.isNotEmpty)
                                      Text(
                                        _fmtTime(c.at),
                                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(c.text, style: const TextStyle(fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (!_editingNote && (priorNote == null || priorNote.isEmpty)) ...[
            Text(
              'No doctor notes recorded yet. Use "Add note" above to document cycle-specific observations.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
