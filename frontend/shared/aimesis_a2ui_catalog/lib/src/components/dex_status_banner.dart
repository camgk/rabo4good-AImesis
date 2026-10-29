import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows whether dexamethasone is allowed or blocked (with the rule reason).
class DexStatusBanner extends StatelessWidget {
  const DexStatusBanner({super.key, required this.blocked, this.reason, this.source});

  final bool blocked;
  final String? reason;

  /// Optional source label (e.g. "UZA v2 (mock rules)").
  final String? source;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final tier = blocked ? 'high' : 'low';
    final bg = AimesisTheme.tierColor(tier, b);
    final fg = AimesisTheme.onTierColor(tier, b);
    final text = Theme.of(context).textTheme;
    final title = blocked ? 'Dexamethasone blocked' : 'Dexamethasone allowed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AimesisTheme.tierAccent(tier)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(blocked ? Icons.block : Icons.check_circle_outline, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(reason!, style: text.bodyMedium?.copyWith(color: fg)),
                ],
                if (source != null && source!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(source!, style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
