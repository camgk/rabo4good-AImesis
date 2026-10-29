import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';

/// Minimum touch target for the family app (stressed parent, one hand).
const double kTouch = 56;

/// Small grey footer shown on every screen.
class DemoFooter extends StatelessWidget {
  const DemoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        t.demoFooter,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Segmented NL / FR / EN picker with big targets.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(64, kTouch),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      segments: [
        for (final l in supportedLangs)
          ButtonSegment(
            value: l,
            label: Text(l.toUpperCase(), semanticsLabel: langNames[l]),
            tooltip: langNames[l],
          ),
      ],
      selected: {state.lang},
      onSelectionChanged: (s) => state.setLang(s.first),
    );
  }
}

/// Friendly error text for any exception.
String friendlyError(BuildContext context, Object? error) {
  final t = AppLocalizations.of(context);
  if (error is ApiException && error.isNetworkError) return t.networkError;
  return t.errorLoading;
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(friendlyError(context, error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(160, kTouch)),
            onPressed: onRetry,
            child: Text(t.retry),
          ),
        ],
      ),
    );
  }
}

/// Banner that shows how many logs are waiting on the phone.
class PendingBanner extends StatelessWidget {
  const PendingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final count = state.pending.length;
    if (count == 0) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.schedule_send_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.pendingCount(count),
                  style: TextStyle(color: scheme.onTertiaryContainer)),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, kTouch)),
              onPressed: () => state.flushQueue(),
              child: Text(t.sendNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// Human wording for routes (families, not pharmacists).
String routeLabel(String route, String lang) {
  const labels = {
    'oral_tablet': {'en': 'tablet by mouth', 'nl': 'tablet via de mond', 'fr': 'comprimé par la bouche'},
    'oral_liquid': {'en': 'drink (liquid)', 'nl': 'drankje', 'fr': 'sirop (liquide)'},
    'ng_tube': {'en': 'through the feeding tube', 'nl': 'via de sonde', 'fr': 'par la sonde'},
    'iv': {'en': 'drip (IV)', 'nl': 'via het infuus', 'fr': 'perfusion (IV)'},
  };
  final key = route.trim().toLowerCase();
  return labels[key]?[lang] ?? route;
}

/// Short family-friendly purpose of common antiemetics, shown under the name.
String? medicinePurpose(String medicine, String lang) {
  final m = medicine.toLowerCase();
  const sick = {'en': 'against feeling sick', 'nl': 'tegen misselijkheid', 'fr': 'contre les nausées'};
  const extra = {'en': 'extra help against feeling sick', 'nl': 'extra hulp tegen misselijkheid', 'fr': 'aide supplémentaire contre les nausées'};
  const night = {'en': 'against feeling sick, in the evening', 'nl': "tegen misselijkheid, 's avonds", 'fr': 'contre les nausées, le soir'};
  const rescue = {'en': 'only if still sick (rescue)', 'nl': 'alleen als het kind toch misselijk is', 'fr': 'seulement si les nausées persistent'};
  if (m.contains('ondansetron') || m.contains('palonosetron') || m.contains('granisetron')) return sick[lang];
  if (m.contains('aprepitant') || m.contains('fosaprepitant') || m.contains('dexameth')) return extra[lang];
  if (m.contains('olanzapin')) return night[lang];
  if (m.contains('alizaprid') || m.contains('lorazepam')) return rescue[lang];
  return null;
}
