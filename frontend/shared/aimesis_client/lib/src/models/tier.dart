/// Emetogenicity tiers (UZA v2): minimal < low < moderate < high.
abstract final class Tier {
  static const String minimal = 'minimal';
  static const String low = 'low';
  static const String moderate = 'moderate';
  static const String high = 'high';

  /// Ordered lowest → highest.
  static const List<String> values = [minimal, low, moderate, high];

  /// 0 (minimal) … 3 (high); -1 for unknown/null.
  static int rank(String? tier) => values.indexOf((tier ?? '').toLowerCase());

  static bool isKnown(String? tier) => rank(tier) >= 0;

  /// Highest of the given tiers (null if none known).
  static String? max(Iterable<String?> tiers) {
    String? best;
    for (final t in tiers) {
      if (rank(t) > rank(best)) best = t!.toLowerCase();
    }
    return best;
  }

  /// "High", "Moderate", … ("Unknown" for null/unknown).
  static String label(String? tier) {
    if (!isKnown(tier)) return 'Unknown';
    final t = tier!.toLowerCase();
    return t[0].toUpperCase() + t.substring(1);
  }
}

/// Plan workflow statuses.
abstract final class PlanStatus {
  static const String draft = 'draft';
  static const String awaitingPharmacist = 'awaiting_pharmacist';
  static const String approved = 'approved';
  static const String returned = 'returned';

  static String label(String? status) => switch (status) {
        draft => 'Draft',
        awaitingPharmacist => 'Awaiting pharmacist',
        approved => 'Approved',
        returned => 'Returned',
        _ => status ?? 'Unknown',
      };
}

/// Account roles.
abstract final class Role {
  static const String oncologist = 'oncologist';
  static const String nurse = 'nurse';
  static const String pharmacist = 'pharmacist';
  static const String parent = 'parent';
  static const String patient = 'patient';

  static const Set<String> clinician = {oncologist, nurse, pharmacist};
  static const Set<String> family = {parent, patient};

  static bool isClinician(String? role) => clinician.contains(role);
  static bool isFamily(String? role) => family.contains(role);
}

/// Administration routes (RiskFactors.preferredRoute and dose lines).
abstract final class Route {
  static const String oralTablet = 'oral_tablet';
  static const String oralLiquid = 'oral_liquid';
  static const String ngTube = 'ng_tube';
  static const String iv = 'iv';

  static const List<String> values = [oralTablet, oralLiquid, ngTube, iv];

  static String label(String? route) => switch (route) {
        oralTablet => 'Oral tablet',
        oralLiquid => 'Oral liquid',
        ngTube => 'NG tube',
        iv => 'IV',
        _ => route ?? '',
      };
}

/// Companion episode types.
abstract final class EpisodeType {
  static const String nausea = 'nausea';
  static const String vomiting = 'vomiting';
}

/// Interaction severities.
abstract final class Severity {
  static const String critical = 'critical';
  static const String warning = 'warning';
  static const String info = 'info';

  /// 2 critical, 1 warning, 0 info, -1 unknown.
  static int rank(String? s) => switch (s) {
        critical => 2,
        warning => 1,
        info => 0,
        _ => -1,
      };
}
