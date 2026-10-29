import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_table.dart';
import '../../onboarding/onboarding_store.dart';
import '../onboarding/onboarding_page.dart';

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

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  /// Selected tag filter; null = all patients.
  String? _tag;

  @override
  Widget build(BuildContext context) {
    return PatientsLoader(
      builder: (context, apiPatients, reload) => ListenableBuilder(
        listenable: AppScope.of(context).onboarding,
        builder: (context, _) {
        final all = withOnboarded(apiPatients, AppScope.of(context).onboarding);
        final tags = (all.expand((p) => p.tags).toSet().toList()..sort());
        final tag = (_tag != null && tags.contains(_tag)) ? _tag : null;
        final patients = tag == null ? all : all.where((p) => p.hasTag(tag)).toList();
        final awaiting = patients.where((p) => p.planStatus == PlanStatus.awaitingPharmacist).length;
        final high = patients.where((p) => p.overallTier == Tier.high).length;
        final app = AppScope.of(context);
        final acc = app.account;
        final canOnboard = acc != null && (acc.isOncologist || acc.isNurse);
        return PageFrame(
          title: 'Patients',
          subtitle: 'Patients starting or in a chemotherapy cycle',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
            if (canOnboard) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('new-patient'),
                onPressed: () {
                  final ref = app.onboarding.createPatient(createdBy: app.account?.displayName ?? '');
                  context.go(OnboardingPage.path(ref.cycle.id, ref.cycle.stage));
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('New patient'),
              ),
            ],
          ],
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Stat(label: 'Total', value: '${patients.length}', icon: Icons.people_alt_outlined),
              _Stat(label: 'High emetogenic', value: '$high', icon: Icons.local_fire_department_outlined),
              _Stat(label: 'Awaiting pharmacist', value: '$awaiting', icon: Icons.hourglass_top_rounded),
            ]),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                key: const Key('patients-tag-filter'),
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.sell_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    ? 'There are no patients yet.'
                    : 'No patients tagged "$tag".',
              )
            else
              PatientTable(
                patients: patients,
                onOpen: (p) => context.go('/patients/${p.id}'),
              ),
          ],
        );
        },
      ),
    );
  }
}

/// API patients plus patients created here, as one list. Rows get an
/// "in progress" tag while a cycle is being onboarded, and new patients a
/// "new" tag.
List<PatientSummary> withOnboarded(List<PatientSummary> api, OnboardingStore store) {
  bool open(String id) => store.patient(id)?.inProgress != null;
  PatientSummary tagged(PatientSummary p, List<String> extra) => PatientSummary(
        id: p.id,
        alias: p.alias,
        age: p.age,
        sex: p.sex,
        diagnosis: p.diagnosis,
        protocol: p.protocol,
        cycle: p.cycle,
        cycleStart: p.cycleStart,
        overallTier: p.overallTier,
        planStatus: p.planStatus,
        language: p.language,
        tags: [...p.tags, ...extra],
      );
  final created = [
    for (final r in store.localPatients)
      if (r.latest != null)
        PatientSummary(
          id: r.id,
          alias: r.displayName,
          age: r.profile.age,
          sex: r.profile.sex,
          diagnosis: r.profile.diagnosis.isEmpty ? null : r.profile.diagnosis,
          protocol: r.latest!.intake.protocol.isEmpty ? null : r.latest!.intake.protocol,
          cycle: r.latest!.intake.cycle.isEmpty ? '${r.numberOf(r.latest!)}' : r.latest!.intake.cycle,
          cycleStart: r.latest!.intake.cycleStart?.toIso8601String().substring(0, 10),
          planStatus: r.latest!.isSent ? PlanStatus.awaitingPharmacist : PlanStatus.draft,
          language: r.profile.language,
          tags: ['new', if (open(r.id)) 'in progress'],
        ),
  ];
  return [
    ...created,
    for (final p in api) open(p.id) ? tagged(p, const ['in progress']) : p,
  ];
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
