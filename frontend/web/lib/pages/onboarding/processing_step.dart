import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/onboarding_models.dart';
import '../../onboarding/suggestion_engine.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'onboarding_page.dart';

/// Step 3 — runs the models and brings their outputs together.
class ProcessingStep extends StatefulWidget {
  const ProcessingStep({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  State<ProcessingStep> createState() => _ProcessingStepState();
}

class _ProcessingStepState extends State<ProcessingStep> {
  late final SuggestionEngine _engine = AppScope.read(context).suggestionEngine;
  final Map<String, ModelState> _states = {};
  StreamSubscription<ProcessingUpdate>? _sub;
  String? _error;

  bool get _running => _sub != null;
  bool get _ready => !widget.draft.needsProcessing && !_running;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.draft.needsProcessing) {
        _start();
      } else {
        setState(() => _states.addAll({for (final s in _engine.steps) s.key: ModelState.done}));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    final d = widget.draft;
    final store = AppScope.read(context).onboarding;
    final version = d.inputsVersion;
    setState(() {
      _error = null;
      _states
        ..clear()
        ..addAll({for (final s in _engine.steps) s.key: ModelState.queued});
    });
    _sub = _engine.run(d).listen(
      (u) {
        if (!mounted) return;
        setState(() => _states[u.stepKey] = u.state);
        if (u.state == ModelState.failed) _error = u.error ?? 'A model failed to run.';
        final result = u.result;
        if (result != null) {
          d
            ..suggestion = result
            ..processedVersion = version;
          if (d.stage.index < OnboardingStage.review.index) d.stage = OnboardingStage.review;
          store.save(d);
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = errorMessage(e));
      },
      onDone: () {
        if (mounted) setState(() => _sub = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = _engine.steps;
    final done = _states.values.where((s) => s == ModelState.done).length;
    final d = widget.draft;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: _ready ? 'Suggestion ready' : (_error != null ? 'Processing stopped' : 'Running models'),
        subtitle: '$done of ${steps.length} complete',
        icon: _ready ? Icons.task_alt_rounded : Icons.auto_awesome_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: steps.isEmpty ? 0 : done / steps.length, minHeight: 6),
          ),
          const SizedBox(height: 12),
          for (final s in steps) _row(context, s, _states[s.key] ?? ModelState.queued),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),
        ]),
      ),
      StepFooter(
        back: TextButton.icon(
          onPressed: _running ? null : () => context.go(OnboardingPage.path(d.id, OnboardingStage.session)),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Patient session'),
        ),
        secondary: _running ? null : TextButton(onPressed: _start, child: const Text('Run again')),
        primary: FilledButton.icon(
          key: const Key('onboarding-review'),
          onPressed: _ready ? () => context.go(OnboardingPage.path(d.id, OnboardingStage.review)) : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review suggestion'),
        ),
      ),
    ]);
  }

  Widget _row(BuildContext context, ModelStep s, ModelState state) {
    final cs = Theme.of(context).colorScheme;
    final Widget lead = switch (state) {
      ModelState.running => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ModelState.done => Icon(Icons.check_circle_rounded, color: cs.primary, size: 24),
      ModelState.failed => Icon(Icons.error_rounded, color: cs.error, size: 24),
      ModelState.queued => Icon(Icons.radio_button_unchecked_rounded, color: cs.outline, size: 24),
    };
    final label = switch (state) {
      ModelState.running => 'Running',
      ModelState.done => 'Done',
      ModelState.failed => 'Failed',
      ModelState.queued => 'Queued',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: state == ModelState.running ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: state == ModelState.running ? cs.primary : cs.outlineVariant),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Center(child: lead)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(s.description, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ]),
        ),
        Text(label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
