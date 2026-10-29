import 'package:aimesis_client/aimesis_client.dart';

/// Where a new patient is in the onboarding flow.
///
/// treatment → session → processing → review → sent
enum OnboardingStage {
  treatment('treatment', 'Treatment'),
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

/// What stays the same across cycles: who the patient is and their lasting
/// preferences.
class PatientProfile {
  String alias;
  int? age;
  String? sex;
  String language;
  String diagnosis;
  String? diagnosisGroup;
  String formulationPreference;
  String whatHelps;

  PatientProfile({
    this.alias = '',
    this.age,
    this.sex,
    this.language = 'nl',
    this.diagnosis = '',
    this.diagnosisGroup,
    this.formulationPreference = '',
    this.whatHelps = '',
  });

  bool get isComplete => alias.trim().isNotEmpty && age != null && diagnosis.trim().isNotEmpty;

  factory PatientProfile.fromApi(Patient p) => PatientProfile(
        alias: p.alias,
        age: p.age,
        sex: p.sex,
        language: p.language ?? 'nl',
        diagnosis: p.diagnosis ?? '',
        diagnosisGroup: p.diagnosisGroup,
      );

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
        alias: (j['alias'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex'] as String?,
        language: (j['language'] as String?) ?? 'nl',
        diagnosis: (j['diagnosis'] as String?) ?? '',
        diagnosisGroup: j['diagnosisGroup'] as String?,
        formulationPreference: (j['formulationPreference'] as String?) ?? '',
        whatHelps: (j['whatHelps'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'alias': alias,
        'age': age,
        'sex': sex,
        'language': language,
        'diagnosis': diagnosis,
        'diagnosisGroup': diagnosisGroup,
        'formulationPreference': formulationPreference,
        'whatHelps': whatHelps,
      };
}

/// Session 1 for one cycle — the doctor prepares the chemotherapy.
/// Weight and height are per cycle because children grow between cycles.
class CycleIntake {
  String protocol;
  String cycle;
  DateTime? cycleStart;
  double? weightKg;
  double? heightCm;

  /// Only asked on a patient's first recorded cycle.
  bool firstCycle;
  List<ChemoRow> chemo;
  List<String> activeMeds;

  CycleIntake({
    this.protocol = '',
    this.cycle = '',
    this.cycleStart,
    this.weightKg,
    this.heightCm,
    this.firstCycle = true,
    List<ChemoRow>? chemo,
    List<String>? activeMeds,
  })  : chemo = chemo ?? [],
        activeMeds = activeMeds ?? [];

  bool get isComplete =>
      weightKg != null &&
      heightCm != null &&
      chemo.isNotEmpty &&
      chemo.every((c) => c.drug.trim().isNotEmpty && c.doseMgM2 > 0 && c.days.isNotEmpty);

  List<int> get chemoDays => (chemo.expand((c) => c.days).toSet().toList()..sort());

  factory CycleIntake.fromJson(Map<String, dynamic> j) => CycleIntake(
        protocol: (j['protocol'] as String?) ?? '',
        cycle: (j['cycle'] as String?) ?? '',
        cycleStart: j['cycleStart'] == null ? null : DateTime.tryParse(j['cycleStart'] as String),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        firstCycle: (j['firstCycle'] as bool?) ?? true,
        chemo: [
          for (final c in (j['chemo'] as List? ?? const []))
            ChemoRow.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        activeMeds: [for (final m in (j['activeMeds'] as List? ?? const [])) m as String],
      );

  Map<String, dynamic> toJson() => {
        'protocol': protocol,
        'cycle': cycle,
        'cycleStart': cycleStart?.toIso8601String().substring(0, 10),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'firstCycle': firstCycle,
        'chemo': chemo.map((c) => c.toJson()).toList(),
        'activeMeds': activeMeds,
      };
}

/// Session 2 for one cycle — filled in with the patient and family.
/// Route and swallowing can change between cycles, so they live here.
class CycleSession {
  Set<String> present;
  bool canSwallowTablets;
  String preferredRoute;
  bool anticipatory;
  String priorNausea;
  String concerns;
  bool completed;

  CycleSession({
    Set<String>? present,
    this.canSwallowTablets = true,
    this.preferredRoute = DoseRoute.oralTablet,
    this.anticipatory = false,
    this.priorNausea = '',
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

  factory CycleSession.fromJson(Map<String, dynamic> j) => CycleSession(
        present: {for (final p in (j['present'] as List? ?? const [])) p as String},
        canSwallowTablets: (j['canSwallowTablets'] as bool?) ?? true,
        preferredRoute: (j['preferredRoute'] as String?) ?? DoseRoute.oralTablet,
        anticipatory: (j['anticipatory'] as bool?) ?? false,
        priorNausea: (j['priorNausea'] as String?) ?? '',
        concerns: (j['concerns'] as String?) ?? '',
        completed: (j['completed'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'present': present.toList(),
        'canSwallowTablets': canSwallowTablets,
        'preferredRoute': preferredRoute,
        'anticipatory': anticipatory,
        'priorNausea': priorNausea,
        'concerns': concerns,
        'completed': completed,
      };
}

/// A cycle from the existing patient record (API), shown read-only in the
/// history. Cycles added here are [CycleRecord]s instead.
class PriorCycle {
  final String label;
  final String? date;
  final String summary;
  final String note;

  /// The API record's current cycle: its plan opens in the workspace.
  final bool current;

  const PriorCycle({required this.label, this.date, this.summary = '', this.note = '', this.current = false});

  factory PriorCycle.fromJson(Map<String, dynamic> j) => PriorCycle(
        label: (j['label'] as String?) ?? '',
        date: j['date'] as String?,
        summary: (j['summary'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        current: (j['current'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'label': label, 'date': date, 'summary': summary, 'note': note, 'current': current};
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

  /// Gemini summary for the clinician and plain-language family explanation.
  final String? aiSummary;
  final String? familyExplanation;
  final String? aiModel;

  /// Why the AI step failed (the rule-based plan is still valid).
  final String? aiError;

  /// Set when dexamethasone is contraindicated for this cycle.
  final String? dexBlockedReason;
  final bool dexBlocked;

  /// The models refused to suggest a plan (e.g. unknown drugs).
  final bool refused;
  final String? refusalReason;

  /// Critical drug–drug interactions, shown above everything else.
  final List<String> criticalInteractions;

  const Suggestion({
    this.overallTier,
    this.antiemetics = const [],
    this.outputs = const [],
    required this.generatedAt,
    this.placeholder = false,
    this.aiSummary,
    this.familyExplanation,
    this.aiModel,
    this.aiError,
    this.dexBlocked = false,
    this.dexBlockedReason,
    this.refused = false,
    this.refusalReason,
    this.criticalInteractions = const [],
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
        aiSummary: j['aiSummary'] as String?,
        familyExplanation: j['familyExplanation'] as String?,
        aiModel: j['aiModel'] as String?,
        aiError: j['aiError'] as String?,
        dexBlocked: (j['dexBlocked'] as bool?) ?? false,
        dexBlockedReason: j['dexBlockedReason'] as String?,
        refused: (j['refused'] as bool?) ?? false,
        refusalReason: j['refusalReason'] as String?,
        criticalInteractions: [
          for (final c in (j['criticalInteractions'] as List? ?? const [])) c as String,
        ],
      );

  Map<String, dynamic> toJson() => {
        'overallTier': overallTier,
        'antiemetics': antiemetics.map((l) => l.toJson()).toList(),
        'outputs': outputs.map((o) => o.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'placeholder': placeholder,
        'aiSummary': aiSummary,
        'familyExplanation': familyExplanation,
        'aiModel': aiModel,
        'aiError': aiError,
        'dexBlocked': dexBlocked,
        'dexBlockedReason': dexBlockedReason,
        'refused': refused,
        'refusalReason': refusalReason,
        'criticalInteractions': criticalInteractions,
      };
}

/// One chemotherapy cycle going through the four steps, and its outcome.
class CycleRecord {
  final String id;
  final String patientId;
  final DateTime createdAt;
  final String createdBy;
  DateTime updatedAt;
  OnboardingStage stage;
  CycleIntake intake;
  CycleSession session;
  Suggestion? suggestion;

  /// Bumped whenever inputs change, so a stale suggestion is re-run.
  int inputsVersion;
  int? processedVersion;

  String reviewNote;
  String? approvedBy;
  DateTime? approvedAt;

  CycleRecord({
    required this.id,
    required this.patientId,
    required this.createdAt,
    required this.createdBy,
    DateTime? updatedAt,
    this.stage = OnboardingStage.treatment,
    CycleIntake? intake,
    CycleSession? session,
    this.suggestion,
    this.inputsVersion = 0,
    this.processedVersion,
    this.reviewNote = '',
    this.approvedBy,
    this.approvedAt,
  })  : updatedAt = updatedAt ?? createdAt,
        intake = intake ?? CycleIntake(),
        session = session ?? CycleSession();

  bool get isSent => stage == OnboardingStage.sent;
  bool get needsProcessing => suggestion == null || processedVersion != inputsVersion;

  /// Inputs changed: any existing suggestion is now out of date.
  void touchInputs() => inputsVersion++;

  /// Whether the stepper may jump to [step].
  bool canOpen(OnboardingStage step, PatientProfile profile) {
    final ready = profile.isComplete && intake.isComplete;
    return switch (step) {
      OnboardingStage.treatment => true,
      OnboardingStage.session => ready,
      OnboardingStage.processing => ready && session.completed,
      OnboardingStage.review || OnboardingStage.sent => suggestion != null && !needsProcessing,
    };
  }

  factory CycleRecord.fromJson(Map<String, dynamic> j) => CycleRecord(
        id: j['id'] as String,
        patientId: j['patientId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        createdBy: (j['createdBy'] as String?) ?? '',
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        stage: OnboardingStage.fromName(j['stage'] as String?),
        intake: CycleIntake.fromJson(Map<String, dynamic>.from((j['intake'] as Map?) ?? const {})),
        session: CycleSession.fromJson(Map<String, dynamic>.from((j['session'] as Map?) ?? const {})),
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
        'patientId': patientId,
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

/// One patient profile holding every cycle: cycles from the existing record
/// ([imported], API patients only) followed by cycles added here ([cycles]).
class PatientRecord {
  final String id;
  final DateTime createdAt;

  /// True for patients created here; false for API patients that got a new
  /// cycle here.
  final bool isLocal;
  PatientProfile profile;
  List<PriorCycle> imported;
  List<CycleRecord> cycles;

  PatientRecord({
    required this.id,
    required this.createdAt,
    required this.isLocal,
    PatientProfile? profile,
    List<PriorCycle>? imported,
    List<CycleRecord>? cycles,
  })  : profile = profile ?? PatientProfile(),
        imported = imported ?? [],
        cycles = cycles ?? [];

  String get displayName => profile.alias.trim().isEmpty ? 'New patient' : profile.alias.trim();
  CycleRecord? get latest => cycles.isEmpty ? null : cycles.last;
  CycleRecord? get inProgress => cycles.where((c) => !c.isSent).lastOrNull;
  DateTime get lastActivity =>
      cycles.isEmpty ? createdAt : cycles.map((c) => c.approvedAt ?? c.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Total cycles on the profile, including imported history.
  int get cycleCount => imported.length + cycles.length;

  /// 1-based position of [c] across the whole history.
  int numberOf(CycleRecord c) => imported.length + cycles.indexWhere((x) => x.id == c.id) + 1;

  /// Cycles before [c] (added here); imported ones come before all of them.
  List<CycleRecord> before(CycleRecord c) => cycles.takeWhile((x) => x.id != c.id).toList();

  /// Whether [c] is the patient's first cycle on the profile.
  bool isFirst(CycleRecord c) => imported.isEmpty && cycles.isNotEmpty && cycles.first.id == c.id;

  String labelOf(CycleRecord c) =>
      c.intake.cycle.trim().isEmpty ? 'Cycle ${numberOf(c)}' : 'Cycle ${c.intake.cycle.trim()}';

  factory PatientRecord.fromJson(Map<String, dynamic> j) => PatientRecord(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isLocal: (j['isLocal'] as bool?) ?? true,
        profile: PatientProfile.fromJson(Map<String, dynamic>.from((j['profile'] as Map?) ?? const {})),
        imported: [
          for (final c in (j['imported'] as List? ?? const []))
            PriorCycle.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        cycles: [
          for (final c in (j['cycles'] as List? ?? const []))
            CycleRecord.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'isLocal': isLocal,
        'profile': profile.toJson(),
        'imported': imported.map((c) => c.toJson()).toList(),
        'cycles': cycles.map((c) => c.toJson()).toList(),
      };
}

/// A cycle together with its patient — what the flow screens work on.
typedef CycleRef = ({PatientRecord patient, CycleRecord cycle});

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
