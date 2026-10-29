import 'package:flutter/material.dart';

import 'govuk_tokens.dart';

/// ThemeData built from GOV.UK Design System patterns with the AImesis brand
/// layer. GOV.UK is light-first; [dark] keeps text contrast ≥ 4.5:1 and the
/// yellow focus state.
///
/// [largeScreen] picks the GOV.UK type scale for ≥ 641px (web) or below
/// (phones). Body text is 19px in both.
abstract final class GovukTheme {
  static ThemeData light({bool largeScreen = true}) => _build(Brightness.light, largeScreen);
  static ThemeData dark({bool largeScreen = true}) => _build(Brightness.dark, largeScreen);

  static TextTheme textTheme({required bool largeScreen, required Color color, required Color secondary}) {
    TextStyle s(GovukTypePoint p, {bool bold = false, Color? c}) =>
        GovukType.styleFor(p, largeScreen: largeScreen, bold: bold, color: c ?? color);
    return TextTheme(
      displayLarge: s(GovukType.p80, bold: true),
      displayMedium: s(GovukType.p48, bold: true),
      displaySmall: s(GovukType.p36, bold: true),
      headlineLarge: s(GovukType.p36, bold: true),
      headlineMedium: s(GovukType.p27, bold: true),
      headlineSmall: s(GovukType.p24, bold: true),
      titleLarge: s(GovukType.p24, bold: true),
      titleMedium: s(GovukType.p19, bold: true),
      titleSmall: s(GovukType.p16, bold: true),
      bodyLarge: s(GovukType.p19),
      bodyMedium: s(GovukType.p19),
      bodySmall: s(GovukType.p16, c: secondary),
      labelLarge: s(GovukType.p19, bold: true),
      labelMedium: s(GovukType.p16),
      labelSmall: s(GovukType.p14),
    );
  }

