import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../util/cycle.dart';
import '../../widgets/common.dart';

/// "Today": child, cycle day, today's medicines with a local "Given" tick.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.onLogTap});

  final VoidCallback onLogTap;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  /// Day being looked at; null = today's cycle day.
  int? _viewDay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final child = state.selected;
    final passport = state.passport;
    final today = state.cycleDay;
    final day = _viewDay ?? today;

    PassportDay? pDay;
    for (final d in passport?.days ?? const <PassportDay>[]) {
      if (d.day == day) pDay = d;
    }
    final items = [...?pDay?.items]
      ..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));

    // Next = first not-given item from now on (only on the real today).
    PassportItem? next;
    if (day == today) {
      final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
      final open = items.where((i) => !state.isGiven(day, i)).toList();
      next = open.where((i) => minutesOf(i.time) >= nowMin - 30).firstOrNull ??
          open.firstOrNull;
    }

    final planDays = passport?.days
            .where((d) => d.items.isNotEmpty)
            .map((d) => d.day)
            .toList() ??
        const <int>[];

    return RefreshIndicator(
      onRefresh: state.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          const PendingBanner(),
          // Child + cycle day
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.child_care_rounded,
                        color: scheme.onPrimary, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child?.alias ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(t.dayOfCycle(today, child?.cycle ?? '—'),
                            key: const Key('cycleDay'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: scheme.onPrimaryContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Shortcut to logging
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onLogTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.sentiment_dissatisfied_rounded,
                          color: scheme.error, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          state.isTeen
                              ? t.howFeelingTeen
                              : t.howFeelingParent(child?.alias ?? ''),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(day == today ? t.todayMedicines : t.dayN(day),
              style: theme.textTheme.titleLarge),
          Text(t.medicinesSubtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (passport == null && state.passportLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (passport == null && state.passportError != null)
            ErrorRetry(error: state.passportError, onRetry: state.loadPassport)
          else if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.noMedicinesToday, style: theme.textTheme.bodyLarge),
                    if (planDays.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(t.planRunsDays(compactDays(planDays)),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicineTile(
                  item: item,
                  day: day,
                  isNext: identical(item, next),
                ),
              ),
          if (planDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.showDay, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(t.today),
                  selected: day == today,
                  onSelected: (_) => setState(() => _viewDay = null),
                ),
                for (final d in planDays)
                  if (d != today)
                    ChoiceChip(
                      label: Text(t.dayN(d)),
                      selected: day == d,
                      onSelected: (_) => setState(() => _viewDay = d),
                    ),
              ],
            ),
          ],
          const DemoFooter(),
        ],
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile(
      {required this.item, required this.day, required this.isNext});

  final PassportItem item;
  final int day;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final given = state.isGiven(day, item);
    final purpose = medicinePurpose(item.medicine, state.lang);
    final time = item.time == '24:00' ? '00:00' : item.time;

    return Card(
      color: isNext ? scheme.secondaryContainer : null,
      shape: isNext
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary, width: 2))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => state.setGiven(day, item, !given),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Text(time,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                    if (isNext)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(t.next,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onPrimary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.medicine,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: given ? TextDecoration.lineThrough : null,
                        )),
                    Text(
                      [
                        if (item.amount.isNotEmpty) item.amount,
                        if (item.route.isNotEmpty) routeLabel(item.route, state.lang),
                      ].join(' · '),
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (purpose != null)
                      Text(purpose,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.note!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: given ? t.given : t.markGiven,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Checkbox(
                    value: given,
                    onChanged: (v) => state.setGiven(day, item, v ?? false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
