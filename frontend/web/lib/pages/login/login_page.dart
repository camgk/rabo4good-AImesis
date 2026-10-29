import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

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

  /// GOV.UK validation: field errors shown in the error summary and beside
  /// each field.
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  List<GovukErrorItem> _fieldErrors = const [];

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
    _emailFocus.dispose();
    _passwordFocus.dispose();
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

  static String? _emailError(String? v) => (v == null || !v.contains('@')) ? 'Enter your email' : null;
  static String? _passwordError(String? v) => (v == null || v.isEmpty) ? 'Enter your password' : null;

  Future<void> _submit() async {
    final errors = <GovukErrorItem>[
      if (_emailError(_email.text) case final m?) GovukErrorItem(m, onTap: _emailFocus.requestFocus),
      if (_passwordError(_password.text) case final m?) GovukErrorItem(m, onTap: _passwordFocus.requestFocus),
    ];
    setState(() => _fieldErrors = errors);
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
    final gutter = GovukLayout.isTablet(context) ? GovukLayout.gutter : GovukLayout.gutterHalf;
    return Scaffold(
      appBar: GovukHeader(serviceName: 'Care team', logo: AimesisBrand.logo(height: 38)),
      body: Column(
        children: [
          const GovukPhaseBanner(maxWidth: double.infinity),
          const AdvisoryBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, GovukSpacing.of(context, 7), gutter, GovukSpacing.of(context, 8)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_fieldErrors.isNotEmpty) ...[
                            GovukErrorSummary(key: ValueKey(_fieldErrors.length), errors: _fieldErrors),
                            const SizedBox(height: GovukSpacing.s6),
                          ] else if (_error != null && !_familyError) ...[
                            GovukErrorSummary(errors: [GovukErrorItem(_error!)]),
                            const SizedBox(height: GovukSpacing.s6),
                          ],
                          const GovukHeading('Log in', caption: 'Paediatric CINV decision support'),
                          TextFormField(
                            key: const Key('login-email'),
                            controller: _email,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            style: theme.textTheme.bodyLarge,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: _emailError,
                          ),
                          const SizedBox(height: GovukSpacing.s6),
                          TextFormField(
                            key: const Key('login-password'),
                            controller: _password,
                            focusNode: _passwordFocus,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              helperText: _hasDemoAccounts ? 'Demo password: $demoPassword' : null,
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: _passwordError,
                          ),
                          if (_error != null && _familyError) ...[
                            const SizedBox(height: GovukSpacing.s6),
                            _ErrorBox(text: _error!, family: _familyError),
                          ],
                          const SizedBox(height: GovukSpacing.s6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              key: const Key('login-submit'),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
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
        ],
      ),
    );
  }
}

/// Family account on the care-team app: GOV.UK notification banner (an
/// important message, not a validation error).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text, required this.family});
  final String text;
  final bool family;

  @override
  Widget build(BuildContext context) => GovukNotificationBanner(text: text);
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
            const Divider(),
            const SizedBox(height: GovukSpacing.s4),
            const GovukHeading('Demo accounts', size: GovukHeadingSize.m),
            Wrap(
              spacing: GovukSpacing.s3,
              runSpacing: GovukSpacing.s3,
              children: [
                for (final a in clinicians)
                  Tooltip(
                    message: a.email,
                    child: OutlinedButton.icon(
                      icon: Icon(RoleChip.icon(a.role), size: 20),
                      label: Text(a.displayName),
                      onPressed: () => onPick(a),
                    ),
                  ),
              ],
            ),
            if (family > 0) ...[
              const SizedBox(height: GovukSpacing.s3),
              Text(
                '$family family account${family == 1 ? '' : 's'} (parent / teen) sign in with the AImesis Family app.',
                style: GovukType.style(context, GovukType.p16, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
    );
  }
}
