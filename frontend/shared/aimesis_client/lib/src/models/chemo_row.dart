import 'json_helpers.dart';

/// One chemotherapy drug in the regimen.
class ChemoRow {
  final String drug;
  final double doseMgM2;
  final List<int> days;

  const ChemoRow({required this.drug, required this.doseMgM2, this.days = const []});

  factory ChemoRow.fromJson(Map<String, dynamic> json) => ChemoRow(
        drug: str(json['drug']),
        doseMgM2: dbl(json['doseMgM2']),
        days: intList(json['days']),
      );

  Map<String, dynamic> toJson() => {'drug': drug, 'doseMgM2': doseMgM2, 'days': days};
}
