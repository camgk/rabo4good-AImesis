import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../util/cycle.dart';
import '../../widgets/common.dart';

/// The family's CINV Passport: full schedule, warning signs, resources.
class PassportPage extends StatelessWidget {
  const PassportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = state.passport;

    if (p == null) {
      return Center(
        child: state.passportLoading
            ? const CircularProgressIndicator()
            : ErrorRetry(error: state.passportError, onRetry: state.loadPassport),
      );
    }

    final days = p.days.where((d) => d.items.isNotEmpty).toList();
    return RefreshIndicator(
      onRefresh: state.loadPassport,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          Text(p.title.isNotEmpty ? p.title : t.navPassport,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _SignOffChip(signedOff: p.signedOff),
          const SizedBox(height: 16),

          // Warning signs first: the most important thing on the page.
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Text(t.warningSignsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  for (final w in p.warningSigns)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ',
                              style: TextStyle(color: scheme.onErrorContainer)),
                          Expanded(
                            child: Text(w,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(color: scheme.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                  if (p.wardPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError),
                        icon: const Icon(Icons.call_rounded),
                        label: Text('${t.callWard} · ${p.wardPhone}'),
                        onPressed: () => _call(context, p.wardPhone),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(t.scheduleTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final d in days) _DayCard(day: d, isToday: d.day == state.cycleDay),
          const SizedBox(height: 12),

          Text(t.resourcesTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (p.resources.isEmpty)
            Text(t.noResources)
          else
            for (final r in p.resources) _ResourceTile(resource: r),
          const SizedBox(height: 16),

          if (p.pairingCode != null && p.pairingCode!.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded),
              title: Text(t.pairingCodeLabel),
              subtitle: SelectableText(p.pairingCode!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 2)),
            ),
          if (p.disclaimer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p.disclaimer,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const DemoFooter(),
        ],
      ),
    );
  }

  static Future<void> _call(BuildContext context, String phone) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: phone));
      messenger.showSnackBar(SnackBar(content: Text('${t.numberCopied}: $phone')));
    }
  }
}

class _SignOffChip extends StatelessWidget {
  const _SignOffChip({required this.signedOff});
  final bool signedOff;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: signedOff ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(signedOff ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              color: signedOff ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(signedOff ? t.signedOffYes : t.signedOffNo)),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.isToday});
  final PassportDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [...day.items]
      ..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: isToday
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.primary, width: 2))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  day.label.isNotEmpty ? day.label : t.dayN(day.day),
                  if (day.date != null) day.date!,
                  if (isToday) t.today,
                ].join(' · '),
                style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? scheme.primary : null,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(i.time == '24:00' ? '00:00' : i.time,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i.medicine} · ${i.amount}',
                                style: theme.textTheme.bodyLarge),
                            Text(
                              [
                                if (i.route.isNotEmpty) routeLabel(i.route, state.lang),
                                if (i.note != null && i.note!.isNotEmpty) i.note!,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.resource});
  final Resource resource;

  Future<void> _open(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(resource.url),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: resource.url));
      messenger.showSnackBar(SnackBar(content: Text(t.linkCopied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          minTileHeight: 64,
          leading: Icon(resource.isPdf
              ? Icons.picture_as_pdf_rounded
              : Icons.public_rounded),
          title: Text(resource.title),
          subtitle: Text('${resource.institution} · ${resource.format}'),
          trailing: Tooltip(
            message: t.openLink,
            child: const Icon(Icons.open_in_new_rounded),
          ),
          onTap: () => _open(context),
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: resource.url));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t.linkCopied)));
            }
          },
        ),
      ),
    );
  }
}
