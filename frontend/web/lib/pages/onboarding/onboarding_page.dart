import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import 'processing_step.dart';
import 'review_step.dart';
import 'session_step.dart';
import 'treatment_step.dart';

/// `/onboarding/:id/:step` — the four-step flow for a new patient.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.draftId, required this.step});

  final String draftId;
  final OnboardingStage step;

  static String path(String id, OnboardingStage s) =>
      '/onboarding/$id/${(s == OnboardingStage.sent ? OnboardingStage.review : s).path}';

  static const _subtitles = {
    OnboardingStage.treatment: 'Session 1 · Prepare the chemotherapy and basic patient details',
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
        final draft = store.byId(draftId);
        if (draft == null) {
          return PageFrame(title: 'New patient', children: [
            const EmptyView(
              icon: Icons.person_search_outlined,
              title: 'Onboarding not found',
              message: 'It may have been discarded, or it was started in another browser tab.',
            ),
            Center(
              child: FilledButton.tonal(onPressed: () => context.go('/patients'), child: const Text('Back to patients')),
            ),
          ]);
        }

        // Sent drafts only show the (read-only) review. Otherwise fall back to
        // the furthest step that can be opened.
        var current = draft.isSent ? OnboardingStage.review : step;
        if (!draft.isSent && !draft.canOpen(current)) {
          current = OnboardingStage.steps.lastWhere(draft.canOpen);
        }
        if (current != step) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(path(draftId, current));
          });
        }

        final Widget body = switch (current) {
          OnboardingStage.treatment => TreatmentStep(key: ValueKey('treatment-$draftId'), draft: draft),
          OnboardingStage.session => SessionStep(key: ValueKey('session-$draftId'), draft: draft),
          OnboardingStage.processing => ProcessingStep(key: ValueKey('processing-$draftId'), draft: draft),
          _ => ReviewStep(key: ValueKey('review-$draftId'), draft: draft),
        };

        final named = draft.intake.alias.trim().isNotEmpty;
        return PageFrame(
          title: draft.isSent ? draft.displayName : (named ? 'New patient · ${draft.displayName}' : 'New patient'),
          subtitle: draft.isSent ? 'Onboarding complete · sent to the pharmacist' : _subtitles[current],
          maxWidth: 1180,
          children: [
            OnboardingStepper(draft: draft, current: current),
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
  const OnboardingStepper({super.key, required this.draft, required this.current});

  final OnboardingDraft draft;
  final OnboardingStage current;

  bool _done(OnboardingStage s) => switch (s) {
        OnboardingStage.treatment => draft.intake.isComplete,
        OnboardingStage.session => draft.session.completed,
        OnboardingStage.processing => !draft.needsProcessing,
        _ => draft.isSent,
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
    final enabled = !active && !draft.isSent && draft.canOpen(s);
    final circleColor = active ? cs.primary : (done ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = active ? cs.onPrimary : (done ? cs.onPrimaryContainer : cs.onSurfaceVariant);
    return Semantics(
      button: enabled,
      selected: active,
      label: 'Step $n: ${s.label}',
      child: InkWell(
        key: Key('onboarding-step-${s.path}'),
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => context.go(OnboardingPage.path(draft.id, s)) : null,
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
