import 'package:flutter/material.dart';

import '../govuk/govuk_tokens.dart';
import '../theme.dart';

/// "Advisory only — requires clinician sign-off" strip shown on every
/// clinician screen. GOV.UK warning-text pattern (black "!" circle, bold text)
/// on the AImesis light brand tint.
class AdvisoryBanner extends StatelessWidget {
  const AdvisoryBanner({super.key, this.text});

  /// Defaults to [AimesisTheme.advisoryText] (or pass `plan.advisory`).
  final String? text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = (text == null || text!.trim().isEmpty) ? AimesisTheme.advisoryText : text!;
    final fg = dark ? GovukColours.darkText : GovukColours.text;
    final bg = dark ? GovukColours.darkSurfaceHigh : GovukColours.brandTintLight;
    return Semantics(
      container: true,
      label: 'Warning: $t',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          border: Border(bottom: BorderSide(color: dark ? GovukColours.darkBorder : GovukColours.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: GovukSpacing.s3, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              child: Text('!',
                  style: TextStyle(
                    fontFamily: GovukType.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1,
                    color: bg,
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t, style: GovukType.style(context, GovukType.p16, bold: true, color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
