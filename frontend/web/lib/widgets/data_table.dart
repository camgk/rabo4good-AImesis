import 'package:flutter/material.dart';

class DenseColumn {
  const DenseColumn(this.label, {this.flex = 1});
  final String label;
  final int flex;
}

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
    final header = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: cs.onSurfaceVariant);
    if (rows.isEmpty && empty != null) return empty!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(children: [
            for (final c in columns) Expanded(flex: c.flex, child: Text(c.label.toUpperCase(), style: header)),
          ]),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          Container(
            color: rowColors?[i],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var j = 0; j < columns.length; j++)
                      Expanded(
                        flex: columns[j].flex,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
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
