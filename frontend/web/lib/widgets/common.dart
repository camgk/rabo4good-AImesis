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
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
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
          Text(title, style: Theme.of(context).textTheme.titleSmall),
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
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (story != null) StoryTag(story!),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Small "Story N" tag linking a screen to the UZA user stories.
class StoryTag extends StatelessWidget {
  const StoryTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'UZA user story',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
      ),
    );
  }
}

/// Outlined chip for a patient tag (e.g. "demo").
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key, this.dense = false});
  final String tag;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 1 : 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(tag,
          style: TextStyle(
              fontSize: dense ? 10.5 : 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
    );
  }
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
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }
}

/// Coloured pill for plan workflow status.
class PlanStatusChip extends StatelessWidget {
  const PlanStatusChip(this.status, {super.key, this.dense = false});
  final String? status;
  final bool dense;

  static (Color bg, Color fg, IconData icon) colors(String? status, Brightness b) {
    final dark = b == Brightness.dark;
    switch (status) {
      case PlanStatus.approved:
        return dark
            ? (const Color(0xFF1B4332), const Color(0xFFB7E4C7), Icons.verified_rounded)
            : (const Color(0xFFDCFCE7), const Color(0xFF14532D), Icons.verified_rounded);
      case PlanStatus.awaitingPharmacist:
        return dark
            ? (const Color(0xFF1E3A5F), const Color(0xFFBFDBFE), Icons.hourglass_top_rounded)
            : (const Color(0xFFDBEAFE), const Color(0xFF1E3A8A), Icons.hourglass_top_rounded);
      case PlanStatus.returned:
        return dark
            ? (const Color(0xFF5C2B0E), const Color(0xFFFED7AA), Icons.undo_rounded)
            : (const Color(0xFFFFEDD5), const Color(0xFF7C2D12), Icons.undo_rounded);
      default:
        return dark
            ? (const Color(0xFF2E3436), const Color(0xFFD1D5DB), Icons.edit_note_rounded)
            : (const Color(0xFFF1F5F9), const Color(0xFF334155), Icons.edit_note_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = colors(status, Theme.of(context).brightness);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(PlanStatus.label(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: dense ? 12 : 13)),
          ),
        ],
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon(role), size: 15, color: cs.onPrimaryContainer),
        const SizedBox(width: 6),
        Text(label(role),
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ]),
    );
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
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
