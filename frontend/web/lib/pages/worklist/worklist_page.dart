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

class WorklistPage extends StatelessWidget {
  const WorklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PatientsLoader(
      builder: (context, patients, reload) {
        final awaiting = patients.where((p) => p.planStatus == PlanStatus.awaitingPharmacist).length;
        final high = patients.where((p) => p.overallTier == Tier.high).length;
        return PageFrame(
          title: 'Worklist',
          subtitle: 'Patients starting or in a chemotherapy cycle · demo data',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
          ],
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Stat(label: 'Patients', value: '${patients.length}', icon: Icons.people_alt_outlined),
              _Stat(label: 'High emetogenic', value: '$high', icon: Icons.local_fire_department_outlined),
              _Stat(label: 'Awaiting pharmacist', value: '$awaiting', icon: Icons.hourglass_top_rounded),
            ]),
            const SizedBox(height: 20),
            if (patients.isEmpty)
              const EmptyView(
                icon: Icons.inbox_outlined,
                title: 'No patients',
                message: 'The demo backend has no patients. Reset the demo data and refresh.',
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
