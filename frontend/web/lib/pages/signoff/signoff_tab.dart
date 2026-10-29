import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../state/app_scope.dart';
import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';

String _fmtTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? iso : DateFormat('d MMM yyyy, HH:mm').format(d);
}

/// Dual sign-off: oncologist submits, pharmacist approves or returns.
class SignoffTab extends StatefulWidget {
  const SignoffTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  State<SignoffTab> createState() => _SignoffTabState();
}

class _SignoffTabState extends State<SignoffTab> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(String done, Future<Plan> Function(AimesisApi api) call) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.ws.mutate(call);
      _comment.clear();
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = AppScope.of(context).account!;
    final plan = widget.ws.plan!;
    final id = widget.ws.patientId;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _timeline(context, plan),
        const SizedBox(height: 16),
        _actions(context, acc, plan, id),
      ]);
      final right = _comments(context, plan);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: right),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
    });
  }

  Widget _timeline(BuildContext context, Plan plan) {
    final s = plan.status;
    final steps = <_Step>[
      _Step(
        'Draft',
        'Plan computed by the rules engine (advisory)',
        done: true,
        active: s == PlanStatus.draft,
      ),
      _Step(
        'Submitted by oncologist',
        plan.signoffs.oncologist == null
            ? 'Waiting for oncologist sign-off'
            : '${plan.signoffs.oncologist!.by} · ${_fmtTime(plan.signoffs.oncologist!.at)}',
        done: plan.signoffs.oncologist != null,
        active: false,
      ),
      _Step(
        'Awaiting pharmacist check',
        s == PlanStatus.awaitingPharmacist ? 'In the pharmacist queue' : '',
        done: s == PlanStatus.approved || s == PlanStatus.returned,
        active: s == PlanStatus.awaitingPharmacist,
      ),
      if (s == PlanStatus.returned)
        const _Step('Returned', 'Pharmacist returned the plan with a comment — revise and resubmit',
            done: true, active: true, returned: true)
      else
        _Step(
          'Approved',
          plan.signoffs.pharmacist == null
              ? 'Both sign-offs needed before the Passport is final'
              : '${plan.signoffs.pharmacist!.by} · ${_fmtTime(plan.signoffs.pharmacist!.at)}',
          done: s == PlanStatus.approved,
          active: s == PlanStatus.approved,
        ),
    ];
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Sign-off',
      subtitle: 'Advisory only — export needs oncologist and pharmacist',
      icon: Icons.how_to_reg_outlined,
      trailing: PlanStatusChip(plan.status),
      child: Column(children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 32,
                child: Column(children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].returned
                          ? const Color(0xFFEA580C)
                          : steps[i].done
                              ? cs.primary
                              : cs.surfaceContainerHighest,
                      border: steps[i].active ? Border.all(color: cs.primary, width: 3) : null,
                    ),
                    child: Icon(
                      steps[i].returned ? Icons.undo_rounded : (steps[i].done ? Icons.check_rounded : Icons.circle_outlined),
                      size: 14,
                      color: steps[i].done || steps[i].returned ? Colors.white : cs.onSurfaceVariant,
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(child: Container(width: 2, color: steps[i + 1].done ? cs.primary : cs.outlineVariant)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(steps[i].title,
                        style: TextStyle(
                            fontWeight: steps[i].active ? FontWeight.w800 : FontWeight.w600,
                            color: steps[i].done || steps[i].active ? null : cs.onSurfaceVariant)),
                    if (steps[i].detail.isNotEmpty)
                      Text(steps[i].detail, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _actions(BuildContext context, Account acc, Plan plan, String id) {
    final cs = Theme.of(context).colorScheme;
    final canSubmit = acc.isOncologist && !plan.refused && (plan.isDraft || plan.isReturned);
    final canReview = acc.isPharmacist && plan.isAwaitingPharmacist;
    String submitWhy() {
      if (!acc.isOncologist) return 'Only the oncologist can submit the plan';
      if (plan.refused) return 'A refused plan cannot be submitted';
      if (plan.isAwaitingPharmacist) return 'Already waiting for the pharmacist';
      if (plan.isApproved) return 'Plan already approved';
      return 'Submit for pharmacist check';
    }

    String reviewWhy() {
      if (!acc.isPharmacist) return 'Only the hospital pharmacist can approve or return';
      if (!plan.isAwaitingPharmacist) return 'The plan must first be submitted by the oncologist';
      return '';
    }

    return SectionCard(
      title: 'Actions',
      subtitle: 'Signed in as ${acc.displayName}',
      icon: Icons.touch_app_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (acc.isNurse)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Nurse specialists can review the plan and edit risk factors; sign-off is by the oncologist and pharmacist.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 4,
          enabled: canReview && !_busy,
          decoration: InputDecoration(
            labelText: 'Pharmacist comment',
            helperText: canReview ? 'Optional when approving, required when returning' : reviewWhy(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
          Tooltip(
            message: submitWhy(),
            child: FilledButton.icon(
              onPressed: canSubmit && !_busy
                  ? () => _run('Submitted for pharmacist check', (api) => api.submitPlan(id))
                  : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit for pharmacist check'),
            ),
          ),
          Tooltip(
            message: canReview ? 'Return to the oncologist (comment required)' : reviewWhy(),
            child: OutlinedButton.icon(
              onPressed: canReview && !_busy && _comment.text.trim().isNotEmpty
                  ? () => _run('Plan returned to oncologist', (api) => api.returnPlan(id, _comment.text.trim()))
                  : null,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Return with comment'),
            ),
          ),
          Tooltip(
            message: canReview ? 'Approve (pharmacist sign-off)' : reviewWhy(),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
              onPressed: canReview && !_busy
                  ? () => _run('Plan approved — Passport is now signed off', (api) {
                        final c = _comment.text.trim();
                        return api.approvePlan(id, comment: c.isEmpty ? null : c);
                      })
                  : null,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Approve'),
            ),
          ),
        ]),
        if (plan.isApproved) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/patients/$id/passport'),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Open the signed-off Passport'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _comments(BuildContext context, Plan plan) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Comments',
      icon: Icons.forum_outlined,
      child: plan.comments.isEmpty
          ? const EmptyView(icon: Icons.chat_bubble_outline_rounded, title: 'No comments yet')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final c in plan.comments)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(RoleChip.icon(c.role), size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c.by, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(_fmtTime(c.at), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 6),
                    Text(c.text),
                  ]),
                ),
            ]),
    );
  }
}

class _Step {
  const _Step(this.title, this.detail, {required this.done, required this.active, this.returned = false});
  final String title;
  final String detail;
  final bool done;
  final bool active;
  final bool returned;
}
