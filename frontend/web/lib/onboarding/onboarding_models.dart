import 'package:aimesis_client/aimesis_client.dart';

/// Where a new patient is in the onboarding flow.
///
/// treatment → session → processing → review → sent
enum OnboardingStage {
  treatment('treatment', 'Treatment & patient'),
  session('session', 'Patient session'),
  processing('processing', 'Processing'),
  review('review', 'Review & approve'),
  sent('sent', 'Sent to pharmacist');

  const OnboardingStage(this.path, this.label);
  final String path;
  final String label;

  /// The four steps shown in the stepper (sent is a state, not a step).
  static const steps = [treatment, session, processing, review];

  static OnboardingStage fromPath(String? p) =>
      values.firstWhere((s) => s.path == p, orElse: () => treatment);

  static OnboardingStage fromName(String? n) =>
      values.firstWhere((s) => s.name == n, orElse: () => treatment);
}

/// Session 1 — the doctor prepares: chemotherapy and basic patient details.
class PatientIntake {
  String alias;
  int? age;
  String? sex;
  double? weightKg;
  double? heightCm;
  String language;
  String diagnosis;
  String? diagnosisGroup;
  String protocol;
  String cycle;
  DateTime? cycleStart;
  bool firstCycle;
  List<ChemoRow> chemo;
  List<String> activeMeds;

  PatientIntake({
    this.alias = '',
    this.age,
    this.sex,
    this.weightKg,
    this.heightCm,
    this.language = 'nl',
    this.diagnosis = '',
    this.diagnosisGroup,
    this.protocol = '',
    this.cycle = '',
    this.cycleStart,
    this.firstCycle = true,
    List<ChemoRow>? chemo,
    List<String>? activeMeds,
  })  : chemo = chemo ?? [],
        activeMeds = activeMeds ?? [];

  /// Enough to move on to the patient session.
  bool get isComplete =>
      alias.trim().isNotEmpty &&
      age != null &&
      weightKg != null &&
      heightCm != null &&
      diagnosis.trim().isNotEmpty &&
      chemo.isNotEmpty &&
      chemo.every((c) => c.drug.trim().isNotEmpty && c.doseMgM2 > 0 && c.days.isNotEmpty);

  List<int> get chemoDays => (chemo.expand((c) => c.days).toSet().toList()..sort());

