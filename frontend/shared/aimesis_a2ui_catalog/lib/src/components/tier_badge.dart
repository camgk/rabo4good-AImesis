import 'package:flutter/material.dart';

import '../govuk/govuk_tag.dart';

/// Emetogenicity tier as a GOV.UK tag (minimal grey, low green, moderate
/// yellow, high red), sentence case. The word carries the meaning, not colour.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.compact = false});

  final String tier;

  /// 16px tag for tables and lists (19px otherwise).
  final bool compact;

  @override
  Widget build(BuildContext context) => GovukTag.tier(tier, small: compact);
}
