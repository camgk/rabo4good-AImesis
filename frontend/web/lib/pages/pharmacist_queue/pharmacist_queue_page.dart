import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_table.dart';
import '../worklist/worklist_page.dart';

/// Plans awaiting the pharmacist check first, then everything else.
class PharmacistQueuePage extends StatelessWidget {
  const PharmacistQueuePage({super.key});

  static int _order(String? status) => switch (status) {
        PlanStatus.awaitingPharmacist => 0,
        PlanStatus.returned => 1,
        PlanStatus.draft => 2,
        PlanStatus.approved => 3,
        _ => 4,
      };

  @override
  Widget build(BuildContext context) {
    final acc = AppScope.of(context).account;
    final isPharmacist = acc?.isPharmacist ?? false;
    return PatientsLoader(builder: (context, patients, reload) {
      final sorted = [...patients]..sort((a, b) => _order(a.planStatus).compareTo(_order(b.planStatus)));
      final waiting = sorted.where((p) => p.planStatus == PlanStatus.awaitingPharmacist).toList();
      final others = sorted.where((p) => p.planStatus != PlanStatus.awaitingPharmacist).toList();
      void open(PatientSummary p) => context.go('/patients/${p.id}/signoff');
      return PageFrame(
        title: 'Pharmacist queue',
        subtitle: isPharmacist
            ? 'Check submitted plans, then approve or return them with a comment.'
            : 'Read-only view: only the hospital pharmacist can approve or return plans.',
        actions: [IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh_rounded))],
        children: [
          Text('Awaiting pharmacist check (${waiting.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (waiting.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: EmptyView(
                icon: Icons.task_alt_rounded,
                title: 'Nothing waiting',
                message: 'Plans appear here once the oncologist submits them for pharmacist check.',
              ),
            )
          else
            PatientTable(patients: waiting, onOpen: open, actionLabel: 'Open sign-off'),
          const SizedBox(height: 28),
          Text('Other plans (${others.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (others.isNotEmpty) PatientTable(patients: others, onOpen: open, actionLabel: 'Open sign-off'),
        ],
      );
    });
  }
}
