import 'package:flutter/material.dart';

import 'govuk_tokens.dart';

/// GOV.UK tag colour variants (classic v5 values) plus the AImesis brand.
enum GovukTagColour {
  grey(Color(0xFF383F43), Color(0xFFE5E6E7)),
  green(Color(0xFF005A30), Color(0xFFCCE2D8)),
  turquoise(Color(0xFF10403C), Color(0xFFD4ECEA)),
  blue(Color(0xFF144E81), Color(0xFFD2E2F1)),
  lightBlue(Color(0xFF0C2D4A), Color(0xFFBBD4EA)),
  purple(Color(0xFF3D2375), Color(0xFFDBD5E9)),
  pink(Color(0xFF80224D), Color(0xFFF7D7E6)),
  red(Color(0xFF942514), Color(0xFFF6D7D2)),
  orange(Color(0xFF6E3619), Color(0xFFFCD6C3)),
  yellow(Color(0xFF594D00), Color(0xFFFFF7BF)),

  /// AImesis brand: white on steel blue (5.7:1). Phase banner, own labels.
  brand(GovukColours.white, GovukColours.brand),

  /// AImesis brand tint: dark brand blue on sky (6.3:1).
  brandTint(GovukColours.brandDark, GovukColours.brandTint);

  const GovukTagColour(this.foreground, this.background);

  /// Text colour (all pairs ≥ 6:1).
  final Color foreground;
  final Color background;
}

/// GOV.UK tag: a non-interactive status label in sentence case. Never make it
/// a button or link, and don't rely on colour alone: the text says it.
class GovukTag extends StatelessWidget {
  const GovukTag(this.label, {super.key, this.colour = GovukTagColour.blue, this.small = false, this.semanticLabel});

  /// Emetogenicity tier tag: minimal grey, low green, moderate yellow, high red.
  factory GovukTag.tier(String tier, {Key? key, bool small = false, bool prefix = false}) {
    final label = GovukMapping.tierLabel(tier);
    return GovukTag(
      prefix ? '$label risk' : label,
      key: key,
      colour: GovukMapping.tierTag(tier),
      small: small,
      semanticLabel: 'Emetogenicity tier: $label',
    );
  }

  /// Severity tag: critical red, warning orange, info blue.
  factory GovukTag.severity(String severity, {Key? key, bool small = false}) => GovukTag(
        GovukMapping.severityLabel(severity),
        key: key,
        colour: GovukMapping.severityTag(severity),
        small: small,
        semanticLabel: 'Severity: ${GovukMapping.severityLabel(severity)}',
      );

  final String label;
  final GovukTagColour colour;

  /// 16px instead of 19px, for tables and dense lists.
  final bool small;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = GovukType.style(context, small ? GovukType.p16 : GovukType.p19, color: colour.foreground)
        .copyWith(height: small ? 1.15 : 1.2);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: EdgeInsets.fromLTRB(8, small ? 2 : 2, 8, small ? 3 : 3),
        decoration: BoxDecoration(color: colour.background, borderRadius: BorderRadius.circular(1)),
        child: Text(label, style: style, softWrap: true),
      ),
    );
  }
}

/// How AImesis concepts map onto GOV.UK tag colours.
abstract final class GovukMapping {
  static String _n(String s) => s.trim().toLowerCase();

  static GovukTagColour tierTag(String tier) {
    switch (_n(tier)) {
      case 'minimal':
        return GovukTagColour.grey;
      case 'low':
        return GovukTagColour.green;
      case 'moderate':
        return GovukTagColour.yellow;
      case 'high':
        return GovukTagColour.red;
      default:
        return GovukTagColour.grey;
    }
  }

  /// "High", "Moderate" … in sentence case ("Unknown" otherwise).
  static String tierLabel(String tier) {
    final t = _n(tier);
    const known = {'minimal', 'low', 'moderate', 'high'};
    if (!known.contains(t)) return 'Unknown';
    return t[0].toUpperCase() + t.substring(1);
  }

  static GovukTagColour severityTag(String severity) {
    switch (_n(severity)) {
      case 'critical':
      case 'contraindicated':
      case 'high':
        return GovukTagColour.red;
      case 'warning':
      case 'major':
      case 'moderate':
        return GovukTagColour.orange;
      default:
        return GovukTagColour.blue;
    }
  }

  static String severityLabel(String severity) {
    switch (_n(severity)) {
      case 'critical':
        return 'Critical';
      case 'warning':
        return 'Warning';
      case 'info':
        return 'Info';
      default:
        final s = severity.trim();
        return s.isEmpty ? 'Info' : s[0].toUpperCase() + s.substring(1).toLowerCase();
    }
  }

  /// Workflow status → tag colour (sentence-case label is the status text).
  static GovukTagColour statusTag(String status) {
    final s = _n(status);
    if (s.contains('signed') || s.contains('approved') || s.contains('complete') || s.contains('done')) {
      return GovukTagColour.green;
    }
    if (s.contains('reject') || s.contains('block') || s.contains('refus') || s.contains('missing')) {
      return GovukTagColour.red;
    }
    if (s.contains('wait') || s.contains('pending') || s.contains('review') || s.contains('queue')) {
      return GovukTagColour.yellow;
    }
    if (s.contains('draft') || s.contains('new')) return GovukTagColour.blue;
    return GovukTagColour.grey;
  }

  /// Stable colour for free-form patient tags (same tag → same colour).
  static GovukTagColour patientTag(String tag) {
    const palette = [
      GovukTagColour.blue,
      GovukTagColour.turquoise,
      GovukTagColour.purple,
      GovukTagColour.pink,
      GovukTagColour.lightBlue,
      GovukTagColour.orange,
      GovukTagColour.green,
    ];
    var h = 0;
    for (final c in _n(tag).codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }
}
