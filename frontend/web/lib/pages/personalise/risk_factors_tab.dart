import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:intl/intl.dart';

import '../../state/app_scope.dart';
import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';

/// Story 3 — personalisation: risk factors, previous cycles, companion log.
class RiskFactorsTab extends StatefulWidget {
  const RiskFactorsTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  State<RiskFactorsTab> createState() => _RiskFactorsTabState();
}

class _RiskFactorsTabState extends State<RiskFactorsTab> {
  late RiskFactors _rf = widget.ws.patient!.riskFactors;
  bool _saving = false;
  Future<List<Episode>>? _episodes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _episodes ??= AppScope.read(context).api.episodes(widget.ws.patientId);
  }

  bool get _dirty {
    final o = widget.ws.patient!.riskFactors;
    return o.canSwallowTablets != _rf.canSwallowTablets ||
        o.preferredRoute != _rf.preferredRoute ||
        o.anticipatory != _rf.anticipatory;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final plan = await widget.ws.mutate((api) => api.updateRiskFactors(widget.ws.patientId, _rf));
      await widget.ws.refreshPatient();
      if (!mounted) return;
      setState(() => _rf = widget.ws.patient!.riskFactors);
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Plan recalculated · overall tier ${Tier.label(plan.overallTier)}'
            '${plan.refused ? ' · plan refused' : ' · ${plan.antiemetics.length} antiemetic lines'}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = AppScope.of(context).account!;
    final canEdit = acc.canEditRiskFactors;
    final patient = widget.ws.patient!;
    final plan = widget.ws.plan!;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final left = _riskFactorsCard(context, canEdit);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _historyCard(context, patient),
        const SizedBox(height: 16),
        _companionCard(context, plan),
      ]);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 6, child: right),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
    });
  }

  Widget _riskFactorsCard(BuildContext context, bool canEdit) {
    final cs = Theme.of(context).colorScheme;
    final routes = const [
      (Route.oralTablet, 'Oral tablet', Icons.medication_outlined),
      (Route.oralLiquid, 'Oral liquid', Icons.water_drop_outlined),
      (Route.ngTube, 'NG tube', Icons.cable_outlined),
      (Route.iv, 'IV', Icons.vaccines_outlined),
    ];
    return SectionCard(
      title: 'Risk factors & route',
      subtitle: canEdit ? 'Changes recalculate the plan' : 'Read-only for your role (oncologist or nurse can edit)',
      icon: Icons.tune_rounded,
      story: 'Story 3',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Can swallow tablets'),
          subtitle: const Text('If not, oral tablets switch to oral liquid'),
          value: _rf.canSwallowTablets,
          onChanged: canEdit ? (v) => setState(() => _rf = _rf.copyWith(canSwallowTablets: v)) : null,
        ),
        const SizedBox(height: 8),
        Text('Preferred route', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final r in routes) ButtonSegment(value: r.$1, label: Text(r.$2), icon: Icon(r.$3, size: 18)),
          ],
          selected: {_rf.preferredRoute},
          onSelectionChanged: canEdit ? (s) => setState(() => _rf = _rf.copyWith(preferredRoute: s.first)) : null,
        ),
        if (!_rf.canSwallowTablets && _rf.preferredRoute == Route.oralTablet)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Cannot swallow tablets → the rules engine will switch tablets to oral liquid.',
                style: TextStyle(fontSize: 12.5, color: cs.tertiary)),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Anticipatory nausea'),
          subtitle: const Text('Adds lorazepam to the breakthrough options'),
          value: _rf.anticipatory,
          onChanged: canEdit ? (v) => setState(() => _rf = _rf.copyWith(anticipatory: v)) : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (_dirty)
            TextButton(
              onPressed: _saving ? null : () => setState(() => _rf = widget.ws.patient!.riskFactors),
              child: const Text('Discard'),
            ),
          const Spacer(),
          Tooltip(
            message: canEdit ? '' : 'Only the oncologist or nurse specialist can change risk factors',
            child: FilledButton.icon(
              onPressed: canEdit && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate_outlined),
              label: Text(_dirty ? 'Save & recalculate' : 'Recalculate plan'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _historyCard(BuildContext context, Patient patient) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Previous cycles',
      subtitle: 'From the ward notes (quoted, not interpreted)',
      icon: Icons.history_rounded,
      child: patient.history.isEmpty
          ? const EmptyView(icon: Icons.history_toggle_off_rounded, title: 'No previous cycles recorded')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final h in patient.history)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('Cycle ${h.cycle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (h.date != null) Text(h.date!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                      _pill(context, h.nauseaDays.isEmpty ? 'No nausea' : 'Nausea ${formatDays(h.nauseaDays).toLowerCase()}',
                          h.nauseaDays.isNotEmpty),
                      _pill(context,
                          h.vomitingDays.isEmpty ? 'No vomiting' : 'Vomiting ${formatDays(h.vomitingDays).toLowerCase()}',
                          h.vomitingDays.isNotEmpty),
                    ]),
                    if (h.antiemetics != null && h.antiemetics!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Antiemetics: ${h.antiemetics}', style: const TextStyle(fontSize: 13)),
                    ],
                    if (h.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.primary, width: 3))),
                        child: Text('“${h.note}”', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ]),
                ),
            ]),
    );
  }

  Widget _pill(BuildContext context, String text, bool bad) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bad ? cs.errorContainer : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: bad ? cs.onErrorContainer : cs.onSecondaryContainer)),
    );
  }

  Widget _companionCard(BuildContext context, Plan plan) {
    final cs = Theme.of(context).colorScheme;
    final summary = plan.episodesSummary;
    final days = [...summary.currentCycle]..sort((a, b) => a.day.compareTo(b.day));
    final maxCount = days.fold<int>(1, (m, d) => d.total > m ? d.total : m);
    return SectionCard(
      title: 'Companion app log',
      subtitle: 'Episodes logged by the family this cycle',
      icon: Icons.phone_iphone_rounded,
      story: 'Bonus',
      trailing: IconButton(
        tooltip: 'Refresh log',
        icon: const Icon(Icons.refresh_rounded, size: 20),
        onPressed: () async {
          setState(() => _episodes = AppScope.read(context).api.episodes(widget.ws.patientId));
          await widget.ws.load();
        },
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (summary.priorNauseaDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Prior nausea on ${formatDays(summary.priorNauseaDays).toLowerCase()} — used for step-ups.',
                style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.w600)),
          ),
        if (days.isEmpty)
          Text('No episodes in the current cycle.', style: TextStyle(color: cs.onSurfaceVariant))
        else
          SizedBox(
            height: 120,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${d.total}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (d.vomiting > 0)
                        Container(
                          height: 70.0 * d.vomiting / maxCount,
                          decoration: const BoxDecoration(color: Color(0xFFDC2626)),
                        ),
                      if (d.nausea > 0)
                        Container(
                          height: 70.0 * d.nausea / maxCount,
                          decoration: const BoxDecoration(color: Color(0xFFF59E0B)),
                        ),
                      const SizedBox(height: 4),
                      Text('D${d.day}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ),
            ]),
          ),
        if (days.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              _legend(const Color(0xFFF59E0B), 'Nausea'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFDC2626), 'Vomiting'),
            ]),
          ),
        const Divider(height: 24),
        FutureBuilder<List<Episode>>(
          future: _episodes,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) {
              return Text('Could not load episodes: ${errorMessage(snap.error!)}', style: TextStyle(color: cs.error));
            }
            final eps = snap.data ?? const [];
            if (eps.isEmpty) {
              return Text('No episodes logged yet. Families log with one tap in the AImesis Family app.',
                  style: TextStyle(color: cs.onSurfaceVariant));
            }
            final fmt = DateFormat('EEE d MMM, HH:mm');
            return Column(children: [
              for (final e in eps.take(12))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.isVomiting ? Icons.sick_outlined : Icons.sentiment_dissatisfied_outlined,
                    color: e.isVomiting ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  ),
                  title: Text('${cap(e.type)}${e.severity != null ? ' · severity ${e.severity}/5' : ''}'),
                  subtitle: Text(
                      'Cycle day ${e.cycleDay} · ${e.atDate != null ? fmt.format(e.atDate!) : e.at} · logged by ${e.loggedByRole}'),
                ),
              if (eps.length > 12)
                Text('+ ${eps.length - 12} more', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: c),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}
