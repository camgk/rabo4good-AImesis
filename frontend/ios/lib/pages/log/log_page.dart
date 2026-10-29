import 'dart:async';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/episode_service.dart';
import '../../state/app_state.dart';
import '../../util/cycle.dart';
import '../../widgets/common.dart';

/// The big one-tap logging screen.
///
/// One tap on "Feeling sick" / "Vomited" saves the episode on the phone
/// immediately. A small face scale then offers severity (optional, closes by
/// itself after a few seconds) and the episode is sent to the care team.
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  bool _busy = false;

  Future<void> _log(String type) async {
    if (_busy) return;
    final state = AppScope.read(context);
    final child = state.selected;
    if (child == null) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.heavyImpact());

    try {
      // 1. Saved on the phone right now: the tap alone is enough.
      final staged = await state.episodes
          .stage(child.id, type, cycleDay: state.cycleDay);
      state.onEpisodeLogged(LogResult(LogOutcome.savedOffline, staged.at));

      // 2. Optional severity (skippable, auto-closes).
      if (!mounted) return;
      final severity = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => const _SeveritySheet(),
      );

      // 3. Send (or keep queued).
      final r = await state.episodes.commit(staged.localId, severity: severity);
      state.onEpisodeLogged(r);
      unawaited(HapticFeedback.mediumImpact());
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              r.outcome == LogOutcome.sent
                  ? Icons.check_circle_rounded
                  : Icons.save_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.outcome == LogOutcome.sent
                  ? t.loggedAt(hhmm(r.at))
                  : t.savedOffline),
            ),
          ],
        ),
      ));
    } on EpisodeRejected {
      messenger.showSnackBar(SnackBar(content: Text(t.errorLoading)));
      state.onEpisodeLogged(LogResult(LogOutcome.savedOffline, DateTime.now()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final teen = state.isTeen;
    final alias = state.selected?.alias ?? '';

    final todays = state.episodeList
        .where((e) => e.cycleDay == state.cycleDay)
        .toList();
    final pending = state.pending;

    return RefreshIndicator(
      onRefresh: () async {
        await state.flushQueue();
        await state.loadEpisodes();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          const PendingBanner(),
          const SizedBox(height: 8),
          Text(teen ? t.howFeelingTeen : t.howFeelingParent(alias),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _BigLogButton(
            key: const Key('logNausea'),
            label: teen ? t.logSickTeen : t.logSickParent,
            icon: Icons.sick_rounded,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            onTap: _busy ? null : () => _log(EpisodeType.nausea),
          ),
          const SizedBox(height: 16),
          _BigLogButton(
            key: const Key('logVomiting'),
            label: teen ? t.logVomitedTeen : t.logVomitedParent,
            icon: Icons.water_drop_rounded,
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
            onTap: _busy ? null : () => _log(EpisodeType.vomiting),
          ),
          const SizedBox(height: 16),
          Text(t.oneTapHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          Text(t.loggedToday, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (todays.isEmpty && pending.isEmpty)
            Text(t.nothingLoggedToday,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant))
          else ...[
            for (final p in pending)
              _EpisodeRow(
                type: p.type,
                at: p.at,
                severity: p.severity,
                trailing: t.waitingToSend,
                waiting: true,
              ),
            for (final e in todays)
              _EpisodeRow(
                type: e.type,
                at: e.atDate ?? DateTime.now(),
                severity: e.severity,
                trailing: e.loggedBy == state.account?.id
                    ? t.loggedByYou
                    : e.loggedByFamily
                        ? t.loggedByFamily
                        : t.loggedByCareTeam,
              ),
          ],
          const DemoFooter(),
        ],
      ),
    );
  }
}

class _BigLogButton extends StatelessWidget {
  const _BigLogButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: foreground),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: foreground, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.type,
    required this.at,
    required this.severity,
    required this.trailing,
    this.waiting = false,
  });

  final String type;
  final DateTime at;
  final int? severity;
  final String trailing;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final vomit = type == EpisodeType.vomiting;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      leading: CircleAvatar(
        backgroundColor: vomit ? scheme.errorContainer : scheme.tertiaryContainer,
        child: Icon(vomit ? Icons.water_drop_rounded : Icons.sick_rounded,
            color: vomit ? scheme.onErrorContainer : scheme.onTertiaryContainer),
      ),
      title: Text(
          '${hhmm(at)} · ${vomit ? t.vomiting : t.nausea}${severity != null ? ' · ${t.severityShort(severity!)}' : ''}'),
      subtitle: Text(trailing),
      trailing: waiting
          ? Icon(Icons.schedule_send_rounded, color: scheme.tertiary)
          : Icon(Icons.cloud_done_rounded, color: scheme.primary),
    );
  }
}

/// Optional 1–5 face scale. Closes by itself so a log is never stuck.
class _SeveritySheet extends StatefulWidget {
  const _SeveritySheet();

  @override
  State<_SeveritySheet> createState() => _SeveritySheetState();
}

class _SeveritySheetState extends State<_SeveritySheet> {
  static const _seconds = 8;
  int _left = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_left <= 1) {
        timer.cancel();
        Navigator.of(context).maybePop();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labels = [t.severity1, t.severity2, t.severity3, t.severity4, t.severity5];
    const faces = [
      Icons.sentiment_satisfied_rounded,
      Icons.sentiment_neutral_rounded,
      Icons.sentiment_dissatisfied_rounded,
      Icons.sentiment_very_dissatisfied_rounded,
      Icons.mood_bad_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.severityTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t.severityOptional,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: Color.lerp(scheme.secondaryContainer,
                          scheme.errorContainer, i / 4),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: Key('severity-${i + 1}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(i + 1);
                        },
                        child: SizedBox(
                          height: 96,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(faces[i], size: 36),
                              const SizedBox(height: 6),
                              Text('${i + 1}',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('severitySkip'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('${t.skip} · ${t.savingIn(_left)}'),
            ),
          ),
        ],
      ),
    );
  }
}
