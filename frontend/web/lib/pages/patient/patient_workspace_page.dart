import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
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
        if (crit > 0) return _dot(GovukTagColour.red, '$crit critical');
        if (warn > 0) return _dot(GovukTagColour.orange, '$warn');
        if (plan.dexamethasone.blocked) return _dot(GovukTagColour.orange, '!');
        return null;
      case WorkspaceTab.plan:
        return plan.refused ? _dot(GovukTagColour.red, 'refused') : null;
      case WorkspaceTab.evidence:
        final n = plan.uzaVsPogo.where((r) => r.differs).length;
        return n > 0 ? _dot(GovukTagColour.purple, '$n') : null;
      default:
        return null;
    }
  }

  Widget _dot(GovukTagColour c, String text) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GovukTag(text, colour: c, small: true),
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
      padding: EdgeInsets.symmetric(horizontal: GovukLayout.isTablet(context) ? GovukSpacing.s6 : GovukSpacing.s3),
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
    // GOV.UK tabs: unselected tabs are underlined links on a grey tab;
    // the selected tab is a white box with borders joined to the panel.
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final link = dark ? GovukColours.darkLink : GovukColours.link;
    return Tooltip(
      message: tab.story,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.only(right: 5, top: 10),
          child: GovukFocusRing.builder(
            onTap: onTap,
            semanticLabel: 'Step $index: ${tab.label}',
            builder: (context, focused, hovered) {
              final fg = focused ? GovukColours.focusText : (selected ? cs.onSurface : link);
              final label = Text(tab.label,
                  style: GovukType.style(context, GovukType.p19, bold: selected, color: fg).copyWith(
                    decoration: selected || focused ? TextDecoration.none : TextDecoration.underline,
                    decorationColor: fg,
                    decorationThickness: hovered ? 3 : 1.5,
                  ));
              final row = Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$index. ', style: GovukType.style(context, GovukType.p19, bold: selected, color: fg)),
                if (showIcon) ...[
                  Icon(tab.icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                label,
                if (badge != null) badge!,
              ]);
              return Container(
                padding: EdgeInsets.fromLTRB(15, selected ? 12 : 10, 15, selected ? 13 : 10),
                decoration: BoxDecoration(
                  color: selected ? cs.surface : (dark ? GovukColours.darkSurfaceHigh : GovukColours.lightGrey),
                  border: selected
                      ? Border(
                          top: BorderSide(color: dark ? GovukColours.brandOnDark : GovukColours.brand, width: 5),
                          left: BorderSide(color: cs.outlineVariant),
                          right: BorderSide(color: cs.outlineVariant),
                        )
                      : null,
                ),
                child: focused ? GovukFocusedText(child: row) : row,
              );
            },
          ),
        ),
      ),
    );
  }
}
