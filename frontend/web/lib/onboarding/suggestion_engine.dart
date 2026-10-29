import 'dart:async';

import 'package:aimesis_client/aimesis_client.dart';

import 'onboarding_models.dart';

/// One model run during processing.
class ModelStep {
  final String key;
  final String title;
  final String description;
  const ModelStep(this.key, this.title, this.description);
}

enum ModelState { queued, running, done, failed }

/// Progress from [SuggestionEngine.run]. The last update carries [result].
class ProcessingUpdate {
  final String stepKey;
  final ModelState state;
  final Suggestion? result;
  final String? error;
  const ProcessingUpdate(this.stepKey, this.state, {this.result, this.error});
}

/// Runs the models over a cycle and brings their outputs together.
///
/// The screens only talk to this interface. When the calculation APIs exist,
/// add an implementation that calls them (or the AG-UI agent) and pass it to
/// [AppState]; nothing in the onboarding pages needs to change.
abstract class SuggestionEngine {
  List<ModelStep> get steps;
  Stream<ProcessingUpdate> run(CycleRef ref);
}

const defaultModelSteps = [
  ModelStep('emetogenicity', 'Chemotherapy emetogenicity',
      'Classifies each drug and treatment day by emetogenic risk'),
  ModelStep('risk', 'Patient risk factors',
      'Age, previous cycles, anticipatory nausea, swallowing and route'),
  ModelStep('interactions', 'Drug–drug interactions',
      'Checks other medications against the antiemetic options'),
  ModelStep('dosing', 'Antiemetic dosing',
      'Weight- and BSA-based doses, formulation per preferred route'),
  ModelStep('guidelines', 'Guideline check',
      'Compares the plan against the UZA protocol and POGO guideline'),
  ModelStep('combine', 'Bring it together',
      'Combines all model outputs into one suggestion for review'),
];

/// Stand-in until the calculation APIs are built: walks through the steps
/// with a short delay and returns a structured suggestion that echoes the
/// inputs. It makes no clinical calculations — tier and doses stay empty.
class PlaceholderSuggestionEngine implements SuggestionEngine {
  PlaceholderSuggestionEngine({this.stepDelay = const Duration(milliseconds: 650)});

  final Duration stepDelay;

  @override
  List<ModelStep> get steps => defaultModelSteps;

  @override
  Stream<ProcessingUpdate> run(CycleRef ref) async* {
    for (final s in steps) {
      yield ProcessingUpdate(s.key, ModelState.running);
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      final last = identical(s, steps.last);
      yield ProcessingUpdate(s.key, ModelState.done, result: last ? _suggestion(ref) : null);
    }
  }

