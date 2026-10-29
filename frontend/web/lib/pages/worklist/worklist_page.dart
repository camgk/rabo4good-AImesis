import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_table.dart';

/// Loads `GET /patients` and refetches when a plan changes elsewhere.
class PatientsLoader extends StatefulWidget {
  const PatientsLoader({super.key, required this.builder});
  final Widget Function(BuildContext context, List<PatientSummary> patients, VoidCallback reload) builder;

  @override
  State<PatientsLoader> createState() => _PatientsLoaderState();
}

class _PatientsLoaderState extends State<PatientsLoader> {
  Future<List<PatientSummary>>? _future;
  int _version = -1;

  void _load() {
    final state = AppScope.read(context);
    _version = state.plansVersion;
    _future = state.api.patients().catchError((Object e) {
      if (e is ApiException && e.status == 401) state.handleUnauthorized();
      throw e;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).plansVersion;
    if (_future == null || v != _version) _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PatientSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'Loading patients…');
        }
        if (snap.hasError) {
          return ErrorView(
            title: 'Could not load patients',
            error: snap.error!,
            onRetry: () => setState(_load),
          );
        }
        return widget.builder(context, snap.data ?? const [], () => setState(_load));
      },
    );
  }
}

class WorklistPage extends StatefulWidget {
  const WorklistPage({super.key});

  @override
  State<WorklistPage> createState() => _WorklistPageState();
}

class _WorklistPageState extends State<WorklistPage> {
  /// Selected tag filter; null = all patients.
  String? _tag;

  @override
  Widget build(BuildContext context) {
    return PatientsLoader(
      builder: (context, all, reload) {
        final tags = (all.expand((p) => p.tags).toSet().toList()..sort());
        final tag = (_tag != null && tags.contains(_tag)) ? _tag : null;
        final patients = tag == null ? all : all.where((p) => p.hasTag(tag)).toList();
        final awaiting = patients.where((p) => p.planStatus == PlanStatus.awaitingPharmacist).length;
        final high = patients.where((p) => p.overallTier == Tier.high).length;
        return PageFrame(
          title: 'Worklist',
          subtitle: 'Patients starting or in a chemotherapy cycle',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
          ],
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Stat(label: 'Patients', value: '${patients.length}', icon: Icons.people_alt_outlined),
              _Stat(label: 'High emetogenic', value: '$high', icon: Icons.local_fire_department_outlined),
              _Stat(label: 'Awaiting pharmacist', value: '$awaiting', icon: Icons.hourglass_top_rounded),
            ]),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                key: const Key('worklist-tag-filter'),
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Filter by tag', style: GovukType.style(context, GovukType.p19, bold: true, color: Theme.of(context).colorScheme.onSurface)),
                  FilterChip(
                    label: const Text('All'),
                    selected: tag == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                  for (final t in tags)
                    FilterChip(
                      label: Text(t),
                      selected: tag == t,
                      showCheckmark: false,
                      onSelected: (sel) => setState(() => _tag = sel ? t : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (patients.isEmpty)
              EmptyView(
                icon: Icons.inbox_outlined,
                title: 'No patients',
                message: tag == null
                    ? 'There are no patients on the worklist yet.'
                    : 'No patients tagged "$tag".',
              )
            else
              PatientTable(
                patients: patients,
                onOpen: (p) => context.go('/patients/${p.id}/regimen'),
              ),
          ],
        );
      },
    );
  }
}

/// Headline number, GOV.UK style: big bold figure over a short label with a
/// brand left border.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(GovukSpacing.s3, GovukSpacing.s2, GovukSpacing.s3, GovukSpacing.s2),
      decoration: BoxDecoration(
        color: dark ? GovukColours.darkSurface : GovukColours.brandTintLight,
        border: Border(left: BorderSide(color: dark ? GovukColours.brandOnDark : GovukColours.brand, width: GovukLayout.borderWidth)),
      ),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GovukType.style(context, GovukType.p48, bold: true, color: cs.onSurface)),
          Text(label, style: GovukType.style(context, GovukType.p19, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
