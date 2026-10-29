import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

const demoPassword = 'aimesis-demo';

/// Welcome + sign-in. Shows family demo accounts as one-tap chips, only when
/// the API returns some.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late Future<List<DemoAccount>> _demo;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _demo = AppScope.read(context)
        .api
        .demoAccounts()
        .catchError((Object _) => <DemoAccount>[]);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).login(_email.text.trim(), _password.text);
    } on ClinicianAccountException {
      _error = t.clinicianNotAllowed;
    } on ApiException catch (e) {
      _error = e.isNetworkError ? t.networkError : t.loginFailed;
    } catch (_) {
      _error = t.loginFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(DemoAccount a) {
    setState(() {
      _email.text = a.email;
      _password.text = demoPassword;
      _error = a.isClinician
          ? AppLocalizations.of(context).clinicianNotAllowed
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          children: [
            Align(alignment: Alignment.centerRight, child: const LanguagePicker()),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.water_drop_rounded,
                      color: scheme.onPrimary, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.appTitle,
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(t.forFamilies,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: scheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(t.welcomeIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 28),
            TextField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: t.emailLabel,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.go,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: t.passwordLabel,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('signIn'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3))
                  : Text(t.signIn),
            ),
            FutureBuilder<List<DemoAccount>>(
              future: _demo,
              builder: (context, snap) {
                final family = (snap.data ?? const <DemoAccount>[])
                    .where((a) => a.isFamily)
                    .toList();
                if (snap.connectionState != ConnectionState.done ||
                    family.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  key: const Key('demoAccounts'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Text(t.demoAccounts, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(t.demoPasswordHint(demoPassword),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in family)
                          ActionChip(
                            key: Key('demo-${a.email}'),
                            avatar: Icon(
                              a.role == Role.patient
                                  ? Icons.face_rounded
                                  : Icons.family_restroom_rounded,
                              size: 20,
                            ),
                            label: Text(a.displayName),
                            labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 10),
                            onPressed: () => _fill(a),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
