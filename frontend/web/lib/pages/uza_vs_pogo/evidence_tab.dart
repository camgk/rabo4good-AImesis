import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';

/// Story 5 — UZA v2 (source of truth) vs POGO 2010 (comparison only).
class EvidenceTab extends StatefulWidget {
  const EvidenceTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  State<EvidenceTab> createState() => _EvidenceTabState();
}

class _EvidenceTabState extends State<EvidenceTab> {
  bool _onlyDiff = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = widget.ws.plan!.uzaVsPogo;
    final diffCount = rows.where((r) => r.differs).length;
    final shown = _onlyDiff ? rows.where((r) => r.differs).toList() : rows;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlight = dark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'UZA v2 vs POGO',
          subtitle: 'UZA "Anti-emetica beleid CINV" v2 is the source of truth; POGO (2010) is shown for comparison only.',
          icon: Icons.compare_arrows_rounded,
          story: 'Story 5',
          trailing: FilterChip(
            label: Text('Only differences ($diffCount)'),
            selected: _onlyDiff,
            onSelected: (v) => setState(() => _onlyDiff = v),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: DenseTable(
            columns: const [
              DenseColumn('Drug / combination', flex: 4),
              DenseColumn('UZA v2', flex: 2),
              DenseColumn('POGO', flex: 2),
              DenseColumn('', flex: 2),
              DenseColumn('Note', flex: 6),
            ],
            rowColors: [for (final r in shown) r.differs ? highlight : null],
            rows: [
              for (final r in shown)
                [
                  Text(cap(r.item), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Align(alignment: Alignment.centerLeft, child: _tier(r.uzaTier)),
                  Align(alignment: Alignment.centerLeft, child: _tier(r.pogoTier)),
                  r.differs
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(999)),
                            child: const Text('Differs',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        )
                      : Icon(Icons.check_rounded, size: 18, color: cs.onSurfaceVariant),
                  Text(r.note.isEmpty ? (r.differs ? '' : 'Same tier') : r.note,
                      style: TextStyle(
                          color: r.differs ? null : cs.onSurfaceVariant,
                          fontWeight: r.differs ? FontWeight.w500 : FontWeight.normal)),
                ],
            ],
            empty: EmptyView(
              icon: Icons.compare_arrows_rounded,
              title: _onlyDiff ? 'No differences' : 'No comparison rows',
              message: _onlyDiff ? 'UZA v2 and POGO agree for every drug in this regimen.' : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Differences are informative: the plan always follows UZA v2. POGO mock values in this demo '
          '(e.g. doxorubicin moderate, cyclophosphamide ≥ 1000 mg/m² high).',
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _tier(String t) => Tier.isKnown(t) ? TierBadge(tier: t, compact: true) : Text(t.isEmpty ? '—' : t);
}
