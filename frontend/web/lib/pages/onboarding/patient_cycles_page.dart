import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../onboarding/onboarding_store.dart';
import '../../state/app_scope.dart';
import '../../widgets/breadcrumbs.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import 'onboarding_list.dart';
import 'onboarding_page.dart';

/// `/patients/:id/cycles` — the patient profile with every cycle, newest
/// first. Works for patients created here (`NEW-…`) and API patients (their
/// record's cycles are shown as history; new cycles are added here).
class PatientCyclesPage extends StatelessWidget {
  const PatientCyclesPage({super.key, required this.patientId});
  final String patientId;

  static bool isLocalId(String id) => id.startsWith('NEW-');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.onboarding,
      builder: (context, _) {
        final record = app.onboarding.patient(patientId);
        if (isLocalId(patientId)) {
          if (record == null) {
            return PageFrame(title: 'Patient not found', children: [
              const EmptyView(
                icon: Icons.person_search_outlined,
                title: 'This patient is not here',
                message: 'Patients added before the API exists only live in the browser tab they were created in.',
              ),
              Center(
                child: FilledButton.tonal(onPressed: () => context.go('/patients'), child: const Text('Back to patients')),
              ),
            ]);
          }
          return _Profile(record: record);
        }
        final ws = app.workspace(patientId);
        return ListenableBuilder(
          listenable: ws,
          builder: (context, _) {
            if (ws.patient == null) {
              if (ws.error != null) {
                return ErrorView(title: 'Could not load patient', error: ws.error!, onRetry: ws.load);
              }
              return const LoadingView(label: 'Loading patient…');
            }
            return _Profile(record: record, api: ws.patient);
          },
        );
      },
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({this.record, this.api});

  final PatientRecord? record;
  final Patient? api;

  PatientProfile get _profile => record?.profile ?? PatientProfile.fromApi(api!);
  List<PriorCycle> get _imported => record?.imported ?? OnboardingStore.priorCyclesOf(api!);
  List<CycleRecord> get _cycles => record?.cycles ?? const [];
  String get _id => record?.id ?? api!.id;

  void _newCycle(BuildContext context) {
    final app = AppScope.read(context);
    final store = app.onboarding;
    final rec = record ?? store.importApiPatient(api!);
    final ref = store.startCycle(
      rec,
      createdBy: app.account?.displayName ?? '',
      api: rec.cycles.isEmpty ? api : null,
    );
    context.go(OnboardingPage.path(ref.cycle.id, ref.cycle.stage));
  }

  @override
  Widget build(BuildContext context) {
    final acc = AppScope.of(context).account;
    final canAdd = acc != null && (acc.isOncologist || acc.isNurse);
    final pr = _profile;
    final open = record?.inProgress;
    final total = _imported.length + _cycles.length;
    final sex = switch (pr.sex) { 'F' => 'Female', 'M' => 'Male', _ => '—' };
    const languages = {'nl': 'Nederlands', 'fr': 'Français', 'en': 'English'};

    final tiles = <Widget>[
      for (final c in _cycles.reversed) _CycleTile.local(record!, c),
      for (var i = _imported.length - 1; i >= 0; i--) _CycleTile.imported(_imported[i], i + 1, _id),
    ];

    return PageFrame(
      title: pr.alias.isEmpty ? 'Patient' : pr.alias,
      subtitle: 'Patient profile · $total cycle${total == 1 ? '' : 's'}',
      maxWidth: 1100,
      breadcrumbs: [const Crumb('Patients', '/patients'), Crumb(pr.alias.isEmpty ? 'Patient' : pr.alias)],
      actions: [
        if (record?.isLocal ?? false)
          TextButton.icon(
            key: const Key('edit-profile'),
            onPressed: () => context.go('/patients/$_id/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        if (canAdd) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('new-cycle'),
            onPressed: () => open != null
                ? context.go(OnboardingPage.path(open.id, open.stage))
                : _newCycle(context),
            icon: Icon(open != null ? Icons.arrow_forward_rounded : Icons.add_rounded),
            label: Text(open != null
                ? 'Continue ${record!.labelOf(open).toLowerCase()}'
                : (total == 0 ? 'Start first cycle' : 'New cycle')),
          ),
        ],
      ],
      children: [
        SectionCard(
          title: 'Profile',
          subtitle: 'Shared by every cycle',
          icon: Icons.badge_outlined,
          child: Wrap(spacing: 32, runSpacing: 14, children: [
            KeyValue('Age', pr.age == null ? '—' : '${pr.age} yrs'),
            KeyValue('Sex', sex),
            KeyValue('Diagnosis', pr.diagnosis.isEmpty ? '—' : pr.diagnosis),
            KeyValue('Family language', languages[pr.language] ?? pr.language),
            KeyValue('Formulation and taste', pr.formulationPreference.isEmpty ? '—' : pr.formulationPreference),
            KeyValue('What helps', pr.whatHelps.isEmpty ? '—' : pr.whatHelps),
          ]),
        ),
        const SizedBox(height: 24),
        Text('Cycles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (tiles.isEmpty)
          EmptyView(
            icon: Icons.event_note_outlined,
            title: 'No cycles yet',
            message: canAdd
                ? 'Start the first cycle to enter the chemotherapy, hold the patient session and get a suggestion.'
                : 'The oncologist or nurse specialist starts cycles from here.',
          )
        else
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            tiles[i],
          ],
      ],
    );
  }
}

