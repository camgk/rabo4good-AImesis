import 'package:flutter/material.dart';

/// Shared AImesis look: calm clinical Material 3, teal seed, tier colours.
abstract final class AimesisTheme {
  static const Color seed = Color(0xFF0F766E);

  /// Advisory text required on every clinician screen.
  static const String advisoryText =
      'Advisory only — requires clinician sign-off. Demo data, not for clinical use.';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      chipTheme: ChipThemeData(side: BorderSide(color: scheme.outlineVariant)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }

  // ---- tiers -------------------------------------------------------------

  static String _norm(String tier) => tier.trim().toLowerCase();

  /// Background colour for a tier: minimal grey, low green, moderate amber, high red.
  static Color tierColor(String tier, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (_norm(tier)) {
      case 'minimal':
        return dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
      case 'low':
        return dark ? const Color(0xFF166534) : const Color(0xFFDCFCE7);
      case 'moderate':
        return dark ? const Color(0xFF92400E) : const Color(0xFFFEF3C7);
      case 'high':
        return dark ? const Color(0xFF991B1B) : const Color(0xFFFEE2E2);
      default:
        return dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    }
  }

  /// Readable foreground for [tierColor].
  static Color onTierColor(String tier, Brightness brightness) {
    if (brightness == Brightness.dark) return Colors.white;
    switch (_norm(tier)) {
      case 'minimal':
        return const Color(0xFF1F2937);
      case 'low':
        return const Color(0xFF14532D);
      case 'moderate':
        return const Color(0xFF78350F);
      case 'high':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF374151);
    }
  }

  /// Strong accent for a tier (borders, icons, chart bars) — same in both themes.
  static Color tierAccent(String tier) {
    switch (_norm(tier)) {
      case 'minimal':
        return const Color(0xFF6B7280);
      case 'low':
        return const Color(0xFF16A34A);
      case 'moderate':
        return const Color(0xFFD97706);
      case 'high':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  /// "High", "Moderate", … ("Unknown" for anything else).
  static String tierLabel(String tier) {
    final t = _norm(tier);
    const known = {'minimal', 'low', 'moderate', 'high'};
    if (!known.contains(t)) return 'Unknown';
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Interaction severity colours (critical red, warning amber, info teal/blue).
  static Color severityColor(String severity, Brightness brightness) {
    switch (severity) {
      case 'critical':
        return tierColor('high', brightness);
      case 'warning':
        return tierColor('moderate', brightness);
      default:
        return brightness == Brightness.dark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE);
    }
  }

  static Color onSeverityColor(String severity, Brightness brightness) {
    switch (severity) {
      case 'critical':
        return onTierColor('high', brightness);
      case 'warning':
        return onTierColor('moderate', brightness);
      default:
        return brightness == Brightness.dark ? Colors.white : const Color(0xFF0C4A6E);
    }
  }
}
