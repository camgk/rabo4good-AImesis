import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';

/// AImesis logo (from the brand assets) with an optional service-area name.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.subtitle, this.size = 28});
  final String? subtitle;

  /// Roughly the old text size; the logo is drawn at ~1.5× this height.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AimesisBrand.logo(height: size * 1.6),
        if (subtitle != null) ...[
          SizedBox(width: size * 0.45),
          Container(width: 1, height: size, color: GovukColours.midGrey),
          SizedBox(width: size * 0.45),
          Text(subtitle!,
              style: GovukType.style(context, GovukType.p24, bold: true, color: GovukColours.brandDark)),
        ],
      ],
    );
  }
}
