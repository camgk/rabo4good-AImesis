import 'json_helpers.dart';
import 'tier.dart';

/// Per-drug emetogenicity classification.
class DrugTier {
  final String drug;
  final double? doseMgM2;
  final String tier;
  final String rule;
  final String source;

  const DrugTier({
    required this.drug,
    this.doseMgM2,
    required this.tier,
    this.rule = '',
    this.source = '',
  });

  factory DrugTier.fromJson(Map<String, dynamic> json) => DrugTier(
        drug: str(json['drug']),
        doseMgM2: dblOrNull(json['doseMgM2']),
        tier: str(json['tier']),
        rule: str(json['rule']),
        source: str(json['source']),
      );

  Map<String, dynamic> toJson() => {
        'drug': drug,
        'doseMgM2': doseMgM2,
        'tier': tier,
        'rule': rule,
        'source': source,
      };

  int get tierRank => Tier.rank(tier);
}

/// Tier for one chemo day.
class DayTier {
  final int day;
  final String tier;
  final List<String> drugs;

  const DayTier({required this.day, required this.tier, this.drugs = const []});

  factory DayTier.fromJson(Map<String, dynamic> json) => DayTier(
        day: integer(json['day'], 1),
        tier: str(json['tier']),
        drugs: strList(json['drugs']),
      );

  Map<String, dynamic> toJson() => {'day': day, 'tier': tier, 'drugs': drugs};

  int get tierRank => Tier.rank(tier);
}

/// A rule reference (combination rules).
class RuleRef {
  final String rule;
  final String source;

  const RuleRef({required this.rule, this.source = ''});

  factory RuleRef.fromJson(Map<String, dynamic> json) =>
      RuleRef(rule: str(json['rule']), source: str(json['source']));

  Map<String, dynamic> toJson() => {'rule': rule, 'source': source};
}

/// Dexamethasone block status.
class DexStatus {
  final bool blocked;
  final String? reason;
  final String source;

  const DexStatus({this.blocked = false, this.reason, this.source = ''});

  factory DexStatus.fromJson(Map<String, dynamic> json) => DexStatus(
        blocked: boolean(json['blocked']),
        reason: strOrNull(json['reason']),
        source: str(json['source']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'blocked': blocked};
    putIfNotNull(m, 'reason', reason);
    m['source'] = source;
    return m;
  }
}

/// A dose line: used for both `antiemetics` and `breakthrough` (breakthrough has no days/steps).
class AntiemeticLine {
  final String drug;
  final double? doseMg;
  final String unit;
  final String frequency;
  final String route;
  final List<int> days;
  final String formula;
  final List<String> steps;
  final String source;
  final List<String> notes;

  const AntiemeticLine({
    required this.drug,
    this.doseMg,
    this.unit = 'mg',
    this.frequency = '',
    this.route = '',
    this.days = const [],
    this.formula = '',
    this.steps = const [],
    this.source = '',
    this.notes = const [],
  });

  factory AntiemeticLine.fromJson(Map<String, dynamic> json) => AntiemeticLine(
        drug: str(json['drug']),
        doseMg: dblOrNull(json['doseMg']),
        unit: str(json['unit'], 'mg'),
        frequency: str(json['frequency']),
        route: str(json['route']),
        days: intList(json['days']),
        formula: str(json['formula']),
        steps: strList(json['steps']),
        source: str(json['source']),
        notes: strList(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'drug': drug,
        'doseMg': doseMg,
        'unit': unit,
        'frequency': frequency,
        'route': route,
        'days': days,
        'formula': formula,
        'steps': steps,
        'source': source,
        'notes': notes,
      };

  /// e.g. "7.6 mg" (trailing ".0" dropped), or "" when no dose.
  String get doseLabel {
    final d = doseMg;
    if (d == null) return '';
    final s = d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
    return '$s $unit';
  }

  String get routeLabel => DoseRoute.label(route);

  /// e.g. "Days 1–2", "Day 1", or "" when no days.
  String get daysLabel {
    if (days.isEmpty) return '';
    if (days.length == 1) return 'Day ${days.first}';
    final sorted = [...days]..sort();
    final contiguous = sorted.last - sorted.first == sorted.length - 1;
    return contiguous
        ? 'Days ${sorted.first}–${sorted.last}'
        : 'Days ${sorted.join(', ')}';
  }
}

class Alternative {
  final String title;
  final String detail;
  final String source;

  const Alternative({required this.title, this.detail = '', this.source = ''});

  factory Alternative.fromJson(Map<String, dynamic> json) => Alternative(
        title: str(json['title']),
        detail: str(json['detail']),
        source: str(json['source']),
      );

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail, 'source': source};
}

class StepUp {
  final String title;
  final String reason;
  final String source;

  const StepUp({required this.title, this.reason = '', this.source = ''});

  factory StepUp.fromJson(Map<String, dynamic> json) => StepUp(
        title: str(json['title']),
        reason: str(json['reason']),
        source: str(json['source']),
      );

