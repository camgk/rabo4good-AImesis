import '../models/episode.dart';
import 'api_core.dart';

/// Companion-app episode endpoints.
mixin EpisodesApi on ApiCore {
  /// `GET /patients/{id}/episodes` — newest first.
  Future<List<Episode>> episodes(String patientId) async =>
      asList(await getJson('/patients/${Uri.encodeComponent(patientId)}/episodes'), Episode.fromJson);

  /// `POST /patients/{id}/episodes` — [type] is `nausea` or `vomiting`,
  /// [severity] 1–5. [at] defaults to "now" on the server (pass it when
  /// replaying an offline queue).
  Future<Episode> logEpisode(String patientId, String type, {int? severity, DateTime? at}) async {
    final body = <String, dynamic>{
      'type': type,
      if (severity != null) 'severity': severity,
      if (at != null) 'at': at.toUtc().toIso8601String(),
    };
    return Episode.fromJson(
        asObject(await postJson('/patients/${Uri.encodeComponent(patientId)}/episodes', body)));
  }
}