  static ThemeData _build(Brightness b, bool large) {
    final dark = b == Brightness.dark;
    final text = dark ? GovukColours.darkText : GovukColours.text;
    final secondaryText = dark ? GovukColours.darkSecondaryText : GovukColours.secondaryText;
    final bg = dark ? GovukColours.darkBackground : GovukColours.bodyBackground;
    final surface = dark ? GovukColours.darkSurface : GovukColours.bodyBackground;
    final border = dark ? GovukColours.darkBorder : GovukColours.border;
    final inputBorder = dark ? GovukColours.darkText : GovukColours.inputBorder;
    final link = dark ? GovukColours.darkLink : GovukColours.link;
    final error = dark ? GovukColours.darkError : GovukColours.error;
    final primary = dark ? GovukColours.brandOnDark : GovukColours.brand;
    final onPrimary = dark ? GovukColours.black : GovukColours.white;

    final scheme = ColorScheme(
      brightness: b,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: dark ? GovukColours.brandDark : GovukColours.brandTint,
      onPrimaryContainer: dark ? GovukColours.white : GovukColours.black,
      secondary: dark ? GovukColours.accent : GovukColours.brandDark,
      onSecondary: dark ? GovukColours.black : GovukColours.white,
      secondaryContainer: dark ? GovukColours.darkSurfaceHigh : GovukColours.brandTintLight,
      onSecondaryContainer: text,
      tertiary: dark ? GovukColours.accent : GovukColours.green,
      onTertiary: dark ? GovukColours.black : GovukColours.white,
      tertiaryContainer: dark ? const Color(0xFF1F3A31) : GovukColours.accentTintLight,
      onTertiaryContainer: text,
      error: error,
      onError: dark ? GovukColours.black : GovukColours.white,
      errorContainer: dark ? const Color(0xFF4A1A12) : const Color(0xFFF6D7D2),
      onErrorContainer: dark ? GovukColours.white : const Color(0xFF942514),
      surface: surface,
      onSurface: text,
      onSurfaceVariant: secondaryText,
      surfaceContainerLowest: bg,
      surfaceContainerLow: dark ? GovukColours.darkSurface : GovukColours.white,
      surfaceContainer: dark ? GovukColours.darkSurface : GovukColours.lightGrey,
      surfaceContainerHigh: dark ? GovukColours.darkSurfaceHigh : GovukColours.lightGrey,
      surfaceContainerHighest: dark ? GovukColours.darkSurfaceHigh : const Color(0xFFE8E7E6),
      outline: inputBorder,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: dark ? GovukColours.white : GovukColours.black,
      onInverseSurface: dark ? GovukColours.black : GovukColours.white,
      inversePrimary: dark ? GovukColours.brand : GovukColours.brandTint,
      surfaceTint: Colors.transparent,
    );

    final tt = textTheme(largeScreen: large, color: text, secondary: secondaryText);
    const square = RoundedRectangleBorder();
    const minButton = Size(GovukLayout.touchTarget, GovukLayout.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 15, vertical: 8);

    WidgetStateProperty<Color?> focusable(Color normal, {Color? hover, Color? disabled}) =>
        WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return disabled ?? normal.withValues(alpha: 0.5);
          if (s.contains(WidgetState.focused) && !s.contains(WidgetState.pressed)) return GovukColours.focus;
          if (s.contains(WidgetState.hovered)) return hover ?? normal;
          return normal;
        });
    WidgetStateProperty<Color?> focusFg(Color normal) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return normal.withValues(alpha: 0.6);
          if (s.contains(WidgetState.focused) && !s.contains(WidgetState.pressed)) return GovukColours.focusText;
          return normal;
        });
    WidgetStateProperty<OutlinedBorder?> shadowShape(Color shadow) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return const GovukButtonBorder(shadowColor: Colors.transparent);
          if (s.contains(WidgetState.focused)) return const GovukButtonBorder(shadowColor: GovukColours.focusText);
          return GovukButtonBorder(shadowColor: shadow);
        });

    final primaryStyle = ButtonStyle(
      backgroundColor: focusable(primary, hover: dark ? const Color(0xFFB4CDE3) : GovukColours.brandHover),
      foregroundColor: focusFg(onPrimary),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: shadowShape(dark ? GovukColours.brandTint : GovukColours.brandDark),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(minButton),
      padding: const WidgetStatePropertyAll(buttonPadding),
      textStyle: WidgetStatePropertyAll(tt.labelLarge?.copyWith(fontWeight: FontWeight.w400)),
      visualDensity: VisualDensity.standard,
    );
    final secondaryStyle = ButtonStyle(
      backgroundColor: focusable(dark ? GovukColours.darkSurfaceHigh : GovukColours.secondaryButton,
          hover: dark ? const Color(0xFF2E4560) : GovukColours.secondaryButtonHover),
      foregroundColor: focusFg(text),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: shadowShape(dark ? GovukColours.darkBorder : GovukColours.secondaryButtonShadow),
      side: const WidgetStatePropertyAll(BorderSide.none),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(minButton),
      padding: const WidgetStatePropertyAll(buttonPadding),
      textStyle: WidgetStatePropertyAll(tt.labelLarge?.copyWith(fontWeight: FontWeight.w400)),
    );
    final linkStyle = ButtonStyle(
      backgroundColor: focusable(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return secondaryText;
        if (s.contains(WidgetState.focused)) return GovukColours.focusText;
        if (s.contains(WidgetState.hovered)) return dark ? GovukColours.darkLinkHover : GovukColours.linkHover;
        return link;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused)
          ? const GovukButtonBorder(shadowColor: GovukColours.focusText, shadowWidth: 4)
          : const RoundedRectangleBorder()),
      minimumSize: const WidgetStatePropertyAll(minButton),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
      textStyle: WidgetStatePropertyAll(tt.bodyMedium?.copyWith(
        decoration: TextDecoration.underline,
        decorationThickness: 1.5,
      )),
    );

    OutlineInputBorder ob(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: tt,
      primaryTextTheme: tt,
      fontFamily: GovukType.fontFamily,
      fontFamilyFallback: GovukType.fontFamilyFallback,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      focusColor: GovukColours.focus,
      hoverColor: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: GovukColours.white,
        foregroundColor: GovukColours.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: GovukLayout.headerHeight,
        titleTextStyle: tt.titleLarge?.copyWith(color: GovukColours.black),
        iconTheme: const IconThemeData(color: GovukColours.black),
        actionsIconTheme: const IconThemeData(color: GovukColours.black),
        shape: const Border(bottom: BorderSide(color: GovukColours.brand, width: GovukLayout.borderWidthWide)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryStyle),
      textButtonTheme: TextButtonThemeData(style: linkStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: focusable(Colors.transparent),
          foregroundColor: focusFg(text),
          overlayColor: WidgetStatePropertyAll(dark ? Colors.white10 : Colors.black12),
          minimumSize: const WidgetStatePropertyAll(minButton),
          shape: const WidgetStatePropertyAll(square),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(square),
          side: WidgetStatePropertyAll(BorderSide(color: inputBorder, width: 2)),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return GovukColours.focus;
            if (s.contains(WidgetState.selected)) return scheme.primaryContainer;
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return GovukColours.focusText;
            return text;
          }),
          minimumSize: const WidgetStatePropertyAll(minButton),
          textStyle: WidgetStatePropertyAll(tt.bodyMedium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: ob(inputBorder, 2),
        enabledBorder: ob(inputBorder, 2),
        focusedBorder: GovukFocusedInputBorder(borderColor: inputBorder),
        errorBorder: ob(error, 2),
        focusedErrorBorder: GovukFocusedInputBorder(borderColor: inputBorder),
        disabledBorder: ob(border, 2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        labelStyle: tt.bodyMedium,
        floatingLabelStyle: tt.bodyMedium?.copyWith(color: text),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: tt.bodyMedium?.copyWith(color: secondaryText),
        helperStyle: tt.bodySmall,
        errorStyle: tt.bodyMedium?.copyWith(color: error, fontWeight: FontWeight.w700),
        prefixIconColor: text,
        suffixIconColor: text,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: border)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(side: BorderSide(color: inputBorder)),
        side: BorderSide(color: inputBorder),
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: text,
        labelStyle: tt.labelMedium?.copyWith(color: text),
        secondaryLabelStyle: tt.labelMedium?.copyWith(color: text),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        showCheckmark: true,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: link,
        labelStyle: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: tt.bodyMedium?.copyWith(decoration: TextDecoration.underline),
        indicator: UnderlineTabIndicator(borderSide: BorderSide(color: primary, width: 5)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? GovukColours.focus : Colors.transparent),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? GovukColours.darkSurface : GovukColours.lightGrey,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: square,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: text),
        selectedLabelTextStyle: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: text),
        unselectedLabelTextStyle: tt.labelMedium?.copyWith(color: link),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: square,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => tt.labelMedium?.copyWith(
              color: text,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
            )),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: text)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: text,
        textColor: text,
        titleTextStyle: tt.bodyMedium,
        subtitleTextStyle: tt.bodySmall,
        shape: square,
        selectedColor: text,
        selectedTileColor: scheme.primaryContainer,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(),
        side: BorderSide(color: inputBorder, width: 2),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? text : surface),
        checkColor: WidgetStatePropertyAll(bg),
        overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? GovukColours.focus : Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(text),
        overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? GovukColours.focus : Colors.transparent),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : border),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onPrimary : text),
        trackOutlineColor: WidgetStatePropertyAll(inputBorder),
        overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? GovukColours.focus : Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? GovukColours.white : GovukColours.black,
        contentTextStyle: tt.bodyMedium?.copyWith(color: dark ? GovukColours.black : GovukColours.white),
        shape: square,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        shape: Border(top: BorderSide(color: primary, width: GovukLayout.borderWidthWide)),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: tt.headlineSmall,
        contentTextStyle: tt.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: dark ? GovukColours.white : GovukColours.black),
        textStyle: tt.labelMedium?.copyWith(color: dark ? GovukColours.black : GovukColours.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: border),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        dataTextStyle: tt.bodyMedium,
        dividerThickness: 1,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        textColor: text,
        collapsedTextColor: link,
        iconColor: text,
        collapsedIconColor: link,
      ),
      scrollbarTheme: const ScrollbarThemeData(radius: Radius.zero),
    );
  }
}

