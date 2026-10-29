import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:http/http.dart' as http;

import 'offline_queue.dart';

enum LogOutcome { sent, savedOffline }

class LogResult {
  const LogResult(this.outcome, this.at, {this.episode});
  final LogOutcome outcome;
  final DateTime at;
  final Episode? episode;
}

/// Server said no for good (e.g. 403 not your child): retrying won't help.
class EpisodeRejected implements Exception {
  const EpisodeRejected(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'EpisodeRejected($status): $message';
}

class _HttpStatus implements Exception {
  const _HttpStatus(this.status, this.message);
  final int status;
  final String message;
}

/// Wraps the REST client and the offline queue.
///
/// Flow for a one-tap log:
///  1. [stage] writes the episode to the phone straight away (time = tap time).
///  2. The UI optionally asks for severity (a few seconds, skippable).
///  3. [commit] adds the severity and sends it with `AimesisApi.logEpisode`.
///     If that fails it stays in the queue and [flush] retries later
///     (app resume, pull-to-refresh), sending the original tap time.
class EpisodeService {
  EpisodeService({required this.api, required this.queue, http.Client? client})
      : _client = client ?? http.Client();

  final AimesisApi api;
  final OfflineQueue queue;
  final http.Client _client;
  Future<int>? _flushing;

  static const _permanentStatuses = {400, 403, 404, 409, 422};

  Future<QueuedEpisode> stage(String patientId, String type,
      {int? cycleDay}) async {
    final item = QueuedEpisode(
      localId: queue.newLocalId(),
      patientId: patientId,
      type: type,
      at: DateTime.now(),
      cycleDay: cycleDay,
      staged: true,
    );
    await queue.add(item);
    return item;
  }

  Future<LogResult> commit(String localId, {int? severity}) async {
    final item = await queue.update(
        localId, (e) => e.copyWith(severity: severity, staged: false));
    if (item == null) {
      // Already sent by a concurrent flush.
      return LogResult(LogOutcome.sent, DateTime.now());
    }
    try {
      final ep = await _send(item);
      await queue.remove(localId);
      return LogResult(LogOutcome.sent, item.at, episode: ep);
    } catch (e) {
      if (_isPermanent(e)) {
        await queue.remove(localId);
        throw EpisodeRejected(_statusOf(e) ?? 0, _messageOf(e));
      }
      return LogResult(LogOutcome.savedOffline, item.at);
    }
  }

  /// Sends everything waiting in the queue. Returns how many are still waiting.
  Future<int> flush() {
    return _flushing ??= _doFlush().whenComplete(() => _flushing = null);
  }

  Future<int> _doFlush() async {
    for (final item in queue.ready()) {
      try {
        await _send(item);
        await queue.remove(item.localId);
      } catch (e) {
        if (_isPermanent(e)) {
          await queue.remove(item.localId);
          continue;
        }
        break; // offline or server down: keep order, try again later
      }
    }
    return queue.length;
  }

  Future<Episode> _send(QueuedEpisode item) async {
    final age = DateTime.now().difference(item.at);
    if (age < const Duration(minutes: 2)) {
      return api.logEpisode(item.patientId, item.type, severity: item.severity);
    }
    // Older (queued offline): post directly so the original tap time is kept.
    final base = api.baseUrl.endsWith('/')
        ? api.baseUrl.substring(0, api.baseUrl.length - 1)
        : api.baseUrl;
    final res = await _client.post(
      Uri.parse('$base/patients/${Uri.encodeComponent(item.patientId)}/episodes'),
      headers: {
        'Content-Type': 'application/json',
        if (api.token != null) 'Authorization': 'Bearer ${api.token}',
      },
      body: jsonEncode({
        'type': item.type,
        if (item.severity != null) 'severity': item.severity,
        'at': item.at.toUtc().toIso8601String(),
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Episode.fromJson(
          Map<String, dynamic>.from(jsonDecode(res.body) as Map));
    }
    String msg = res.body;
    try {
      msg = (jsonDecode(res.body) as Map)['error']?.toString() ?? msg;
    } catch (_) {}
    throw _HttpStatus(res.statusCode, msg);
  }

  static int? _statusOf(Object e) {
    if (e is ApiException) return e.status;
    if (e is _HttpStatus) return e.status;
    return null;
  }

  static String _messageOf(Object e) {
    if (e is ApiException) return e.message;
    if (e is _HttpStatus) return e.message;
    return e.toString();
  }

  static bool _isPermanent(Object e) {
    final s = _statusOf(e);
    return s != null && _permanentStatuses.contains(s);
  }
}
