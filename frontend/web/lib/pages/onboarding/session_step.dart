import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'onboarding_page.dart';

/// Step 2 — filled in by the doctor together with the patient and family.
class SessionStep extends StatefulWidget {
  const SessionStep({super.key, required this.cycleRef});
  final CycleRef cycleRef;

  @override
  State<SessionStep> createState() => _SessionStepState();
}

class _SessionStepState extends State<SessionStep> {
  late final PatientRecord _p = widget.cycleRef.patient;
  late final CycleRecord _c = widget.cycleRef.cycle;
  late final PatientProfile _pr = _p.profile;
  late final CycleSession _s = _c.session;
  late final bool _first = _p.isFirst(_c) && _c.intake.firstCycle;

  late final Set<String> _present = {..._s.present};
  late bool _canSwallow = _s.canSwallowTablets;
  late String _route = _s.preferredRoute;
  late bool _anticipatory = _s.anticipatory;
  late final _priorNausea = TextEditingController(text: _s.priorNausea);
  late final _formulation = TextEditingController(text: _pr.formulationPreference);
  late final _helps = TextEditingController(text: _pr.whatHelps);
  late final _concerns = TextEditingController(text: _s.concerns);

  @override
  void dispose() {
    for (final c in [_priorNausea, _formulation, _helps, _concerns]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _writeBack({required bool complete}) {
    final before = jsonEncode([{..._s.toJson(), 'completed': null}, _pr.toJson()]);
    _s
      ..present = {..._present}
      ..canSwallowTablets = _canSwallow
      ..preferredRoute = _route
      ..anticipatory = _anticipatory
      ..priorNausea = _priorNausea.text.trim()
      ..concerns = _concerns.text.trim();
    _pr
      ..formulationPreference = _formulation.text.trim()
      ..whatHelps = _helps.text.trim();
    if (complete) _s.completed = true;
    return jsonEncode([{..._s.toJson(), 'completed': null}, _pr.toJson()]) != before;
  }

  void _save(String to, {bool complete = false}) {
    final c = _c;
    if (_writeBack(complete: complete)) c.touchInputs();
    if (complete && c.stage.index < OnboardingStage.processing.index) c.stage = OnboardingStage.processing;
    AppScope.read(context).onboarding.save(_p, c);
    context.go(to);
  }

  @override
  Widget build(BuildContext context) {
    final id = _c.id;
    final hasHistory = _p.imported.isNotEmpty || _p.before(_c).isNotEmpty;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 960;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (hasHistory) ...[
          _historyCard(context),
          const SizedBox(height: 16),
        ],
        _presentCard(context),
        const SizedBox(height: 16),
        _routeCard(context),
        const SizedBox(height: 16),
        _nauseaCard(context),
      ]);
      final right = _preferencesCard(context);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _treatmentSummary(context),
        const SizedBox(height: 16),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ])
        else ...[
          left,
          const SizedBox(height: 16),
          right,
        ],
        StepFooter(
          back: TextButton.icon(
            onPressed: () => _save(OnboardingPage.path(id, OnboardingStage.treatment)),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Treatment'),
          ),
          secondary: TextButton(
            onPressed: () => _save('/patients/${_p.id}'),
            child: const Text('Save and exit'),
          ),
          primary: FilledButton.icon(
            key: const Key('onboarding-run-models'),
            onPressed: () => _save(OnboardingPage.path(id, OnboardingStage.processing), complete: true),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Finish session and run models'),
          ),
        ),
      ]);
    });
  }

  /// Read-only reminder of what the doctor prepared in session 1.
  Widget _treatmentSummary(BuildContext context) {
    final i = _c.intake;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primaryContainer),
      ),
      child: Wrap(spacing: 20, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_outline_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            '${_pr.alias}${_pr.age == null ? '' : ' · ${_pr.age} yrs'} · ${_p.labelOf(_c)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ]),
        if (_pr.diagnosis.isNotEmpty) Text(_pr.diagnosis),
        if (i.protocol.isNotEmpty) Text(i.protocol),
        Text(i.chemo.map((c) => '${c.drug} d${daysText(c.days)}').join(' · '),
            style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  /// Earlier cycles on the profile, newest first, so the family session can
  /// start from how they went.
  Widget _historyCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <(String, String?, String)>[
      for (final b in _p.before(_c))
        (
          _p.labelOf(b),
          b.intake.cycleStart == null ? null : DateFormat('d MMM yyyy').format(b.intake.cycleStart!),
          [
            b.intake.chemo.map((r) => r.drug).join(', '),
            if (b.session.priorNausea.isNotEmpty) '“${b.session.priorNausea}”',
            if (b.isSent) 'sent to pharmacist' else b.stage.label.toLowerCase(),
          ].where((x) => x.isNotEmpty).join(' · '),
        ),
      for (final prior in _p.imported) (prior.label, prior.date, [prior.summary, prior.note].where((x) => x.isNotEmpty).join(' · ')),
    ].reversed.toList();
    final shown = rows.take(3).toList();
    return SectionCard(
      title: 'Previous cycles',
      subtitle: '${rows.length} on the profile',
      icon: Icons.history_rounded,
      trailing: rows.length > 3
          ? TextButton(onPressed: () => context.go('/patients/${_p.id}'), child: const Text('See all'))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([r.$1, if (r.$2 != null) r.$2!].join(' · '), style: const TextStyle(fontWeight: FontWeight.w600)),
              if (r.$3.isNotEmpty) Text(r.$3, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }

  Widget _presentCard(BuildContext context) {
    return SectionCard(
      title: 'Who is here',
      icon: Icons.groups_outlined,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in CycleSession.presentOptions.entries)
          FilterChip(
            label: Text(e.value),
            selected: _present.contains(e.key),
            onSelected: (v) => setState(() => v ? _present.add(e.key) : _present.remove(e.key)),
          ),
      ]),
    );
  }

  Widget _routeCard(BuildContext context) {
    const routes = [
      (DoseRoute.oralTablet, 'Tablet', Icons.medication_outlined),
      (DoseRoute.oralLiquid, 'Liquid', Icons.water_drop_outlined),
      (DoseRoute.ngTube, 'NG tube', Icons.cable_outlined),
      (DoseRoute.iv, 'IV', Icons.vaccines_outlined),
    ];
    return SectionCard(
      title: 'Swallowing & route',
      icon: Icons.tune_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          key: const Key('session-swallow'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Can swallow tablets'),
          value: _canSwallow,
          onChanged: (v) => setState(() => _canSwallow = v),
        ),
        const SizedBox(height: 8),
        Text('Preferred route', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final r in routes) ButtonSegment(value: r.$1, label: Text(r.$2), icon: Icon(r.$3, size: 18)),
            ],
            selected: {_route},
            onSelectionChanged: (s) => setState(() => _route = s.first),
          ),
        ),
      ]),
    );
  }

  Widget _nauseaCard(BuildContext context) {
    final first = _first;
    return SectionCard(
      title: 'Nausea history',
      icon: Icons.history_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Anticipatory nausea'),
          subtitle: const Text('Feels sick before treatment starts'),
          value: _anticipatory,
          onChanged: (v) => setState(() => _anticipatory = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priorNausea,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: first ? 'Nausea in other situations' : 'How did the last cycle go?',
            hintText: first ? 'e.g. car sickness, migraines' : 'Nausea or vomiting: which days, how bad, what helped',
            alignLabelWithHint: true,
          ),
        ),
      ]),
    );
  }

  Widget _preferencesCard(BuildContext context) {
    Widget field(TextEditingController c, String label, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: c,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true),
          ),
        );
    return SectionCard(
      title: 'Preferences',
      subtitle: 'In their own words · taste and what helps are kept on the profile',
      icon: Icons.favorite_border_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        field(_formulation, 'Formulation and taste', 'e.g. prefers liquid, dislikes mint flavour'),
        field(_helps, 'What helps, what to avoid', 'e.g. small cold meals, no strong smells'),
        field(_concerns, 'Questions or worries', 'e.g. worried about missing school'),
      ]),
    );
  }
}
