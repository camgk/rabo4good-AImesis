import 'package:aimesis_client/aimesis_client.dart';

import 'offline_queue.dart';

enum LogOutcome { sent, savedOffline }

class LogResult {
  const LogResult(this.outcome, this.at, {this.episode});
  final LogOutcome outcome;
  final DateTime at;
  final Episode? episode;
}

/// The server refused the log for good (e.g. 403: not your child), so
/// retrying won't help.
class EpisodeRejected implements Exception {
  const EpisodeRejected(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'EpisodeRejected($status): $message';
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
  EpisodeService({required this.api, required this.queue});

  final AimesisApi api;
  final OfflineQueue queue;
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

  /// Stage + commit in one go (no severity).
  Future<LogResult> logNow(String patientId, String type,
      {int? severity, int? cycleDay}) async {
    final item = await stage(patientId, type, cycleDay: cycleDay);
    return commit(item.localId, severity: severity);
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
    } on ApiException catch (e) {
      if (_permanentStatuses.contains(e.status)) {
        await queue.remove(localId);
        throw EpisodeRejected(e.status, e.message);
      }
      return LogResult(LogOutcome.savedOffline, item.at);
    } catch (_) {
      return LogResult(LogOutcome.savedOffline, item.at);
    }
  }

  /// Sends everything waiting in the queue. Returns how many are still waiting.
  Future<int> flush() {
    return _flushing ??= _doFlush().whenComplete(() => _flushing = null);
  }

  Future<int> _doFlush() async {
    if (!api.isLoggedIn) return queue.length;
    for (final item in queue.ready()) {
      try {
        await _send(item);
        await queue.remove(item.localId);
      } on ApiException catch (e) {
        if (_permanentStatuses.contains(e.status)) {
          await queue.remove(item.localId);
          continue;
        }
        break; // offline / server down / 401: keep order, try again later
      } catch (_) {
        break;
      }
    }
    return queue.length;
  }

  Future<Episode> _send(QueuedEpisode item) {
    final queuedForAWhile =
        DateTime.now().difference(item.at) > const Duration(minutes: 2);
    // Fresh taps let the server stamp the time; replays keep the tap time.
    return api.logEpisode(item.patientId, item.type,
        severity: item.severity, at: queuedForAWhile ? item.at : null);
  }
}
