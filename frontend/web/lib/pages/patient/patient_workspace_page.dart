import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../state/app_scope.dart';
import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';
import '../doses/plan_doses_tab.dart';
import '../interactions/safety_gates_tab.dart';
import '../passport/passport_tab.dart';
import '../personalise/risk_factors_tab.dart';
import '../risk_tier/regimen_tier_tab.dart';
import '../signoff/signoff_tab.dart';
import '../uza_vs_pogo/evidence_tab.dart';
import 'patient_header.dart';

/// `/patients/:id/:tab` — header + tab bar of the clinical flow.
class PatientWorkspacePage extends StatefulWidget {
  const PatientWorkspacePage({super.key, required this.patientId, required this.tab});

  final String patientId;
  final WorkspaceTab tab;

  @override
  State<PatientWorkspacePage> createState() => _PatientWorkspacePageState();
}

class _PatientWorkspacePageState extends State<PatientWorkspacePage> {
  String get patientId => widget.patientId;
  WorkspaceTab get tab => widget.tab;

  @override
  void initState() {
    super.initState();
    // Entering a patient: refresh cached data in the background so changes
    // made by another clinician (e.g. pharmacist approval) show up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.read(context);
      if (app.hasWorkspace(widget.patientId)) app.workspace(widget.patientId).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = AppScope.of(context).workspace(patientId);
    return ListenableBuilder(
      listenable: ws,
      builder: (context, _) {
        if (!ws.ready) {
          if (ws.error != null) {
            return ErrorView(title: 'Could not load $patientId', error: ws.error!, onRetry: ws.load);
          }
          return const LoadingView(label: 'Loading patient and plan…');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PatientHeader(patient: ws.patient!, plan: ws.plan!, refreshing: ws.loading, onRefresh: ws.load),
            _TabStrip(patientId: patientId, current: tab, ws: ws),
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey('ws-$patientId-${tab.path}'),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: _body(ws),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(PatientWorkspace ws) => switch (tab) {
        WorkspaceTab.regimen => RegimenTierTab(ws: ws),
        WorkspaceTab.risk => RiskFactorsTab(ws: ws),
        WorkspaceTab.safety => SafetyGatesTab(ws: ws),
        WorkspaceTab.plan => PlanDosesTab(ws: ws),
        WorkspaceTab.evidence => EvidenceTab(ws: ws),
        WorkspaceTab.signoff => SignoffTab(ws: ws),
        WorkspaceTab.passport => PassportTab(ws: ws),
      };
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.patientId, required this.current, required this.ws});
  final String patientId;
  final WorkspaceTab current;
  final PatientWorkspace ws;

  Widget? _badge(BuildContext context, WorkspaceTab t) {
    final plan = ws.plan!;
    switch (t) {
      case WorkspaceTab.safety:
        final crit = plan.interactions.where((i) => i.isCritical).length;
        final warn = plan.interactions.where((i) => i.isWarning).length;
        if (crit > 0) return _dot(const Color(0xFFDC2626), '$crit');
        if (warn > 0) return _dot(const Color(0xFFD97706), '$warn');
        if (plan.dexamethasone.blocked) return _dot(const Color(0xFFD97706), '!');
        return null;
      case WorkspaceTab.plan:
        return plan.refused ? _dot(const Color(0xFFDC2626), '!') : null;
      case WorkspaceTab.evidence:
        final n = plan.uzaVsPogo.where((r) => r.differs).length;
        return n > 0 ? _dot(const Color(0xFF7C3AED), '$n') : null;
      default:
        return null;
    }
  }

  Widget _dot(Color c, String text) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(builder: (context, c) {
        final showIcons = c.maxWidth >= 1250;
        return Wrap(
          children: [
            for (var i = 0; i < WorkspaceTab.values.length; i++)
              _TabButton(
                index: i + 1,
                tab: WorkspaceTab.values[i],
                selected: WorkspaceTab.values[i] == current,
                showIcon: showIcons,
                badge: _badge(context, WorkspaceTab.values[i]),
                onTap: () => context.go('/patients/$patientId/${WorkspaceTab.values[i].path}'),
              ),
          ],
        );
      }),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.index,
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge,
    this.showIcon = true,
  });
  final bool showIcon;
  final int index;
  final WorkspaceTab tab;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    return Tooltip(
      message: tab.label,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? cs.primary : Colors.transparent, width: 3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : cs.surfaceContainerHighest,
              ),
              child: Text('$index',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            if (showIcon) ...[
              Icon(tab.icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(tab.label,
                style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5)),
            if (badge != null) badge!,
          ]),
        ),
      ),
    );
  }
}
