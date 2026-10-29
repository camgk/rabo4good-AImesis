import 'package:flutter/material.dart';

import '../govuk/govuk_content.dart';
import '../govuk/govuk_tokens.dart';

/// Dexamethasone gate. Blocked: GOV.UK warning text inside a red-bordered
/// box (it is a safety gate). Allowed: inset text with a green border.
class DexStatusBanner extends StatelessWidget {
  const DexStatusBanner({super.key, required this.blocked, this.reason, this.source});

  final bool blocked;
  final String? reason;

  /// Optional source label (e.g. "UZA v2 (mock rules)").
  final String? source;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? GovukColours.darkSecondaryText : GovukColours.secondaryText;
    final text = dark ? GovukColours.darkText : GovukColours.text;
    final title = blocked ? 'Dexamethasone blocked' : 'Dexamethasone allowed';
    final details = <Widget>[
      if (reason != null && reason!.isNotEmpty)
        Text(reason!, style: GovukType.style(context, GovukType.p19, color: text)),
      if (source != null && source!.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text('Source: ${source!}', style: GovukType.style(context, GovukType.p16, color: secondary)),
      ],
    ];
    if (!blocked) {
      return GovukInsetText(
        borderColor: dark ? GovukColours.darkSuccess : GovukColours.success,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GovukType.style(context, GovukType.p19, bold: true, color: text)),
            if (details.isNotEmpty) const SizedBox(height: 5),
            ...details,
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: dark ? GovukColours.darkError : GovukColours.error,
            width: GovukLayout.borderWidthWide,
          ),
        ),
      ),
      child: GovukWarningText(
        title,
        child: details.isEmpty
            ? null
            : DefaultTextStyle.merge(
                style: const TextStyle(fontWeight: FontWeight.w400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: details),
              ),
      ),
    );
  }
}