  Map<String, dynamic> toJson() => {'title': title, 'reason': reason, 'source': source};
}

/// Drug–drug interaction / contraindication alert.
class Interaction {
  final String severity;
  final List<String> drugs;
  final String message;
  final String? alternative;
  final String source;

  const Interaction({
    required this.severity,
    this.drugs = const [],
    this.message = '',
    this.alternative,
    this.source = '',
  });

  factory Interaction.fromJson(Map<String, dynamic> json) => Interaction(
        severity: str(json['severity'], Severity.info),
        drugs: strList(json['drugs']),
        message: str(json['message']),
        alternative: strOrNull(json['alternative']),
        source: str(json['source']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'severity': severity,
      'drugs': drugs,
      'message': message,
    };
    putIfNotNull(m, 'alternative', alternative);
    m['source'] = source;
    return m;
  }

  bool get isCritical => severity == Severity.critical;
  bool get isWarning => severity == Severity.warning;
  bool get isInfo => severity == Severity.info;
  int get severityRank => Severity.rank(severity);
}

/// One UZA v2 vs POGO comparison row.
class PogoRow {
  final String item;
  final String uzaTier;
  final String pogoTier;
  final bool differs;
  final String note;

  const PogoRow({
    required this.item,
    required this.uzaTier,
    required this.pogoTier,
    this.differs = false,
    this.note = '',
  });

  factory PogoRow.fromJson(Map<String, dynamic> json) => PogoRow(
        item: str(json['item']),
        uzaTier: str(json['uzaTier']),
        pogoTier: str(json['pogoTier']),
        differs: boolean(json['differs']),
        note: str(json['note']),
      );

  Map<String, dynamic> toJson() => {
        'item': item,
        'uzaTier': uzaTier,
        'pogoTier': pogoTier,
        'differs': differs,
        'note': note,
      };
}

/// Episode counts for one cycle day.
class DaySummary {
  final int day;
  final int nausea;
  final int vomiting;

  const DaySummary({required this.day, this.nausea = 0, this.vomiting = 0});

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        day: integer(json['day'], 1),
        nausea: integer(json['nausea']),
        vomiting: integer(json['vomiting']),
      );

  Map<String, dynamic> toJson() => {'day': day, 'nausea': nausea, 'vomiting': vomiting};

  int get total => nausea + vomiting;
}

class EpisodesSummary {
  final List<DaySummary> currentCycle;
  final List<int> priorNauseaDays;

  const EpisodesSummary({this.currentCycle = const [], this.priorNauseaDays = const []});

  factory EpisodesSummary.fromJson(Map<String, dynamic> json) => EpisodesSummary(
        currentCycle: objList(json['currentCycle'], DaySummary.fromJson),
        priorNauseaDays: intList(json['priorNauseaDays']),
      );

  Map<String, dynamic> toJson() => {
        'currentCycle': currentCycle.map((e) => e.toJson()).toList(),
        'priorNauseaDays': priorNauseaDays,
      };

  bool get isEmpty => currentCycle.isEmpty && priorNauseaDays.isEmpty;
}

/// A single sign-off (who, when).
class Signoff {
  final String by;

  /// ISO timestamp.
  final String at;

  const Signoff({required this.by, required this.at});

  factory Signoff.fromJson(Map<String, dynamic> json) =>
      Signoff(by: str(json['by']), at: str(json['at']));

  Map<String, dynamic> toJson() => {'by': by, 'at': at};

  DateTime? get atDate => DateTime.tryParse(at);
}

class Signoffs {
  final Signoff? oncologist;
  final Signoff? pharmacist;

  const Signoffs({this.oncologist, this.pharmacist});

  factory Signoffs.fromJson(Map<String, dynamic> json) {
    final o = mapOrNull(json['oncologist']);
    final p = mapOrNull(json['pharmacist']);
    return Signoffs(
      oncologist: o == null ? null : Signoff.fromJson(o),
      pharmacist: p == null ? null : Signoff.fromJson(p),
    );
  }

  Map<String, dynamic> toJson() => {
        'oncologist': oncologist?.toJson(),
        'pharmacist': pharmacist?.toJson(),
      };

  bool get complete => oncologist != null && pharmacist != null;
}

class PlanComment {
  final String by;
  final String role;
  final String at;
  final String text;

  const PlanComment({required this.by, this.role = '', this.at = '', required this.text});

  factory PlanComment.fromJson(Map<String, dynamic> json) => PlanComment(
        by: str(json['by']),
        role: str(json['role']),
        at: str(json['at']),
        text: str(json['text']),
      );

  Map<String, dynamic> toJson() => {'by': by, 'role': role, 'at': at, 'text': text};

  DateTime? get atDate => DateTime.tryParse(at);
}

/// Computed antiemetic plan (`GET /patients/{id}/plan`).
class Plan {
  static const String defaultAdvisory =
      'Advisory only — requires clinician sign-off.';

