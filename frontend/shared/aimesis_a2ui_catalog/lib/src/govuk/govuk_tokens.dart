// Design tokens: GOV.UK Design System patterns + the AImesis brand layer.
//
// Structure, type scale, spacing, borders, focus and component metrics follow
// GOV.UK Frontend (MIT licence, https://github.com/alphagov/govuk-frontend,
// checked against v6.6.0 source). Functional colours are the classic GOV.UK
// palette (v5). Brand colours are AImesis's own, sampled from the logo.
//
// AImesis is NOT a government service: no crown, no "GOV.UK" logotype and no
// GDS Transport typeface. See docs/design-standards.md.
import 'package:flutter/widgets.dart';

/// GOV.UK colour palette (classic v5 values) plus AImesis brand colours.
///
/// Use the functional names ([text], [link], [error] …) in code. The palette
/// entries are only for building those and for tags.
abstract final class GovukColours {
  // ---- AImesis brand layer (sampled from aimesis_logo.png) -------------------

  /// Steel blue from the wordmark. Brand primary: header border, primary
  /// buttons, phase tag. White on it = 5.66:1; on white = 5.66:1.
  static const Color brand = Color(0xFF426A92);

  /// Darker brand blue: primary button bottom shadow, text on [brandTint].
  /// White on it = 9.15:1; on [brandTint] = 6.32:1.
  static const Color brandDark = Color(0xFF2B4A6B);

  /// Primary button hover.
  static const Color brandHover = Color(0xFF35577A);

  /// Light sky blue from the "AI" blob: panels, banner header tints,
  /// selected states. Body text #0B0C0C on it = 13.5:1. Do NOT put links or
  /// [brand] text on it (3.6:1 / 3.9:1); use [brandDark] instead.
  static const Color brandTint = Color(0xFFC2DAEA);

  /// Very light sky: backgrounds that may hold links (#1D70B8 = 4.52:1).
  static const Color brandTintLight = Color(0xFFE8F1F8);

  /// Seafoam/mint from the swoosh and heart: secondary accent, success tints.
  static const Color accent = Color(0xFFA9D1C1);

  /// Very light mint background.
  static const Color accentTintLight = Color(0xFFEEF7F3);

  /// Light-mode brand colour for dark theme chrome (8.0:1 on [darkBackground]).
  static const Color brandOnDark = Color(0xFF8FB3D4);

  // ---- GOV.UK palette (classic) ----------------------------------------------

  static const Color red = Color(0xFFD4351C);
  static const Color yellow = Color(0xFFFFDD00);
  static const Color green = Color(0xFF00703C);
  static const Color blue = Color(0xFF1D70B8);
  static const Color darkBlue = Color(0xFF003078);
  static const Color lightBlue = Color(0xFF5694CA);
  static const Color purple = Color(0xFF4C2C92);
  static const Color black = Color(0xFF0B0C0C);
  static const Color darkGrey = Color(0xFF505A5F);
  static const Color midGrey = Color(0xFFB1B4B6);
  static const Color lightGrey = Color(0xFFF3F2F1);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightPurple = Color(0xFF6F72AF);
  static const Color brightPurple = Color(0xFF912B88);
  static const Color pink = Color(0xFFD53880);
  static const Color lightPink = Color(0xFFF499BE);
  static const Color orange = Color(0xFFF47738);
  static const Color brown = Color(0xFFB58840);
  static const Color lightGreen = Color(0xFF85994B);
  static const Color turquoise = Color(0xFF28A197);

  // ---- functional (light) ----------------------------------------------------

  static const Color text = black; // 19.6:1 on white
  static const Color secondaryText = darkGrey; // 7.07:1 on white
  static const Color link = blue; // 5.17:1 on white
  static const Color linkHover = darkBlue;
  static const Color linkVisited = purple;
  static const Color linkActive = black;
  static const Color border = midGrey; // decorative borders only
  static const Color inputBorder = black;
  static const Color focus = yellow;
  static const Color focusText = black; // 14.6:1 on yellow
  static const Color error = red; // 4.86:1 on white
  static const Color success = green; // 6.21:1 on white
  static const Color templateBackground = lightGrey;
  static const Color bodyBackground = white;
  static const Color hover = Color(0xFFDBDAD9);

  // ---- buttons ---------------------------------------------------------------

  static const Color secondaryButton = lightGrey;
  static const Color secondaryButtonHover = Color(0xFFDBDAD9);
  static const Color secondaryButtonShadow = Color(0xFF929191);
  static const Color warningButton = red;
  static const Color warningButtonHover = Color(0xFFAA2A16);
  static const Color warningButtonShadow = Color(0xFF55150B);

  // ---- dark variant (AImesis addition; GOV.UK is light-only) -----------------

  static const Color darkBackground = Color(0xFF0F1A26);
  static const Color darkSurface = Color(0xFF182635);
  static const Color darkSurfaceHigh = Color(0xFF22344A);
  static const Color darkText = white; // 17.6:1
  static const Color darkSecondaryText = Color(0xFFB9C3CC); // 9.8:1
  static const Color darkLink = Color(0xFF9CC2E5); // 9.4:1
  static const Color darkLinkHover = Color(0xFFC9DDF0);
  static const Color darkLinkVisited = Color(0xFFC9B3F2); // 9.4:1
  static const Color darkBorder = Color(0xFF6B7B8C); // 4.0:1 (non-text ≥3:1)
  static const Color darkError = Color(0xFFF28B7D); // 7.3:1
  static const Color darkSuccess = Color(0xFF6FCF97); // 9.2:1
}

