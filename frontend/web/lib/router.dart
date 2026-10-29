import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/about/about_page.dart';
import 'pages/login/login_page.dart';
import 'pages/passport/passport_print_page.dart';
import 'pages/patient/patient_workspace_page.dart';
import 'pages/pharmacist_queue/pharmacist_queue_page.dart';
import 'onboarding/onboarding_models.dart';
import 'pages/onboarding/onboarding_page.dart';
import 'pages/patients/patients_page.dart';
import 'shell/app_shell.dart';
import 'state/app_state.dart';

/// Tabs of the patient workspace, in clinical flow order. The path segment
/// is used in `/patients/:id/:tab`.
enum WorkspaceTab {
  regimen('regimen', 'Regimen & tier', Icons.science_outlined, 'Story 1'),
  risk('risk', 'Risk factors', Icons.tune_rounded, 'Story 3'),
  safety('safety', 'Safety gates', Icons.shield_outlined, 'Story 6'),
  plan('plan', 'Plan & doses', Icons.medication_liquid_outlined, 'Stories 2–3'),
  evidence('evidence', 'UZA vs POGO', Icons.compare_arrows_rounded, 'Story 5'),
  signoff('signoff', 'Sign-off', Icons.how_to_reg_outlined, 'Dual sign-off'),
  passport('passport', 'Passport', Icons.badge_outlined, 'Story 4');

  const WorkspaceTab(this.path, this.label, this.icon, this.story);
  final String path;
  final String label;
  final IconData icon;
  final String story;

  static WorkspaceTab fromPath(String? p) =>
      WorkspaceTab.values.firstWhere((t) => t.path == p, orElse: () => WorkspaceTab.regimen);
}

GoRouter buildRouter(AppState state) {
  return GoRouter(
    initialLocation: '/patients',
    refreshListenable: state,
    redirect: (context, s) {
      final loggingIn = s.matchedLocation == '/login';
      if (state.restoring) return null;
      if (!state.isLoggedIn) {
        if (loggingIn) return null;
        final from = s.uri.toString();
        return from == '/' || from == '/patients'
            ? '/login'
            : Uri(path: '/login', queryParameters: {'from': from}).toString();
      }
      if (loggingIn) {
        final from = s.uri.queryParameters['from'];
        return (from != null && from.startsWith('/') && !from.startsWith('/login')) ? from : '/patients';
      }
      if (s.matchedLocation == '/') return '/patients';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/patients'),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/patients/:id/passport/print',
        builder: (_, s) => PassportPrintPage(
          patientId: s.pathParameters['id']!,
          lang: s.uri.queryParameters['lang'] ?? 'en',
        ),
      ),
      ShellRoute(
        builder: (context, s, child) => AppShell(location: s.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/patients',
            pageBuilder: (_, __) => const NoTransitionPage(child: PatientsPage()),
          ),
          // Old links and bookmarks.
          GoRoute(path: '/worklist', redirect: (_, __) => '/patients'),
          GoRoute(
            path: '/pharmacist',
            pageBuilder: (_, __) => const NoTransitionPage(child: PharmacistQueuePage()),
          ),
          GoRoute(
            path: '/about',
            pageBuilder: (_, __) => const NoTransitionPage(child: AboutPage()),
          ),
          GoRoute(
            path: '/onboarding/:id',
            redirect: (_, s) => s.uri.pathSegments.length == 2
                ? '/onboarding/${s.pathParameters['id']}/${OnboardingStage.treatment.path}'
                : null,
            routes: [
              GoRoute(
                path: ':step',
                pageBuilder: (_, s) => NoTransitionPage(
                  key: ValueKey('onboarding-${s.pathParameters['id']}'),
                  child: OnboardingPage(
                    draftId: s.pathParameters['id']!,
                    step: OnboardingStage.fromPath(s.pathParameters['step']),
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/patients/:id',
            redirect: (_, s) => s.uri.pathSegments.length == 2
                ? '/patients/${s.pathParameters['id']}/${WorkspaceTab.regimen.path}'
                : null,
            routes: [
              GoRoute(
                path: ':tab',
                pageBuilder: (_, s) => NoTransitionPage(
                  key: ValueKey('patient-${s.pathParameters['id']}'),
                  child: PatientWorkspacePage(
                    patientId: s.pathParameters['id']!,
                    tab: WorkspaceTab.fromPath(s.pathParameters['tab']),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, s) => Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.explore_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text('Page not found: ${s.uri}'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/patients'), child: const Text('Back to patients')),
        ]),
      ),
    ),
  );
}
