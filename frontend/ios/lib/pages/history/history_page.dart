import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../util/cycle.dart';
import '../../widgets/common.dart';

/// Episodes grouped by cycle day, with a simple bar per day.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final episodes = state.episodeList;

    final byDay = <int, List<Episode>>{};
    for (final e in episodes) {
      byDay.putIfAbsent(e.cycleDay, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final maxCount = byDay.values.fold<int>(1, (m, l) => l.length > m ? l.length : m);

    return RefreshIndicator(
      onRefresh: () async {
        await state.flushQueue();
        await state.loadEpisodes();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          const PendingBanner(),
          if (episodes.isEmpty && state.episodesLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (episodes.isEmpty && state.episodesError != null)
            ErrorRetry(error: state.episodesError, onRetry: state.loadEpisodes)
          else if (episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.sentiment_satisfied_rounded,
                      size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(t.historyEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          else ...[
            Text(t.perDayTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(t.sentToCareTeam,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final d in days.reversed)
                      _DayBar(
                        day: d,
                        nausea: byDay[d]!.where((e) => e.isNausea).length,
                        vomiting: byDay[d]!.where((e) => e.isVomiting).length,
                        max: maxCount,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Legend(color: scheme.tertiary, label: t.nausea),
                        const SizedBox(width: 16),
                        _Legend(color: scheme.error, label: t.vomiting),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final d in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  d == state.cycleDay ? '${t.dayN(d)} · ${t.today}' : t.dayN(d),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final e in byDay[d]!)
                      ListTile(
                        minTileHeight: 56,
                        leading: Icon(
                          e.isVomiting ? Icons.water_drop_rounded : Icons.sick_rounded,
                          color: e.isVomiting ? scheme.error : scheme.tertiary,
                        ),
                        title: Text(e.isVomiting ? t.vomiting : t.nausea),
                        subtitle: Text([
                          if (e.atDate != null) hhmm(e.atDate!),
                          if (e.loggedBy == state.account?.id)
                            t.loggedByYou
                          else if (e.loggedByFamily)
                            t.loggedByFamily
                          else
                            t.loggedByCareTeam,
                        ].join(' · ')),
                        trailing: e.severity != null
                            ? Text(t.severityShort(e.severity!),
                                style: theme.textTheme.titleMedium)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ],
          const DemoFooter(),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar(
      {required this.day,
      required this.nausea,
      required this.vomiting,
      required this.max});

  final int day;
  final int nausea;
  final int vomiting;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final total = nausea + vomiting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(t.dayN(day))),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final unit = c.maxWidth / (max == 0 ? 1 : max);
              return Row(
                children: [
                  if (nausea > 0)
                    Container(
                      width: unit * nausea,
                      height: 20,
                      decoration: BoxDecoration(
                        color: scheme.tertiary,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(6)),
                      ),
                    ),
                  if (vomiting > 0)
                    Container(
                      width: unit * vomiting,
                      height: 20,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(6)),
                      ),
                    ),
                ],
              );
            }),
          ),
          SizedBox(
              width: 32,
              child: Text('$total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