/// GOV.UK spacing scale (px). Static values = large-screen responsive values.
abstract final class GovukSpacing {
  static const double s0 = 0;
  static const double s1 = 5;
  static const double s2 = 10;
  static const double s3 = 15;
  static const double s4 = 20;
  static const double s5 = 25;
  static const double s6 = 30;
  static const double s7 = 40;
  static const double s8 = 50;
  static const double s9 = 60;

  static const List<double> static_ = [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9];

  /// Responsive spacing below the tablet breakpoint (641px).
  static const List<double> responsiveSmall = [0, 5, 10, 15, 15, 15, 20, 25, 30, 40];

  /// Responsive spacing from the tablet breakpoint (641px).
  static const List<double> responsiveLarge = [0, 5, 10, 15, 20, 25, 30, 40, 50, 60];

  /// Static spacing unit 0–9.
  static double unit(int unit) => static_[unit.clamp(0, 9)];

  /// Responsive spacing unit 0–9 for a viewport [width].
  static double responsive(int unit, double width) =>
      (width >= GovukLayout.tablet ? responsiveLarge : responsiveSmall)[unit.clamp(0, 9)];

  /// Responsive spacing unit 0–9 for the current [MediaQuery].
  static double of(BuildContext context, int unit) => responsive(unit, MediaQuery.sizeOf(context).width);
}

/// Layout, borders, focus and touch-target measurements (GOV.UK Frontend).
abstract final class GovukLayout {
  static const double mobile = 320;
  static const double tablet = 641;
  static const double desktop = 769;

  /// Maximum page width.
  static const double pageWidth = 960;
  static const double gutter = 30;
  static const double gutterHalf = 15;

  static const double borderWidth = 5;
  static const double borderWidthWide = 10;
  static const double borderWidthNarrow = 4;
  static const double borderWidthFormElement = 2;
  static const double borderWidthFormGroupError = 5;
  static const double focusWidth = 3;
  static const double hoverWidth = 10;

  /// Button bottom shadow = form element border width.
  static const double buttonShadow = 2;

  /// Minimum touch target (radios/checkboxes are 40px + 4px gutter = 44px).
  static const double touchTarget = 44;

  /// Large one-tap buttons on the family app.
  static const double touchTargetLarge = 64;

  /// Header height without its 10px bottom border.
  static const double headerHeight = 60;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;
}

/// One point of the GOV.UK type scale: font size and line height on small
/// (below 641px) and large screens.
class GovukTypePoint {
  const GovukTypePoint(this.point, this.small, this.smallLine, this.large, this.largeLine);

  final int point;
  final double small;
  final double smallLine;
  final double large;
  final double largeLine;

  double size(bool largeScreen) => largeScreen ? large : small;
  double height(bool largeScreen) => (largeScreen ? largeLine : smallLine) / size(largeScreen);
}

/// GOV.UK type scale. Body is 19px on every screen size; small is 16px.
abstract final class GovukType {
  static const GovukTypePoint p80 = GovukTypePoint(80, 53, 55, 80, 80);
  static const GovukTypePoint p48 = GovukTypePoint(48, 32, 35, 48, 50);
  static const GovukTypePoint p36 = GovukTypePoint(36, 27, 30, 36, 40);
  static const GovukTypePoint p27 = GovukTypePoint(27, 21, 25, 27, 30);
  static const GovukTypePoint p24 = GovukTypePoint(24, 21, 25, 24, 30);
  static const GovukTypePoint p19 = GovukTypePoint(19, 19, 25, 19, 25);
  static const GovukTypePoint p16 = GovukTypePoint(16, 16, 20, 16, 20);

  /// Legacy 14-point (v5) — only for dense tags/captions, never body copy.
  static const GovukTypePoint p14 = GovukTypePoint(14, 14, 20, 14, 20);

  static const List<GovukTypePoint> scale = [p80, p48, p36, p27, p24, p19, p16];

  /// GOV.UK's documented fallback for services that may not use GDS Transport.
  /// No font is downloaded: we rely on what the platform has.
  static const String fontFamily = 'Arial';
  static const List<String> fontFamilyFallback = [
    'Helvetica Neue',
    'Helvetica',
    'Liberation Sans',
    'Arimo',
    'Roboto',
    'sans-serif',
  ];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight bold = FontWeight.w700;

  /// TextStyle for [point] at the current screen size.
  static TextStyle style(BuildContext context, GovukTypePoint point,
      {bool bold = false, Color? color}) {
    final large = MediaQuery.sizeOf(context).width >= GovukLayout.tablet;
    return styleFor(point, largeScreen: large, bold: bold, color: color);
  }

  static TextStyle styleFor(GovukTypePoint point,
          {required bool largeScreen, bool bold = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: point.size(largeScreen),
        height: point.height(largeScreen),
        fontWeight: bold ? GovukType.bold : regular,
        color: color,
      );
}