  factory PatientIntake.fromJson(Map<String, dynamic> j) => PatientIntake(
        alias: (j['alias'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex'] as String?,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        language: (j['language'] as String?) ?? 'nl',
        diagnosis: (j['diagnosis'] as String?) ?? '',
        diagnosisGroup: j['diagnosisGroup'] as String?,
        protocol: (j['protocol'] as String?) ?? '',
        cycle: (j['cycle'] as String?) ?? '',
        cycleStart: j['cycleStart'] == null ? null : DateTime.tryParse(j['cycleStart'] as String),
        firstCycle: (j['firstCycle'] as bool?) ?? true,
        chemo: [
          for (final c in (j['chemo'] as List? ?? const []))
            ChemoRow.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        activeMeds: [for (final m in (j['activeMeds'] as List? ?? const [])) m as String],
      );

  Map<String, dynamic> toJson() => {
        'alias': alias,
        'age': age,
        'sex': sex,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'language': language,
        'diagnosis': diagnosis,
        'diagnosisGroup': diagnosisGroup,
        'protocol': protocol,
        'cycle': cycle,
        'cycleStart': cycleStart?.toIso8601String().substring(0, 10),
        'firstCycle': firstCycle,
        'chemo': chemo.map((c) => c.toJson()).toList(),
        'activeMeds': activeMeds,
      };
}

/// Session 2 — filled in by the doctor together with the patient and family.
class PatientSession {
  Set<String> present;
  bool canSwallowTablets;
  String preferredRoute;
  bool anticipatory;
  String priorNausea;
  String formulationPreference;
  String whatHelps;
  String concerns;
  bool completed;

  PatientSession({
    Set<String>? present,
    this.canSwallowTablets = true,
    this.preferredRoute = DoseRoute.oralTablet,
    this.anticipatory = false,
    this.priorNausea = '',
    this.formulationPreference = '',
    this.whatHelps = '',
    this.concerns = '',
    this.completed = false,
  }) : present = present ?? {};

  static const presentOptions = {
    'patient': 'Patient',
    'parent': 'Parent / carer',
    'nurse': 'Nurse specialist',
  };

  RiskFactors toRiskFactors() => RiskFactors(
        canSwallowTablets: canSwallowTablets,
        preferredRoute: preferredRoute,
        anticipatory: anticipatory,
        priorNauseaNote: priorNausea.trim().isEmpty ? null : priorNausea.trim(),
      );

  factory PatientSession.fromJson(Map<String, dynamic> j) => PatientSession(
        present: {for (final p in (j['present'] as List? ?? const [])) p as String},
        canSwallowTablets: (j['canSwallowTablets'] as bool?) ?? true,
        preferredRoute: (j['preferredRoute'] as String?) ?? DoseRoute.oralTablet,
        anticipatory: (j['anticipatory'] as bool?) ?? false,
        priorNausea: (j['priorNausea'] as String?) ?? '',
        formulationPreference: (j['formulationPreference'] as String?) ?? '',
        whatHelps: (j['whatHelps'] as String?) ?? '',
        concerns: (j['concerns'] as String?) ?? '',
        completed: (j['completed'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'present': present.toList(),
        'canSwallowTablets': canSwallowTablets,
        'preferredRoute': preferredRoute,
        'anticipatory': anticipatory,
        'priorNausea': priorNausea,
        'formulationPreference': formulationPreference,
        'whatHelps': whatHelps,
        'concerns': concerns,
        'completed': completed,
      };
}

/// What one model contributed to the suggestion.
class ModelOutput {
  final String key;
  final String title;
  final String summary;
  final List<String> details;
  final String source;

  const ModelOutput({
    required this.key,
    required this.title,
    required this.summary,
    this.details = const [],
    this.source = '',
  });

  factory ModelOutput.fromJson(Map<String, dynamic> j) => ModelOutput(
        key: j['key'] as String,
        title: j['title'] as String,
        summary: (j['summary'] as String?) ?? '',
        details: [for (final d in (j['details'] as List? ?? const [])) d as String],
        source: (j['source'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'title': title, 'summary': summary, 'details': details, 'source': source};
}

/// One line of the suggested antiemetic plan.
class SuggestedLine {
  final String drug;
  final String route;
  final List<int> days;

  /// Null until the dosing model provides it.
  final String? dose;
  final String? note;

  const SuggestedLine({required this.drug, required this.route, this.days = const [], this.dose, this.note});

  factory SuggestedLine.fromJson(Map<String, dynamic> j) => SuggestedLine(
        drug: j['drug'] as String,
        route: j['route'] as String,
        days: [for (final d in (j['days'] as List? ?? const [])) (d as num).toInt()],
        dose: j['dose'] as String?,
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {'drug': drug, 'route': route, 'days': days, 'dose': dose, 'note': note};
}

/// The combined output of all models, for the doctor to review.
class Suggestion {
  /// Null until the emetogenicity model provides it.
  final String? overallTier;
  final List<SuggestedLine> antiemetics;
  final List<ModelOutput> outputs;
  final DateTime generatedAt;

  /// True while the output comes from the placeholder engine.
  final bool placeholder;

  const Suggestion({
    this.overallTier,
    this.antiemetics = const [],
    this.outputs = const [],
    required this.generatedAt,
    this.placeholder = false,
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        overallTier: j['overallTier'] as String?,
        antiemetics: [
          for (final l in (j['antiemetics'] as List? ?? const []))
            SuggestedLine.fromJson(Map<String, dynamic>.from(l as Map)),
        ],
        outputs: [
          for (final o in (j['outputs'] as List? ?? const []))
            ModelOutput.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
        generatedAt: DateTime.tryParse((j['generatedAt'] as String?) ?? '') ?? DateTime.now(),
        placeholder: (j['placeholder'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'overallTier': overallTier,
        'antiemetics': antiemetics.map((l) => l.toJson()).toList(),
        'outputs': outputs.map((o) => o.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'placeholder': placeholder,
      };
}

/// One new patient going through onboarding.
class OnboardingDraft {
  final String id;
  final DateTime createdAt;
  final String createdBy;
  DateTime updatedAt;
  OnboardingStage stage;
  PatientIntake intake;
  PatientSession session;
  Suggestion? suggestion;

  /// Bumped whenever inputs change, so a stale suggestion is re-run.
  int inputsVersion;
  int? processedVersion;

  String reviewNote;
  String? approvedBy;
  DateTime? approvedAt;

  OnboardingDraft({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    DateTime? updatedAt,
    this.stage = OnboardingStage.treatment,
    PatientIntake? intake,
    PatientSession? session,
    this.suggestion,
    this.inputsVersion = 0,
    this.processedVersion,
    this.reviewNote = '',
    this.approvedBy,
    this.approvedAt,
  })  : updatedAt = updatedAt ?? createdAt,
        intake = intake ?? PatientIntake(),
        session = session ?? PatientSession();

  bool get isSent => stage == OnboardingStage.sent;
  bool get needsProcessing => suggestion == null || processedVersion != inputsVersion;
  String get displayName => intake.alias.trim().isEmpty ? 'New patient' : intake.alias.trim();

  /// Whether the stepper may jump to [step].
  bool canOpen(OnboardingStage step) => switch (step) {
        OnboardingStage.treatment => true,
        OnboardingStage.session => intake.isComplete,
        OnboardingStage.processing => intake.isComplete && session.completed,
        OnboardingStage.review || OnboardingStage.sent => suggestion != null && !needsProcessing,
      };

  /// Inputs changed: any existing suggestion is now out of date.
  void touchInputs() => inputsVersion++;

  factory OnboardingDraft.fromJson(Map<String, dynamic> j) => OnboardingDraft(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        createdBy: (j['createdBy'] as String?) ?? '',
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        stage: OnboardingStage.fromName(j['stage'] as String?),
        intake: PatientIntake.fromJson(Map<String, dynamic>.from((j['intake'] as Map?) ?? const {})),
        session: PatientSession.fromJson(Map<String, dynamic>.from((j['session'] as Map?) ?? const {})),
        suggestion: j['suggestion'] == null
            ? null
            : Suggestion.fromJson(Map<String, dynamic>.from(j['suggestion'] as Map)),
        inputsVersion: (j['inputsVersion'] as num?)?.toInt() ?? 0,
        processedVersion: (j['processedVersion'] as num?)?.toInt(),
        reviewNote: (j['reviewNote'] as String?) ?? '',
        approvedBy: j['approvedBy'] as String?,
        approvedAt: j['approvedAt'] == null ? null : DateTime.tryParse(j['approvedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedAt': updatedAt.toIso8601String(),
        'stage': stage.name,
        'intake': intake.toJson(),
        'session': session.toJson(),
        'suggestion': suggestion?.toJson(),
        'inputsVersion': inputsVersion,
        'processedVersion': processedVersion,
        'reviewNote': reviewNote,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
      };
}

/// "1-3, 8" / "1,2,3" / "1–3" → [1, 2, 3, 8]. Null when it can't be read.
List<int>? parseDays(String text) {
  final out = <int>{};
  for (final raw in text.split(RegExp(r'[,;\s]+'))) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    final range = RegExp(r'^(\d+)\s*[-–]\s*(\d+)$').firstMatch(part);
    if (range != null) {
      final a = int.parse(range.group(1)!), b = int.parse(range.group(2)!);
      if (a < 1 || b < a || b > 60) return null;
      for (var d = a; d <= b; d++) {
        out.add(d);
      }
      continue;
    }
    final n = int.tryParse(part);
    if (n == null || n < 1 || n > 60) return null;
    out.add(n);
  }
  return out.isEmpty ? null : (out.toList()..sort());
}

/// [1, 2, 3, 8] → "1–3, 8".
String daysText(List<int> days) {
  if (days.isEmpty) return '';
  final s = [...days]..sort();
  final parts = <String>[];
  var start = s.first, prev = s.first;
  for (final d in s.skip(1)) {
    if (d == prev + 1) {
      prev = d;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start–$prev');
    start = prev = d;
  }
  parts.add(start == prev ? '$start' : '$start–$prev');
  return parts.join(', ');
}