  Suggestion _suggestion(CycleRef ref) {
    final p = ref.patient, c = ref.cycle;
    final pr = p.profile, i = c.intake, s = c.session;
    final days = i.chemoDays;
    final drugs = i.chemo.map((r) => r.drug).join(', ');
    final previous = p.imported.length + p.before(c).length;
    final route = !s.canSwallowTablets && s.preferredRoute == DoseRoute.oralTablet
        ? DoseRoute.oralLiquid
        : s.preferredRoute;
    const waiting = 'Placeholder until the model API is connected';
    return Suggestion(
      placeholder: true,
      generatedAt: DateTime.now(),
      antiemetics: [
        for (final drug in const ['ondansetron', 'dexamethasone', 'aprepitant'])
          SuggestedLine(drug: drug, route: route, days: days, note: 'Selection and dose from the models'),
      ],
      outputs: [
        ModelOutput(
          key: 'emetogenicity',
          title: 'Chemotherapy emetogenicity',
          summary: 'Will classify $drugs on day ${daysText(days)}.',
          details: [
            for (final r in i.chemo)
              '${r.drug} ${fmt(r.doseMgM2)} mg/m² · day ${daysText(r.days)}',
          ],
          source: waiting,
        ),
        ModelOutput(
          key: 'risk',
          title: 'Patient risk factors',
          summary: [
            if (pr.age != null) 'Age ${pr.age}',
            previous > 0
                ? '$previous previous cycle${previous == 1 ? '' : 's'} on the profile'
                : (i.firstCycle ? 'first cycle' : 'earlier chemotherapy not on the profile'),
            if (s.anticipatory) 'anticipatory nausea reported',
            s.canSwallowTablets ? 'can swallow tablets' : 'cannot swallow tablets',
          ].join(' · '),
          details: [
            if (s.priorNausea.trim().isNotEmpty) 'Previous nausea: ${s.priorNausea.trim()}',
            for (final prior in p.imported)
              if (prior.note.isNotEmpty) '${prior.label}: ${prior.note}',
            for (final b in p.before(c))
              if (b.session.priorNausea.trim().isNotEmpty) '${p.labelOf(b)}: ${b.session.priorNausea.trim()}',
          ],
          source: waiting,
        ),
        ModelOutput(
          key: 'interactions',
          title: 'Drug–drug interactions',
          summary: i.activeMeds.isEmpty
              ? 'No other medications entered.'
              : 'Will check ${i.activeMeds.join(', ')} against the antiemetic options.',
          source: waiting,
        ),
        ModelOutput(
          key: 'dosing',
          title: 'Antiemetic dosing',
          summary: 'Doses will use ${fmt(i.weightKg ?? 0)} kg, ${fmt(i.heightCm ?? 0)} cm, '
              'route ${DoseRoute.label(route).toLowerCase()}.',
          details: [
            if (pr.formulationPreference.trim().isNotEmpty)
              'Formulation preference: ${pr.formulationPreference.trim()}',
          ],
          source: waiting,
        ),
        ModelOutput(
          key: 'guidelines',
          title: 'Guideline check',
          summary: 'Will compare against the UZA protocol and the POGO guideline'
              '${i.protocol.trim().isEmpty ? '' : ' for ${i.protocol.trim()}'}.',
          source: waiting,
        ),
      ],
    );
  }

