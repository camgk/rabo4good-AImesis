import 'package:flutter/material.dart';

/// "AImesis" wordmark with the AI highlighted, plus an optional subtitle.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.subtitle, this.size = 28});
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size * 1.3,
          height: size * 1.3,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(size * 0.35),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.water_drop_rounded, color: cs.onPrimary, size: size * 0.8),
        ),
        SizedBox(width: size * 0.4),
        RichText(
          text: TextSpan(
            style: base.copyWith(color: cs.onSurface),
            children: [
              TextSpan(text: 'AI', style: TextStyle(color: cs.primary)),
              const TextSpan(text: 'mesis'),
            ],
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(width: size * 0.45),
          Container(width: 1, height: size, color: cs.outlineVariant),
          SizedBox(width: size * 0.45),
          Text(subtitle!,
              style: TextStyle(fontSize: size * 0.62, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
