import 'package:flutter/material.dart';

import '../theme.dart';

/// Coloured pill showing an emetogenicity tier (minimal/low/moderate/high).
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.compact = false});

  final String tier;

  /// Smaller pill for tables and lists.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = AimesisTheme.tierColor(tier, b);
    final fg = AimesisTheme.onTierColor(tier, b);
    final label = AimesisTheme.tierLabel(tier);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Emetogenicity tier: $label',
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AimesisTheme.tierAccent(tier), width: compact ? 1 : 1.5),
        ),
        child: Text(
          compact ? label : label.toUpperCase(),
          style: (compact ? text.labelSmall : text.labelLarge)?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 0.2 : 0.8,
          ),
        ),
      ),
    );
  }
}
