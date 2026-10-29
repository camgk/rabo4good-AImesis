import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

/// Human message for any error thrown by the API client.
String errorMessage(Object error) {
  if (error is ApiException) {
    return error.status == 0
        ? 'Cannot reach the AImesis API (${error.message}).'
        : '${error.message} (HTTP ${error.status})';
  }
  final s = error.toString();
  if (s.contains('XMLHttpRequest') || s.contains('ClientException')) {
    return 'Cannot reach the AImesis API. Is the backend running?';
  }
  return s;
}

/// Centered loading indicator with an optional label.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with the API message and a Retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.title});
  final Object error;
  final VoidCallback? onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: cs.error),
              const SizedBox(height: 12),
              Text(title ?? 'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              SelectableText(errorMessage(error),
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                GovukButton.secondary(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: cs.outline),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// A titled card section used across the workspace.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
    this.story,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final String? story;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // GOV.UK summary-card pattern: grey title bar, 1px border, square corners.
    return Material(
      color: cs.surface,
      shape: Border.all(color: cs.outlineVariant),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: cs.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(GovukSpacing.s3, 12, GovukSpacing.s3, 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: cs.onSurface),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: GovukType.style(context, GovukType.p24, bold: true, color: cs.onSurface)),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                if (story != null) StoryTag(story!),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
          Padding(padding: _pad(padding), child: child),
        ],
      ),
    );
  }

  /// Old cards used 16px gutters; GOV.UK uses 15px.
  EdgeInsetsGeometry _pad(EdgeInsetsGeometry p) {
    if (p == const EdgeInsets.fromLTRB(16, 4, 16, 16)) return const EdgeInsets.all(GovukSpacing.s3);
    return p;
  }
}

/// Small "Story N" tag linking a screen to the UZA user stories.
class StoryTag extends StatelessWidget {
  const StoryTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'UZA user story',
        child: GovukTag(label, colour: GovukTagColour.brandTint, small: true),
      );
}

/// Patient tag (e.g. "demo") as a GOV.UK tag; same tag → same colour.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key, this.dense = false});
  final String tag;
  final bool dense;

  @override
  Widget build(BuildContext context) => GovukTag(tag, colour: GovukMapping.patientTag(tag), small: true);
}

/// Muted source / rule citation line, e.g. "UZA v2 (mock rules)".
class SourceLabel extends StatelessWidget {
  const SourceLabel(this.text, {super.key, this.icon = Icons.menu_book_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text, style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// Plan workflow status as a GOV.UK tag: draft grey, awaiting pharmacist
/// yellow, returned orange, approved green.
class PlanStatusChip extends StatelessWidget {
  const PlanStatusChip(this.status, {super.key, this.dense = false});
  final String? status;
  final bool dense;

  static GovukTagColour tagColour(String? status) => switch (status) {
        PlanStatus.approved => GovukTagColour.green,
        PlanStatus.awaitingPharmacist => GovukTagColour.yellow,
        PlanStatus.returned => GovukTagColour.orange,
        _ => GovukTagColour.grey,
      };

  /// Background / foreground / icon for callers that draw their own surface.
  static (Color bg, Color fg, IconData icon) colors(String? status, Brightness b) {
    final c = tagColour(status);
    final icon = switch (status) {
      PlanStatus.approved => Icons.verified_rounded,
      PlanStatus.awaitingPharmacist => Icons.hourglass_top_rounded,
      PlanStatus.returned => Icons.undo_rounded,
      _ => Icons.edit_note_rounded,
    };
    return (c.background, c.foreground, icon);
  }

  @override
  Widget build(BuildContext context) =>
      GovukTag(PlanStatus.label(status), colour: tagColour(status), small: dense, semanticLabel: 'Plan status: ${PlanStatus.label(status)}');
}

/// Role chip shown in the app bar.
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});
  final String role;

  static IconData icon(String role) => switch (role) {
        Role.oncologist => Icons.medical_services_outlined,
        Role.nurse => Icons.health_and_safety_outlined,
        Role.pharmacist => Icons.medication_outlined,
        _ => Icons.family_restroom_outlined,
      };

  static String label(String role) => switch (role) {
        Role.oncologist => 'Oncologist',
        Role.nurse => 'Nurse specialist',
        Role.pharmacist => 'Pharmacist',
        Role.parent => 'Parent',
        Role.patient => 'Patient',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    return GovukTag(label(role), colour: GovukTagColour.brandTint, small: true, semanticLabel: 'Role: ${label(role)}');
  }
}

/// Label/value pair used in headers.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: GovukType.style(context, GovukType.p19, bold: true, color: cs.onSurface)),
      ],
    );
  }
}

/// Capitalise the first letter of a drug name etc.
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "1–3" / "1, 3, 5" style day list.
String formatDays(List<int> days) {
  if (days.isEmpty) return '—';
  final sorted = [...days]..sort();
  var contiguous = true;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] != sorted[i - 1] + 1) contiguous = false;
  }
  if (sorted.length == 1) return 'Day ${sorted.first}';
  if (contiguous) return 'Days ${sorted.first}–${sorted.last}';
  return 'Days ${sorted.join(', ')}';
}

/// Format a number without trailing ".0" when integral.
String fmtNum(num v, {int decimals = 1}) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(decimals);
}
