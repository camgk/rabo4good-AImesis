import 'chemo_row.dart';
import 'json_helpers.dart';
import 'tier.dart';

/// List item from `GET /patients` and result of `POST /pairing`.
class PatientSummary {
  final String id;
  final String alias;
  final int? age;
  final String? sex;
  final String? diagnosis;
  final String? protocol;
  final String? cycle;

  /// ISO date (yyyy-MM-dd) as sent by the API.
  final String? cycleStart;
  final String? overallTier;
  final String? planStatus;
  final String? language;

  const PatientSummary({
    required this.id,
    required this.alias,
    this.age,
    this.sex,
    this.diagnosis,
    this.protocol,
    this.cycle,
    this.cycleStart,
    this.overallTier,
    this.planStatus,
    this.language,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
        id: str(json['id']),
        alias: str(json['alias']),
        age: intOrNull(json['age']),
        sex: strOrNull(json['sex']),
        diagnosis: strOrNull(json['diagnosis']),
        protocol: strOrNull(json['protocol']),
        cycle: strOrNull(json['cycle']),
        cycleStart: strOrNull(json['cycleStart']),
        overallTier: strOrNull(json['overallTier']),
        planStatus: strOrNull(json['planStatus']),
        language: strOrNull(json['language']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alias': alias,
        'age': age,
        'sex': sex,
        'diagnosis': diagnosis,
        'protocol': protocol,
        'cycle': cycle,
        'cycleStart': cycleStart,
        'overallTier': overallTier,
        'planStatus': planStatus,
        'language': language,
      };

  DateTime? get cycleStartDate => cycleStart == null ? null : DateTime.tryParse(cycleStart!);
  int get tierRank => Tier.rank(overallTier);
  String get tierLabel => Tier.label(overallTier);
  String get planStatusLabel => PlanStatus.label(planStatus);
}

/// Previous-cycle history entry.
class HistoryEntry {
  final String cycle;
  final String? date;
  final String? antiemetics;
  final List<int> nauseaDays;
  final List<int> vomitingDays;
  final String note;

  const HistoryEntry({
    required this.cycle,
    this.date,
    this.antiemetics,
    this.nauseaDays = const [],
    this.vomitingDays = const [],
    this.note = '',
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        cycle: str(json['cycle']),
        date: strOrNull(json['date']),
        antiemetics: strOrNull(json['antiemetics']),
        nauseaDays: intList(json['nauseaDays']),
        vomitingDays: intList(json['vomitingDays']),
        note: str(json['note']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'cycle': cycle};
    putIfNotNull(m, 'date', date);
    putIfNotNull(m, 'antiemetics', antiemetics);
    m['nauseaDays'] = nauseaDays;
    m['vomitingDays'] = vomitingDays;
    m['note'] = note;
    return m;
  }

  bool get hadNausea => nauseaDays.isNotEmpty;
  bool get hadVomiting => vomitingDays.isNotEmpty;
}

/// Editable personalisation inputs (`PUT /patients/{id}/risk-factors`).
class RiskFactors {
  final bool canSwallowTablets;

  /// One of [DoseRoute.values]: oral_tablet | oral_liquid | ng_tube | iv.
  final String preferredRoute;
  final bool anticipatory;
  final String? priorNauseaNote;

  const RiskFactors({
    this.canSwallowTablets = true,
    this.preferredRoute = DoseRoute.oralTablet,
    this.anticipatory = false,
    this.priorNauseaNote,
  });

  factory RiskFactors.fromJson(Map<String, dynamic> json) => RiskFactors(
        canSwallowTablets: boolean(json['canSwallowTablets'], true),
        preferredRoute: str(json['preferredRoute'], DoseRoute.oralTablet),
        anticipatory: boolean(json['anticipatory']),
        priorNauseaNote: strOrNull(json['priorNauseaNote']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'canSwallowTablets': canSwallowTablets,
      'preferredRoute': preferredRoute,
      'anticipatory': anticipatory,
    };
    putIfNotNull(m, 'priorNauseaNote', priorNauseaNote);
    return m;
  }

  RiskFactors copyWith({
    bool? canSwallowTablets,
    String? preferredRoute,
    bool? anticipatory,
    String? priorNauseaNote,
  }) =>
      RiskFactors(
        canSwallowTablets: canSwallowTablets ?? this.canSwallowTablets,
        preferredRoute: preferredRoute ?? this.preferredRoute,
        anticipatory: anticipatory ?? this.anticipatory,
        priorNauseaNote: priorNauseaNote ?? this.priorNauseaNote,
      );

  String get routeLabel => DoseRoute.label(preferredRoute);
}

/// Full patient context (`GET /patients/{id}`) = PatientSummary + clinical fields.
class Patient extends PatientSummary {
  final double? weightKg;
  final double? heightCm;
  final double? bsaM2;
  final String? diagnosisGroup;
  final List<ChemoRow> chemo;
  final List<String> activeMeds;
  final List<HistoryEntry> history;
  final RiskFactors riskFactors;
  final String? pairingCode;

  const Patient({
    required super.id,
    required super.alias,
    super.age,
    super.sex,
    super.diagnosis,
    super.protocol,
    super.cycle,
    super.cycleStart,
    super.overallTier,
    super.planStatus,
    super.language,
    this.weightKg,
    this.heightCm,
    this.bsaM2,
    this.diagnosisGroup,
    this.chemo = const [],
    this.activeMeds = const [],
    this.history = const [],
    this.riskFactors = const RiskFactors(),
    this.pairingCode,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    final s = PatientSummary.fromJson(json);
    final rf = mapOrNull(json['riskFactors']);
    return Patient(
      id: s.id,
      alias: s.alias,
      age: s.age,
      sex: s.sex,
      diagnosis: s.diagnosis,
      protocol: s.protocol,
      cycle: s.cycle,
      cycleStart: s.cycleStart,
      overallTier: s.overallTier,
      planStatus: s.planStatus,
      language: s.language,
      weightKg: dblOrNull(json['weightKg']),
      heightCm: dblOrNull(json['heightCm']),
      bsaM2: dblOrNull(json['bsaM2']),
      diagnosisGroup: strOrNull(json['diagnosisGroup']),
      chemo: objList(json['chemo'], ChemoRow.fromJson),
      activeMeds: strList(json['activeMeds']),
      history: objList(json['history'], HistoryEntry.fromJson),
      riskFactors: rf == null ? const RiskFactors() : RiskFactors.fromJson(rf),
      pairingCode: strOrNull(json['pairingCode']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'bsaM2': bsaM2,
        'diagnosisGroup': diagnosisGroup,
        'chemo': chemo.map((e) => e.toJson()).toList(),
        'activeMeds': activeMeds,
        'history': history.map((e) => e.toJson()).toList(),
        'riskFactors': riskFactors.toJson(),
        'pairingCode': pairingCode,
      };

  /// All distinct chemo days, sorted.
  List<int> get chemoDays => (chemo.expand((c) => c.days).toSet().toList()..sort());

  /// True when BSA/weight/height are present (otherwise the rules refuse).
  bool get hasAnthropometrics => weightKg != null && heightCm != null && bsaM2 != null;
}