/// Square button shape with GOV.UK's solid bottom shadow, painted inside the
/// bottom edge so it is never clipped.
class GovukButtonBorder extends OutlinedBorder {
  const GovukButtonBorder({required this.shadowColor, this.shadowWidth = GovukLayout.buttonShadow, super.side});

  final Color shadowColor;
  final double shadowWidth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: shadowWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (shadowColor.a == 0) return;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.bottom - shadowWidth, rect.right, rect.bottom),
      Paint()..color = shadowColor,
    );
  }

  @override
  ShapeBorder scale(double t) => GovukButtonBorder(shadowColor: shadowColor, shadowWidth: shadowWidth * t);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      GovukButtonBorder(shadowColor: shadowColor, shadowWidth: shadowWidth, side: side ?? this.side);

  @override
  bool operator ==(Object other) =>
      other is GovukButtonBorder && other.shadowColor == shadowColor && other.shadowWidth == shadowWidth;

  @override
  int get hashCode => Object.hash(shadowColor, shadowWidth);
}

/// GOV.UK focused text input: 3px yellow outline outside a doubled (4px)
/// black border.
class GovukFocusedInputBorder extends OutlineInputBorder {
  GovukFocusedInputBorder({this.borderColor = GovukColours.inputBorder})
      : super(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderColor, width: 4),
        );

  final Color borderColor;

  @override
  OutlineInputBorder copyWith({BorderSide? borderSide, BorderRadius? borderRadius, double? gapPadding}) =>
      GovukFocusedInputBorder(borderColor: borderSide?.color ?? borderColor);

  @override
  void paint(Canvas canvas, Rect rect,
      {double? gapStart, double gapExtent = 0.0, double gapPercentage = 0.0, TextDirection? textDirection}) {
    canvas.drawRect(
      rect.inflate(GovukLayout.focusWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GovukLayout.focusWidth
        ..color = GovukColours.focus,
    );
    canvas.drawRect(
      rect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = borderColor,
    );
  }
}
