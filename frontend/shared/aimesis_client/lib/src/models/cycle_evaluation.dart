import 'json_helpers.dart';
import 'plan.dart';

/// Result of `POST /cycles/evaluate`: the rule-based plan plus an optional
/// Gemini summary. [aiError] is set when the AI step failed (the plan is still valid).
class CycleEvaluation {
  final Plan plan;
  final String? aiSummary;
  final String? familyExplanation;
  final String? aiModel;
  final String? aiError;

  const CycleEvaluation({
    required this.plan,
    this.aiSummary,
    this.familyExplanation,
    this.aiModel,
    this.aiError,
  });

  bool get hasAi => aiSummary != null && aiSummary!.trim().isNotEmpty;

  factory CycleEvaluation.fromJson(Map<String, dynamic> json) {
    final ai = mapOrNull(json['ai']);
    return CycleEvaluation(
      plan: Plan.fromJson(mapOrNull(json['plan']) ?? const <String, dynamic>{}),
      aiSummary: ai == null ? null : strOrNull(ai['summary']),
      familyExplanation: ai == null ? null : strOrNull(ai['familyExplanation']),
      aiModel: ai == null ? null : strOrNull(ai['model']),
      aiError: strOrNull(json['aiError']),
    );
  }
}
