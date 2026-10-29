import 'package:flutter/material.dart';

import 'govuk/govuk_tag.dart';
import 'govuk/govuk_theme.dart';
import 'govuk/govuk_tokens.dart';

/// Shared AImesis look. Since the GOV.UK switch this delegates to
/// [GovukTheme] (GOV.UK Design System patterns + AImesis brand layer) and maps
/// tiers/severity to GOV.UK tag colours. Kept for existing call sites.
abstract final class AimesisTheme {
  static const Color seed = GovukColours.brand;

  /// Advisory text required on every clinician screen.
  static const String advisoryText =
      'Advisory only — requires clinician sign-off.';

  static ThemeData light() => GovukTheme.light();
  static ThemeData dark() => GovukTheme.dark();

  // ---- tiers -------------------------------------------------------------

  static String _norm(String tier) => tier.trim().toLowerCase();

  /// Background colour for a tier = GOV.UK tag background: minimal grey,
  /// low green, moderate yellow, high red. Same in both themes (the tag pair
  /// carries its own contrast).
  static Color tierColor(String tier, Brightness brightness) => GovukMapping.tierTag(tier).background;

  /// Readable foreground for [tierColor] (≥ 6:1).
  static Color onTierColor(String tier, Brightness brightness) => GovukMapping.tierTag(tier).foreground;

  /// Strong accent for a tier (borders, chart bars).
  static Color tierAccent(String tier) {
    switch (_norm(tier)) {
      case 'minimal':
        return GovukColours.darkGrey;
      case 'low':
        return GovukColours.green;
      case 'moderate':
        return GovukColours.orange;
      case 'high':
        return GovukColours.red;
      default:
        return GovukColours.midGrey;
    }
  }

  /// "High", "Moderate", … ("Unknown" for anything else).
  static String tierLabel(String tier) {
    final t = _norm(tier);
    const known = {'minimal', 'low', 'moderate', 'high'};
    if (!known.contains(t)) return 'Unknown';
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Interaction severity colours: critical red, warning orange, info blue
  /// (GOV.UK tag colours).
  static Color severityColor(String severity, Brightness brightness) =>
      GovukMapping.severityTag(severity).background;

  static Color onSeverityColor(String severity, Brightness brightness) =>
      GovukMapping.severityTag(severity).foreground;
}
