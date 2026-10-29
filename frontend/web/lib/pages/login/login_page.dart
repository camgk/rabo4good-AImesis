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

  /// Demo accounts from the API (quick-pick). Empty / failed → the section
  /// is hidden entirely.
  Future<List<DemoAccount>>? _demoAccounts;
  bool _hasDemoAccounts = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demoAccounts == null) _loadDemoAccounts();
  }

  void _loadDemoAccounts() {
    final f = AppScope.read(context).api.demoAccounts().catchError((Object _) => <DemoAccount>[]);
    _demoAccounts = f;
    f.then((list) {
      if (mounted) setState(() => _hasDemoAccounts = list.isNotEmpty);
    });
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
      // The router's redirect moves us to `from` (or the patient list) once the
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
                                  helperText: _hasDemoAccounts ? 'Demo password: $demoPassword' : null,
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
                              _DemoAccounts(future: _demoAccounts!, onPick: _pick),
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

/// "Demo accounts" quick-pick; renders nothing unless the API returns
/// clinician demo accounts.
class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.future, required this.onPick});
  final Future<List<DemoAccount>> future;
  final ValueChanged<DemoAccount> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<DemoAccount>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.hasError) {
          return const SizedBox.shrink();
        }
        final clinicians = (snap.data ?? const <DemoAccount>[]).where((a) => a.isClinician).toList();
        final family = (snap.data ?? const <DemoAccount>[]).where((a) => a.isFamily).length;
        if (clinicians.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('Demo accounts', style: Theme.of(context).textTheme.labelMedium),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
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
                '$family family account${family == 1 ? '' : 's'} (parent / teen) sign in with the AImesis Family app.',
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
