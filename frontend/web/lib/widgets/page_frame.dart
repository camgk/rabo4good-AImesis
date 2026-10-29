import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';

/// Standard scrollable page body with a title row and max width.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 1280,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = GovukLayout.isTablet(context) ? GovukLayout.gutter : GovukLayout.gutterHalf;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, GovukSpacing.of(context, 6), gutter, GovukSpacing.of(context, 8)),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: GovukType.style(context, GovukType.p36, bold: true, color: theme.colorScheme.onSurface)),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: GovukSpacing.s2),
                        Text(subtitle!,
                            style: GovukType.style(context, GovukType.p19, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ]),
                  ),
                  ...actions,
                ],
              ),
              const SizedBox(height: GovukSpacing.s6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
