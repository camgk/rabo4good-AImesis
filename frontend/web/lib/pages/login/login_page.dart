import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/wordmark.dart';

const demoPassword = 'aimesis-demo';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  bool _familyError = false;

  Future<List<DemoAccount>>? _demoAccounts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _demoAccounts ??= AppScope.read(context).api.demoAccounts();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _pick(DemoAccount a) {
    setState(() {
      _email.text = a.email;
      _password.text = demoPassword;
      _error = null;
      _familyError = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _familyError = false;
    });
    final state = AppScope.read(context);
    try {
      // The router's redirect moves us to `from` (or the worklist) once the
      // session is set.
      await state.login(_email.text, _password.text);
    } on FamilyAccountException catch (e) {
      setState(() {
        _error = e.message;
        _familyError = true;
      });
    } catch (e) {
      setState(() => _error = e is ApiException && e.status == 401
          ? 'Email or password not recognised.'
          : errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: Column(
        children: [
          const AdvisoryBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: Wordmark(size: 32)),
                              const SizedBox(height: 8),
                              Center(
                                child: Text('Care team',
                                    style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Text('Paediatric CINV decision support',
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                key: const Key('login-email'),
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email, AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('login-password'),
                                controller: _password,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  helperText: 'Demo password: $demoPassword',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? 'Show password' : 'Hide password',
                                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                _ErrorBox(text: _error!, family: _familyError),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  key: const Key('login-submit'),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                                      : const Text('Log in'),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('Demo accounts', style: theme.textTheme.labelMedium),
                                ),
                                const Expanded(child: Divider()),
                              ]),
                              const SizedBox(height: 12),
                              _DemoAccounts(future: _demoAccounts!, onPick: _pick, onRetry: () {
                                setState(() => _demoAccounts = AppScope.read(context).api.demoAccounts());
                              }),
                              const SizedBox(height: 20),
                              Text(
                                'Hackathon prototype for Solve with Google: Hacking for Good 2026. '
                                'All patients are fictional demo cases (Casus 1–4); dosing uses mock rules '
                                'derived from UZA v2 and must be checked by a clinician.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text, required this.family});
  final String text;
  final bool family;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = family ? cs.tertiaryContainer : cs.errorContainer;
    final fg = family ? cs.onTertiaryContainer : cs.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(family ? Icons.family_restroom_rounded : Icons.error_outline_rounded, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: fg))),
      ]),
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.future, required this.onPick, required this.onRetry});
  final Future<List<DemoAccount>> future;
  final ValueChanged<DemoAccount> onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<DemoAccount>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: SizedBox(height: 32, child: LoadingView()));
        }
        if (snap.hasError) {
          return Column(children: [
            Text('Could not load demo accounts: ${errorMessage(snap.error!)}',
                textAlign: TextAlign.center, style: TextStyle(color: cs.error, fontSize: 12)),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]);
        }
        final clinicians = (snap.data ?? const <DemoAccount>[]).where((a) => a.isClinician).toList();
        final family = (snap.data ?? const <DemoAccount>[]).where((a) => a.isFamily).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in clinicians)
                  ActionChip(
                    avatar: Icon(RoleChip.icon(a.role), size: 18),
                    label: Text(a.displayName),
                    tooltip: a.email,
                    onPressed: () => onPick(a),
                  ),
              ],
            ),
            if (family > 0) ...[
              const SizedBox(height: 10),
              Text(
                '$family family demo account${family == 1 ? '' : 's'} (parent / teen) use the AImesis Family app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
    );
  }
}