  final String patientId;
  final String status;
  final bool refused;
  final List<String> refusalReasons;
  final List<DrugTier> drugTiers;
  final List<DayTier> dayTiers;
  final String? overallTier;
  final List<RuleRef> combinationRules;
  final DexStatus dexamethasone;
  final List<AntiemeticLine> antiemetics;
  final List<AntiemeticLine> breakthrough;
  final List<Alternative> alternatives;
  final List<StepUp> stepUps;
  final List<Interaction> interactions;
  final List<PogoRow> uzaVsPogo;
  final EpisodesSummary episodesSummary;
  final Signoffs signoffs;
  final List<PlanComment> comments;
  final String advisory;

  /// Not in the spec shapes but tolerated if the server sends it (refuse-rather-than-guess).
  final List<String> unknownDrugs;

  const Plan({
    required this.patientId,
    this.status = PlanStatus.draft,
    this.refused = false,
    this.refusalReasons = const [],
    this.drugTiers = const [],
    this.dayTiers = const [],
    this.overallTier,
    this.combinationRules = const [],
    this.dexamethasone = const DexStatus(),
    this.antiemetics = const [],
    this.breakthrough = const [],
    this.alternatives = const [],
    this.stepUps = const [],
    this.interactions = const [],
    this.uzaVsPogo = const [],
    this.episodesSummary = const EpisodesSummary(),
    this.signoffs = const Signoffs(),
    this.comments = const [],
    this.advisory = defaultAdvisory,
    this.unknownDrugs = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final dex = mapOrNull(json['dexamethasone']);
    final eps = mapOrNull(json['episodesSummary']);
    final so = mapOrNull(json['signoffs']);
    return Plan(
      patientId: str(json['patientId']),
      status: str(json['status'], PlanStatus.draft),
      refused: boolean(json['refused']),
      refusalReasons: strList(json['refusalReasons']),
      drugTiers: objList(json['drugTiers'], DrugTier.fromJson),
      dayTiers: objList(json['dayTiers'], DayTier.fromJson),
      overallTier: strOrNull(json['overallTier']),
      combinationRules: objList(json['combinationRules'], RuleRef.fromJson),
      dexamethasone: dex == null ? const DexStatus() : DexStatus.fromJson(dex),
      antiemetics: objList(json['antiemetics'], AntiemeticLine.fromJson),
      breakthrough: objList(json['breakthrough'], AntiemeticLine.fromJson),
      alternatives: objList(json['alternatives'], Alternative.fromJson),
      stepUps: objList(json['stepUps'], StepUp.fromJson),
      interactions: objList(json['interactions'], Interaction.fromJson),
      uzaVsPogo: objList(json['uzaVsPogo'], PogoRow.fromJson),
      episodesSummary: eps == null ? const EpisodesSummary() : EpisodesSummary.fromJson(eps),
      signoffs: so == null ? const Signoffs() : Signoffs.fromJson(so),
      comments: objList(json['comments'], PlanComment.fromJson),
      advisory: str(json['advisory'], defaultAdvisory),
      unknownDrugs: strList(json['unknownDrugs']),
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'patientId': patientId,
      'status': status,
      'refused': refused,
      'refusalReasons': refusalReasons,
      'drugTiers': drugTiers.map((e) => e.toJson()).toList(),
      'dayTiers': dayTiers.map((e) => e.toJson()).toList(),
      'overallTier': overallTier,
      'combinationRules': combinationRules.map((e) => e.toJson()).toList(),
      'dexamethasone': dexamethasone.toJson(),
      'antiemetics': antiemetics.map((e) => e.toJson()).toList(),
      'breakthrough': breakthrough.map((e) => e.toJson()).toList(),
      'alternatives': alternatives.map((e) => e.toJson()).toList(),
      'stepUps': stepUps.map((e) => e.toJson()).toList(),
      'interactions': interactions.map((e) => e.toJson()).toList(),
      'uzaVsPogo': uzaVsPogo.map((e) => e.toJson()).toList(),
      'episodesSummary': episodesSummary.toJson(),
      'signoffs': signoffs.toJson(),
      'comments': comments.map((e) => e.toJson()).toList(),
      'advisory': advisory,
    };
    if (unknownDrugs.isNotEmpty) m['unknownDrugs'] = unknownDrugs;
    return m;
  }

  bool get isDraft => status == PlanStatus.draft;
  bool get isAwaitingPharmacist => status == PlanStatus.awaitingPharmacist;
  bool get isApproved => status == PlanStatus.approved;
  bool get isReturned => status == PlanStatus.returned;
  String get statusLabel => PlanStatus.label(status);

  int get tierRank => Tier.rank(overallTier);
  String get tierLabel => Tier.label(overallTier);

  bool get hasCriticalInteraction => interactions.any((i) => i.isCritical);

  /// Interactions sorted critical → warning → info.
  List<Interaction> get interactionsBySeverity =>
      [...interactions]..sort((a, b) => b.severityRank.compareTo(a.severityRank));

  bool get hasPogoDifferences => uzaVsPogo.any((r) => r.differs);
}
