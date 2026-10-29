import 'package:flutter/material.dart';

import '../theme.dart';

/// "Advisory only — requires clinician sign-off" banner shown on every clinician screen.
class AdvisoryBanner extends StatelessWidget {
  const AdvisoryBanner({super.key, this.text});

  /// Defaults to [AimesisTheme.advisoryText] (or pass `plan.advisory`).
  final String? text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = (text == null || text!.trim().isEmpty) ? AimesisTheme.advisoryText : text!;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
