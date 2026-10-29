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
