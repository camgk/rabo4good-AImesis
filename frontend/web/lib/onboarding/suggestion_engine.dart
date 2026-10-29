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

/// Runs the models over a draft and brings their outputs together.
///
/// The screens only talk to this interface. When the calculation APIs exist,
/// add an implementation that calls them (or the AG-UI agent) and pass it to
/// [AppState]; nothing in the onboarding pages needs to change.
abstract class SuggestionEngine {
  List<ModelStep> get steps;
  Stream<ProcessingUpdate> run(OnboardingDraft draft);
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
  Stream<ProcessingUpdate> run(OnboardingDraft draft) async* {
    for (final s in steps) {
      yield ProcessingUpdate(s.key, ModelState.running);
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      final last = identical(s, steps.last);
      yield ProcessingUpdate(s.key, ModelState.done, result: last ? _suggestion(draft) : null);
    }
  }

  Suggestion _suggestion(OnboardingDraft d) {
    final i = d.intake, p = d.session;
    final days = i.chemoDays;
    final drugs = i.chemo.map((c) => c.drug).join(', ');
    final route = !p.canSwallowTablets && p.preferredRoute == DoseRoute.oralTablet
        ? DoseRoute.oralLiquid
        : p.preferredRoute;
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
            for (final c in i.chemo)
              '${c.drug} ${fmt(c.doseMgM2)} mg/m² · day ${daysText(c.days)}',
          ],
          source: waiting,
        ),
        ModelOutput(
          key: 'risk',
          title: 'Patient risk factors',
          summary: [
            if (i.age != null) 'Age ${i.age}',
            i.firstCycle ? 'first cycle' : 'previous cycles recorded',
            if (p.anticipatory) 'anticipatory nausea reported',
            p.canSwallowTablets ? 'can swallow tablets' : 'cannot swallow tablets',
          ].join(' · '),
          details: [
            if (p.priorNausea.trim().isNotEmpty) 'Previous nausea: ${p.priorNausea.trim()}',
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
            if (p.formulationPreference.trim().isNotEmpty)
              'Formulation preference: ${p.formulationPreference.trim()}',
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
