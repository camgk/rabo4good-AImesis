import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/breadcrumbs.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import 'processing_step.dart';
import 'review_step.dart';
import 'session_step.dart';
import 'treatment_step.dart';

/// `/onboarding/:cycleId/:step` — the four-step flow for one cycle: a new
/// patient's first cycle, or the next cycle of an existing patient.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.cycleId, required this.step});

  final String cycleId;
  final OnboardingStage step;

  static String path(String cycleId, OnboardingStage s) =>
      '/onboarding/$cycleId/${(s == OnboardingStage.sent ? OnboardingStage.review : s).path}';

  static const _subtitles = {
    OnboardingStage.treatment: 'Session 1 · Prepare the chemotherapy for this cycle',
    OnboardingStage.session: 'Session 2 · Fill this in together with the patient and family',
    OnboardingStage.processing: 'The models run over the inputs and bring the results together',
    OnboardingStage.review: 'Check the suggestion, approve it and send it to the pharmacist',
  };

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ref = store.cycle(cycleId);
        if (ref == null) {
          return PageFrame(title: 'Cycle not found', children: [
            const EmptyView(
              icon: Icons.person_search_outlined,
              title: 'This cycle is not here',
              message: 'It may have been discarded, or it was started in another browser tab.',
            ),
            Center(
              child: FilledButton.tonal(onPressed: () => context.go('/patients'), child: const Text('Back to patients')),
            ),
          ]);
        }
        final p = ref.patient, c = ref.cycle;

        // Sent cycles only show the (read-only) review. Otherwise fall back
        // to the furthest step that can be opened.
        var current = c.isSent ? OnboardingStage.review : step;
        if (!c.isSent && !c.canOpen(current, p.profile)) {
          current = OnboardingStage.steps.lastWhere((s) => c.canOpen(s, p.profile));
        }
        if (current != step) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(path(cycleId, current));
          });
        }

        final Widget body = switch (current) {
          OnboardingStage.treatment => TreatmentStep(key: ValueKey('treatment-$cycleId'), cycleRef: ref),
          OnboardingStage.session => SessionStep(key: ValueKey('session-$cycleId'), cycleRef: ref),
          OnboardingStage.processing => ProcessingStep(key: ValueKey('processing-$cycleId'), cycleRef: ref),
          _ => ReviewStep(key: ValueKey('review-$cycleId'), cycleRef: ref),
        };

        return PageFrame(
          key: ValueKey('frame-$cycleId-${current.path}'),
          title: '${p.displayName} · ${p.labelOf(c)}',
          subtitle: c.isSent ? 'Sent to the pharmacist' : _subtitles[current],
          maxWidth: 1180,
          breadcrumbs: [
            const Crumb('Patients', '/patients'),
            Crumb(p.displayName, '/patients/${p.id}'),
            Crumb(p.labelOf(c)),
          ],
          children: [
            OnboardingStepper(cycleRef: ref, current: current),
            const SizedBox(height: 24),
            body,
          ],
        );
      },
    );
  }
}

/// Numbered step header; completed steps can be reopened.
class OnboardingStepper extends StatelessWidget {
  const OnboardingStepper({super.key, required this.cycleRef, required this.current});

  final CycleRef cycleRef;
  final OnboardingStage current;

  CycleRecord get _c => cycleRef.cycle;

  bool _done(OnboardingStage s) => switch (s) {
        OnboardingStage.treatment => cycleRef.patient.profile.isComplete && _c.intake.isComplete,
        OnboardingStage.session => _c.session.completed,
        OnboardingStage.processing => !_c.needsProcessing,
        _ => _c.isSent,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = OnboardingStage.steps;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(width: 24, height: 2, color: _done(steps[i - 1]) ? cs.primary : cs.outlineVariant),
          Expanded(child: _item(context, i + 1, steps[i])),
        ],
      ]),
    );
  }

  Widget _item(BuildContext context, int n, OnboardingStage s) {
    final cs = Theme.of(context).colorScheme;
    final active = s == current;
    final done = _done(s) && !active;
    final enabled = !active && !_c.isSent && _c.canOpen(s, cycleRef.patient.profile);
    final circleColor = active ? cs.primary : (done ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = active ? cs.onPrimary : (done ? cs.onPrimaryContainer : cs.onSurfaceVariant);
    return Semantics(
      button: enabled,
      selected: active,
      label: 'Step $n: ${s.label}',
      child: InkWell(
        key: Key('onboarding-step-${s.path}'),
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => context.go(OnboardingPage.path(_c.id, s)) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: fg)
                  : Text('$n', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                s.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active || done ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Back / secondary / primary buttons under each step.
class StepFooter extends StatelessWidget {
  const StepFooter({super.key, this.back, this.secondary, required this.primary});

  final Widget? back;
  final Widget? secondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          back ?? const SizedBox.shrink(),
          Wrap(spacing: 12, runSpacing: 12, children: [if (secondary != null) secondary!, primary]),
        ],
      ),
    );
  }
}

/// Fixed-width slot so form fields flow in a [Wrap].
class FieldSlot extends StatelessWidget {
  const FieldSlot({super.key, this.width = 240, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}
