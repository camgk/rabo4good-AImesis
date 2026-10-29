import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/gen/app_localizations.dart';
import 'pages/home_shell.dart';
import 'pages/login/login_page.dart';
import 'pages/pairing/pairing_page.dart';
import 'state/app_state.dart';

class AimesisFamilyApp extends StatelessWidget {
  const AimesisFamilyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final s = AppScope.of(context);
        return MaterialApp(
          title: 'AImesis',
          debugShowCheckedModeBanner: false,
          theme: _family(AimesisTheme.light()),
          darkTheme: _family(AimesisTheme.dark()),
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => _PhoneWidth(child: child!),
          home: const _Root(),
        );
      }),
    );
  }

  /// Family tweaks on top of the shared theme: bigger buttons and text fields.
  static ThemeData _family(ThemeData base) => base.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 56),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        navigationBarTheme: base.navigationBarTheme.copyWith(height: 72),
      );
}

/// On web/tablet keep the layout phone-sized and centred.
class _PhoneWidth extends StatelessWidget {
  const _PhoneWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!s.loggedIn) return const LoginPage();
    if (s.patients.isEmpty) return const PairingPage(firstChild: true);
    return const HomeShell();
  }
}
