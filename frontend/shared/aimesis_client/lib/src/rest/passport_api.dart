import '../models/passport.dart';
import '../models/resource.dart';
import 'api_core.dart';

/// Passport + family resources endpoints.
mixin PassportApi on ApiCore {
  /// `GET /patients/{id}/passport?lang=nl|fr|en`
  Future<Passport> passport(String patientId, String lang) async => Passport.fromJson(asObject(
      await getJson('/patients/${Uri.encodeComponent(patientId)}/passport', query: {'lang': lang})));

  /// `GET /resources?lang=nl|fr|en|de` (all languages when [lang] is null).
  Future<List<Resource>> resources({String? lang}) async => asList(
      await getJson('/resources', query: lang == null ? null : {'lang': lang}), Resource.fromJson);
}