  static String fmt(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Calls `POST /cycles/evaluate` with the cycle's inputs and maps the returned
/// plan (rule-based, POGO/UZA) and the optional Gemini summary into a
/// [Suggestion]. The backend runs all models in one request, so every step
/// shows as running while it is in flight and is marked done (or failed)
/// when the answer arrives. The last step, the Gemini summary, may fail
/// without blocking the suggestion.
class ApiSuggestionEngine implements SuggestionEngine {
  ApiSuggestionEngine(this.api);

  final AimesisApi api;

  @override
  List<ModelStep> get steps => const [
        ModelStep('emetogenicity', 'Chemotherapy emetogenicity',
            'Classifies each drug and treatment day by emetogenic risk (POGO / UZA)'),
        ModelStep('risk', 'Patient risk factors',
            'Age, previous cycles, anticipatory nausea, swallowing and route'),
        ModelStep('interactions', 'Drug–drug interactions',
            'Checks other medications against the antiemetic options'),
        ModelStep('dosing', 'Antiemetic dosing',
            'Weight- and BSA-based doses, formulation per preferred route'),
        ModelStep('guidelines', 'Guideline check',
            'Compares the plan against the UZA protocol and POGO guideline'),
        ModelStep('combine', 'AI summary (Gemini)',
            'Summarises the plan for the clinician and explains it for the family'),
      ];

  /// Builds the API patient from the cycle being onboarded.
  static Patient patientFor(CycleRef ref) {
    final p = ref.patient, c = ref.cycle;
    final pr = p.profile, i = c.intake, s = c.session;
    final start = i.cycleStart;
    return Patient(
      id: p.id,
      alias: pr.alias.trim(),
      age: pr.age,
      sex: pr.sex,
      diagnosis: pr.diagnosis.trim().isEmpty ? null : pr.diagnosis.trim(),
      diagnosisGroup: pr.diagnosisGroup,
      protocol: i.protocol.trim().isEmpty ? null : i.protocol.trim(),
      cycle: p.labelOf(c),
      cycleStart: start == null
          ? null
          : '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      language: pr.language,
      weightKg: i.weightKg,
      heightCm: i.heightCm,
      chemo: [for (final r in i.chemo) ChemoRow(drug: r.drug.trim(), doseMgM2: r.doseMgM2, days: r.days)],
      activeMeds: [for (final m in i.activeMeds) if (m.trim().isNotEmpty) m.trim()],
      history: [
        for (final prior in p.imported)
          HistoryEntry(
            cycle: prior.label,
            date: prior.date,
            antiemetics: prior.summary.trim().isEmpty ? null : prior.summary.trim(),
            note: prior.note,
          ),
        for (final b in p.before(c))
          HistoryEntry(cycle: p.labelOf(b), note: b.session.priorNausea.trim()),
      ],
      riskFactors: s.toRiskFactors(),
    );
  }

  @override
  Stream<ProcessingUpdate> run(CycleRef ref) async* {
    final modelSteps = steps.where((s) => s.key != 'combine').toList();
    for (final s in modelSteps) {
      yield ProcessingUpdate(s.key, ModelState.running);
    }
    CycleEvaluation ev;
    try {
      ev = await api.evaluateCycle(patientFor(ref));
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      for (final s in modelSteps) {
        yield ProcessingUpdate(s.key, ModelState.failed, error: 'Could not run the models: $msg');
      }
      return;
    }
    for (final s in modelSteps) {
      yield ProcessingUpdate(s.key, ModelState.done);
    }
    final result = suggestionFrom(ev);
    if (ev.hasAi) {
      yield ProcessingUpdate('combine', ModelState.done, result: result);
    } else {
      yield ProcessingUpdate('combine', ModelState.failed,
          result: result,
          error: 'AI summary unavailable${ev.aiError == null ? '' : ': ${ev.aiError}'}. '
              'The rule-based plan below is complete.');
    }
  }

  /// Maps the evaluated plan into the review screen's [Suggestion].
  static Suggestion suggestionFrom(CycleEvaluation ev) {
    final plan = ev.plan;
    final dex = plan.dexamethasone;
    final interactions = plan.interactionsBySeverity;
    final pogoDiffs = plan.uzaVsPogo.where((r) => r.differs).toList();
    String src(String s) => s.trim();
    final refusalReason = plan.refusalReasons.isNotEmpty
        ? plan.refusalReasons.join(' ')
        : (plan.unknownDrugs.isNotEmpty ? 'Unknown drugs: ${plan.unknownDrugs.join(', ')}' : null);
    return Suggestion(
      placeholder: false,
      generatedAt: DateTime.now(),
      overallTier: plan.overallTier,
      aiSummary: ev.aiSummary,
      familyExplanation: ev.familyExplanation,
      aiModel: ev.aiModel,
      aiError: ev.aiError,
      dexBlocked: dex.blocked,
      dexBlockedReason: dex.blocked ? (dex.reason ?? 'Contraindicated') : null,
      refused: plan.refused,
      refusalReason: plan.refused ? (refusalReason ?? 'The models could not produce a safe suggestion.') : null,
      criticalInteractions: [
        for (final x in interactions)
          if (x.isCritical) '${x.drugs.join(' + ')}: ${x.message}${x.alternative == null ? '' : ' → ${x.alternative}'}',
      ],
      antiemetics: [
        for (final a in plan.antiemetics)
          SuggestedLine(
            drug: a.drug,
            route: a.route,
            days: a.days,
            dose: [a.doseLabel, a.frequency].where((x) => x.trim().isNotEmpty).join(' · '),
            note: [a.formula, ...a.notes].where((x) => x.trim().isNotEmpty).join(' · '),
          ),
      ],
      outputs: [
        ModelOutput(
          key: 'emetogenicity',
          title: 'Chemotherapy emetogenicity',
          summary: 'Overall: ${Tier.label(plan.overallTier)}'
              '${plan.dayTiers.isEmpty ? '' : ' · ${plan.dayTiers.map((d) => 'day ${d.day} ${Tier.label(d.tier).toLowerCase()}').join(', ')}'}',
          details: [
            for (final t in plan.drugTiers)
              '${t.drug}${t.doseMgM2 == null ? '' : ' ${PlaceholderSuggestionEngine.fmt(t.doseMgM2!)} mg/m²'}: '
                  '${Tier.label(t.tier)}${t.rule.isEmpty ? '' : ' — ${t.rule}'}${t.source.isEmpty ? '' : ' [${src(t.source)}]'}',
            for (final r in plan.combinationRules)
              'Combination: ${r.rule}${r.source.isEmpty ? '' : ' [${src(r.source)}]'}',
          ],
          source: 'POGO emetogenicity guideline / UZA protocol',
        ),
        ModelOutput(
          key: 'dexamethasone',
          title: 'Dexamethasone',
          summary: dex.blocked ? 'CONTRAINDICATED: ${dex.reason ?? 'see protocol'}' : 'Allowed',
          source: dex.source,
        ),
        ModelOutput(
          key: 'interactions',
          title: 'Drug–drug interactions',
          summary: interactions.isEmpty
              ? 'No interactions found.'
              : '${interactions.length} interaction${interactions.length == 1 ? '' : 's'}'
                  '${plan.hasCriticalInteraction ? ' (includes critical)' : ''}',
          details: [
            for (final x in interactions)
              '${x.severity.toUpperCase()} · ${x.drugs.join(' + ')}: ${x.message}'
                  '${x.alternative == null ? '' : ' Alternative: ${x.alternative}'}'
                  '${x.source.isEmpty ? '' : ' [${src(x.source)}]'}',
          ],
          source: 'Interaction checker',
        ),
        ModelOutput(
          key: 'dosing',
          title: 'Antiemetic dosing',
          summary: '${plan.antiemetics.length} antiemetic${plan.antiemetics.length == 1 ? '' : 's'}'
              '${plan.breakthrough.isEmpty ? '' : ', ${plan.breakthrough.length} breakthrough'}',
          details: [
            for (final a in plan.antiemetics)
              '${a.drug}: ${[a.doseLabel, a.frequency, a.routeLabel, a.daysLabel].where((x) => x.trim().isNotEmpty).join(' · ')}'
                  '${a.formula.isEmpty ? '' : ' (${a.formula})'}',
            for (final b in plan.breakthrough)
              'Breakthrough ${b.drug}: ${[b.doseLabel, b.frequency, b.routeLabel].where((x) => x.trim().isNotEmpty).join(' · ')}',
          ],
          source: 'UZA antiemetic protocol',
        ),
        ModelOutput(
          key: 'guidelines',
          title: 'UZA vs POGO',
          summary: pogoDiffs.isEmpty
              ? 'UZA protocol and POGO guideline agree.'
              : '${pogoDiffs.length} difference${pogoDiffs.length == 1 ? '' : 's'} between UZA and POGO',
          details: [
            for (final r in pogoDiffs)
              '${r.item}: UZA ${Tier.label(r.uzaTier)} vs POGO ${Tier.label(r.pogoTier)}${r.note.isEmpty ? '' : ' — ${r.note}'}',
          ],
          source: 'UZA protocol · POGO guideline',
        ),
        if (plan.stepUps.isNotEmpty || plan.alternatives.isNotEmpty)
          ModelOutput(
            key: 'stepups',
            title: 'Step-ups and alternatives',
            summary: '${plan.stepUps.length} step-up${plan.stepUps.length == 1 ? '' : 's'}, '
                '${plan.alternatives.length} alternative${plan.alternatives.length == 1 ? '' : 's'}',
            details: [
              for (final s in plan.stepUps)
                'Step-up: ${s.title} — ${s.reason}${s.source.isEmpty ? '' : ' [${src(s.source)}]'}',
              for (final a in plan.alternatives)
                'Alternative: ${a.title} — ${a.detail}${a.source.isEmpty ? '' : ' [${src(a.source)}]'}',
            ],
            source: 'UZA protocol',
          ),
      ],
    );
  }
}
