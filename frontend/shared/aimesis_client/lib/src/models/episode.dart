import 'json_helpers.dart';
import 'tier.dart';

/// Companion-app episode of nausea or vomiting.
class Episode {
  final String id;
  final String patientId;

  /// nausea | vomiting
  final String type;

  /// 1–5, optional.
  final int? severity;

  /// ISO timestamp.
  final String at;
  final int cycleDay;
  final String loggedBy;
  final String loggedByRole;

  const Episode({
    required this.id,
    required this.patientId,
    required this.type,
    this.severity,
    required this.at,
    this.cycleDay = 1,
    this.loggedBy = '',
    this.loggedByRole = '',
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: str(json['id']),
        patientId: str(json['patientId']),
        type: str(json['type']),
        severity: intOrNull(json['severity']),
        at: str(json['at']),
        cycleDay: integer(json['cycleDay'], 1),
        loggedBy: str(json['loggedBy']),
        loggedByRole: str(json['loggedByRole']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'patientId': patientId,
      'type': type,
    };
    putIfNotNull(m, 'severity', severity);
    m['at'] = at;
    m['cycleDay'] = cycleDay;
    m['loggedBy'] = loggedBy;
    m['loggedByRole'] = loggedByRole;
    return m;
  }

  bool get isNausea => type == EpisodeType.nausea;
  bool get isVomiting => type == EpisodeType.vomiting;

  /// Parsed timestamp (local time), null if unparsable.
  DateTime? get atDate => DateTime.tryParse(at)?.toLocal();
  bool get loggedByFamily => Role.isFamily(loggedByRole);
}
