import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One nausea/vomiting log that has not reached the server yet.
///
/// Every tap on "Feeling sick" / "Vomited" is written here FIRST, so a log is
/// never lost when the phone is offline or the app is closed mid-way.
class QueuedEpisode {
  const QueuedEpisode({
    required this.localId,
    required this.patientId,
    required this.type,
    required this.at,
    this.severity,
    this.cycleDay,
    this.staged = false,
  });

  final String localId;
  final String patientId;

  /// `nausea` or `vomiting`.
  final String type;
  final DateTime at;
  final int? severity;
  final int? cycleDay;

  /// True while the optional severity sheet is still open. Staged items are
  /// not flushed yet (unless they are older than [OfflineQueue.stageTimeout]).
  final bool staged;

  QueuedEpisode copyWith({int? severity, bool? staged}) => QueuedEpisode(
        localId: localId,
        patientId: patientId,
        type: type,
        at: at,
        severity: severity ?? this.severity,
        cycleDay: cycleDay,
        staged: staged ?? this.staged,
      );

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'patientId': patientId,
        'type': type,
        'at': at.toUtc().toIso8601String(),
        if (severity != null) 'severity': severity,
        if (cycleDay != null) 'cycleDay': cycleDay,
        'staged': staged,
      };

  factory QueuedEpisode.fromJson(Map<String, dynamic> json) => QueuedEpisode(
        localId: json['localId'] as String,
        patientId: json['patientId'] as String,
        type: json['type'] as String,
        at: DateTime.parse(json['at'] as String),
        severity: (json['severity'] as num?)?.toInt(),
        cycleDay: (json['cycleDay'] as num?)?.toInt(),
        staged: json['staged'] as bool? ?? false,
      );
}

/// Persistent FIFO of episodes waiting to be sent, stored in shared_preferences.
class OfflineQueue {
  OfflineQueue(this._prefs);

  static const storageKey = 'aimesis.offline_queue.v1';
  static const stageTimeout = Duration(minutes: 1);

  final SharedPreferences _prefs;
  int _seq = 0;

  String newLocalId() =>
      'local-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  List<QueuedEpisode> all() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QueuedEpisode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Corrupt entry: start clean rather than crash the app.
      return [];
    }
  }

  List<QueuedEpisode> forPatient(String patientId) =>
      all().where((e) => e.patientId == patientId).toList();

  int get length => all().length;

  Future<void> _save(List<QueuedEpisode> items) => _prefs.setString(
      storageKey, jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<void> add(QueuedEpisode item) async {
    final items = all()..add(item);
    await _save(items);
  }

  Future<QueuedEpisode?> update(
      String localId, QueuedEpisode Function(QueuedEpisode) change) async {
    final items = all();
    final i = items.indexWhere((e) => e.localId == localId);
    if (i < 0) return null;
    items[i] = change(items[i]);
    await _save(items);
    return items[i];
  }

  Future<void> remove(String localId) async {
    final items = all()..removeWhere((e) => e.localId == localId);
    await _save(items);
  }

  /// Items that may be sent now (not waiting on the severity sheet).
  List<QueuedEpisode> ready({DateTime? now}) {
    final t = now ?? DateTime.now();
    return all()
        .where((e) => !e.staged || t.difference(e.at) > stageTimeout)
        .toList();
  }
}
