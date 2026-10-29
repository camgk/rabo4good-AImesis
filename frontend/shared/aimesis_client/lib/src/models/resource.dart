import 'json_helpers.dart';

/// Belgian family resource (`GET /resources`, also embedded in the Passport).
class Resource {
  final String institution;
  final String title;
  final String format;

  /// nl | fr | en | de
  final String language;
  final String url;

  /// low | medium | high
  final String effort;
  final String effortNote;

  const Resource({
    required this.institution,
    required this.title,
    this.format = '',
    this.language = '',
    required this.url,
    this.effort = '',
    this.effortNote = '',
  });

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        institution: str(json['institution']),
        title: str(json['title']),
        format: str(json['format']),
        language: str(json['language']),
        url: str(json['url']),
        effort: str(json['effort']),
        effortNote: str(json['effortNote']),
      );

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'title': title,
        'format': format,
        'language': language,
        'url': url,
        'effort': effort,
        'effortNote': effortNote,
      };

  bool get isLowEffort => effort == 'low';
  bool get isPdf => format.toUpperCase() == 'PDF';
}
