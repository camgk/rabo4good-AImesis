import 'package:flutter/material.dart';

import 'govuk_tokens.dart';

/// AImesis brand assets (from the clinical team's decks), shipped with this
/// package under `assets/brand/`.
abstract final class AimesisBrand {
  static const String package = 'aimesis_a2ui_catalog';

  /// Full logo (child + "AI" blob + "mesis" wordmark), transparent PNG 439×182.
  static const String logoAsset = 'assets/brand/aimesis_logo_transparent.png';

  /// Original logo on off-white #FDFDFD.
  static const String logoOpaqueAsset = 'assets/brand/aimesis_logo.png';

  /// Square mark (child, "AI" blob, heart), transparent PNG 512×512.
  static const String markAsset = 'assets/brand/aimesis_mark.png';

  /// App icon master: mark on white, 1024×1024 RGB without alpha.
  static const String appIconAsset = 'assets/brand/aimesis_app_icon_1024.png';

  /// Logo aspect ratio (width / height).
  static const double logoAspect = 439 / 182;

  static const Color primary = GovukColours.brand;
  static const Color primaryDark = GovukColours.brandDark;
  static const Color tint = GovukColours.brandTint;
  static const Color accent = GovukColours.accent;

  /// The AImesis logo at [height] (width follows the aspect ratio).
  static Widget logo({double height = 36, String semanticLabel = 'AImesis'}) => Image.asset(
        logoAsset,
        package: package,
        height: height,
        width: height * logoAspect,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stack) => _fallback(height, semanticLabel),
      );

  /// The square AImesis mark at [size].
  static Widget mark({double size = 40, String? semanticLabel = 'AImesis'}) => Image.asset(
        markAsset,
        package: package,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        errorBuilder: (context, error, stack) => _fallback(size, semanticLabel ?? 'AImesis'),
      );

  static Widget _fallback(double height, String label) => Semantics(
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'AImesis',
              style: TextStyle(
                fontFamily: GovukType.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: height * 0.6,
                color: GovukColours.brand,
              ),
            ),
          ),
        ),
      );
}
