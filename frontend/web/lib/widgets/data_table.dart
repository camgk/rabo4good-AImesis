import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';

class DenseColumn {
  const DenseColumn(this.label, {this.flex = 1});
  final String label;
  final int flex;
}

/// GOV.UK-style table (bold headers, 1px row rules, no zebra fill).
/// Lightweight flex-based table: dense, readable, wraps text instead of
/// overflowing (DataTable doesn't wrap well at tablet widths).
class DenseTable extends StatelessWidget {
  const DenseTable({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
    this.rowColors,
    this.rowBelow,
  });

  final List<DenseColumn> columns;
  final List<List<Widget>> rows;
  final Widget? empty;

  /// Optional background per row (null = default).
  final List<Color?>? rowColors;

  /// Optional full-width widget under each row (e.g. expandable details).
  final List<Widget?>? rowBelow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final header = GovukType.style(context, GovukType.p19, bold: true, color: cs.onSurface);
    if (rows.isEmpty && empty != null) return empty!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
          padding: const EdgeInsets.symmetric(horizontal: GovukSpacing.s3, vertical: 10),
          child: Semantics(
            header: true,
            child: Row(children: [
              for (final c in columns) Expanded(flex: c.flex, child: Text(c.label, style: header)),
            ]),
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          Container(
            color: rowColors?[i],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GovukSpacing.s3, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = 0; j < columns.length; j++)
                      Expanded(
                        flex: columns[j].flex,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: j < rows[i].length ? rows[i][j] : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
              if (rowBelow != null && rowBelow![i] != null) rowBelow![i]!,
            ]),
          ),
        ],
      ],
    );
  }
}