class _CycleTile extends StatelessWidget {
  const _CycleTile._({
    required this.number,
    required this.title,
    required this.lines,
    this.chip,
    this.action,
    this.onTap,
    this.key2,
  });

  factory _CycleTile.local(PatientRecord p, CycleRecord c) {
    final i = c.intake, s = c.session;
    void go(BuildContext ctx) => ctx.go(OnboardingPage.path(c.id, c.stage));
    return _CycleTile._(
      key2: Key('cycle-tile-${c.id}'),
      number: p.numberOf(c),
      title: [
        p.labelOf(c),
        if (i.cycleStart != null) DateFormat('d MMM yyyy').format(i.cycleStart!),
      ].join(' · '),
      lines: [
        [
          if (i.protocol.isNotEmpty) i.protocol,
          i.chemo.map((r) => '${r.drug} ${fmtNum(r.doseMgM2)} mg/m² d${daysText(r.days)}').join(', '),
        ].where((x) => x.isNotEmpty).join(' · '),
        [
          if (i.weightKg != null) '${fmtNum(i.weightKg!)} kg',
          if (i.heightCm != null) '${fmtNum(i.heightCm!)} cm',
          if (s.completed) DoseRoute.label(s.preferredRoute),
          if (s.priorNausea.isNotEmpty) '“${s.priorNausea}”',
        ].join(' · '),
        if (c.isSent) 'Approved by ${c.approvedBy ?? '—'}'
            '${c.approvedAt == null ? '' : ' on ${DateFormat('d MMM, HH:mm').format(c.approvedAt!)}'}',
      ].where((x) => x.isNotEmpty).toList(),
      chip: StageChip(c.stage),
      action: c.isSent ? 'Open' : 'Continue',
      onTap: go,
    );
  }

  factory _CycleTile.imported(PriorCycle c, int number, String patientId) => _CycleTile._(
        key2: c.current ? const Key('current-cycle-tile') : null,
        number: number,
        title: [
          c.label,
          if (c.date != null)
            DateTime.tryParse(c.date!) == null ? c.date! : DateFormat('d MMM yyyy').format(DateTime.parse(c.date!)),
        ].join(' · '),
        lines: [c.summary, c.note].where((x) => x.isNotEmpty).toList(),
        chip: _RecordChip(current: c.current),
        action: c.current ? 'Open plan' : null,
        onTap: c.current ? (ctx) => ctx.go('/patients/$patientId/regimen') : null,
      );

  final int number;
  final String title;
  final List<String> lines;
  final Widget? chip;
  final String? action;
  final void Function(BuildContext)? onTap;
  final Key? key2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tap = onTap == null ? null : () => onTap!(context);
    return Card(
      key: key2,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
              child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (chip != null) chip!,
                ]),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ),
              ]),
            ),
            if (action != null) TextButton(onPressed: tap, child: Text(action!)),
          ]),
        ),
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({this.current = false});
  final bool current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Text(current ? 'Current plan' : 'From patient record',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    );
  }
}
