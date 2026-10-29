import 'json_helpers.dart';
import 'resource.dart';
import 'tier.dart';

/// One scheduled intake on a passport day.
class PassportItem {
  /// "08:00"
  final String time;
  final String medicine;

  /// Human-readable amount, e.g. "7.6 mg".
  final String amount;
  final String route;
  final String? note;

  const PassportItem({
    required this.time,
    required this.medicine,
    this.amount = '',
    this.route = '',
    this.note,
  });

  factory PassportItem.fromJson(Map<String, dynamic> json) => PassportItem(
        time: str(json['time']),
        medicine: str(json['medicine']),
        amount: str(json['amount']),
        route: str(json['route']),
        note: strOrNull(json['note']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'time': time,
      'medicine': medicine,
      'amount': amount,
      'route': route,
    };
    putIfNotNull(m, 'note', note);
    return m;
  }
}

class PassportDay {
  final int day;
  final String label;
  final String? date;
  final List<PassportItem> items;

  const PassportDay({required this.day, this.label = '', this.date, this.items = const []});

  factory PassportDay.fromJson(Map<String, dynamic> json) => PassportDay(
        day: integer(json['day'], 1),
        label: str(json['label']),
        date: strOrNull(json['date']),
        items: objList(json['items'], PassportItem.fromJson),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'day': day, 'label': label};
    putIfNotNull(m, 'date', date);
    m['items'] = items.map((e) => e.toJson()).toList();
    return m;
  }

  DateTime? get dateValue => date == null ? null : DateTime.tryParse(date!);
}

/// CINV Patient Passport (`GET /patients/{id}/passport?lang=`).
class Passport {
  final String patientId;
  final String alias;
  final String lang;
  final String title;
  final String? overallTier;
  final String status;
  final bool signedOff;
  final List<PassportDay> days;
  final List<String> warningSigns;
  final String wardPhone;
  final List<Resource> resources;
  final String? pairingCode;
  final String disclaimer;

  const Passport({
    required this.patientId,
    this.alias = '',
    this.lang = 'en',
    this.title = '',
    this.overallTier,
    this.status = PlanStatus.draft,
    this.signedOff = false,
    this.days = const [],
    this.warningSigns = const [],
    this.wardPhone = '',
    this.resources = const [],
    this.pairingCode,
    this.disclaimer = '',
  });

  factory Passport.fromJson(Map<String, dynamic> json) => Passport(
        patientId: str(json['patientId']),
        alias: str(json['alias']),
        lang: str(json['lang'], 'en'),
        title: str(json['title']),
        overallTier: strOrNull(json['overallTier']),
        status: str(json['status'], PlanStatus.draft),
        signedOff: boolean(json['signedOff']),
        days: objList(json['days'], PassportDay.fromJson),
        warningSigns: strList(json['warningSigns']),
        wardPhone: str(json['wardPhone']),
        resources: objList(json['resources'], Resource.fromJson),
        pairingCode: strOrNull(json['pairingCode']),
        disclaimer: str(json['disclaimer']),
      );

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'alias': alias,
        'lang': lang,
        'title': title,
        'overallTier': overallTier,
        'status': status,
        'signedOff': signedOff,
        'days': days.map((e) => e.toJson()).toList(),
        'warningSigns': warningSigns,
        'wardPhone': wardPhone,
        'resources': resources.map((e) => e.toJson()).toList(),
        'pairingCode': pairingCode,
        'disclaimer': disclaimer,
      };

  int get tierRank => Tier.rank(overallTier);
  String get tierLabel => Tier.label(overallTier);
  String get statusLabel => PlanStatus.label(status);
}
