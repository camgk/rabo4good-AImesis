/// Component names in the A2UI catalog (mirrors contracts/a2ui/catalog.json).
/// The agent may only emit these; this package must implement every one.
abstract final class AimesisCatalog {
  static const String tierBadge = 'TierBadge';
  static const String dayTierStrip = 'DayTierStrip';
  static const String doseTable = 'DoseTable';
  static const String dexStatusBanner = 'DexStatusBanner';
  static const String ddiAlertCard = 'DdiAlertCard';
  static const String uzaPogoTable = 'UzaPogoTable';
  static const String scheduleGrid = 'ScheduleGrid';
  static const String clinicianOption = 'ClinicianOption';
  static const String notesQuote = 'NotesQuote';
  static const String advisoryBanner = 'AdvisoryBanner';

  static const List<String> components = [
    tierBadge,
    dayTierStrip,
    doseTable,
    dexStatusBanner,
    ddiAlertCard,
    uzaPogoTable,
    scheduleGrid,
    clinicianOption,
    notesQuote,
    advisoryBanner,
  ];

  /// Components with a Flutter implementation today.
  static const Set<String> implemented = {tierBadge, dexStatusBanner, advisoryBanner};
}
