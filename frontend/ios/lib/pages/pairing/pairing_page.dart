import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Connect a child to this account with the code from the ward (e.g. C2-ALL8).
class PairingPage extends StatefulWidget {
  const PairingPage({super.key, this.firstChild = false});

  /// True when shown because the account has no child yet (no back button).
  final bool firstChild;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final t = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await AppScope.read(context).pair(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.pairSuccess(p.alias))));
      if (!widget.firstChild) Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      setState(() => _error = e.isNetworkError ? t.networkError : t.pairFailed);
    } catch (_) {
      setState(() => _error = t.pairFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pairTitle),
        automaticallyImplyLeading: !widget.firstChild,
        actions: [
          if (widget.firstChild)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, kTouch)),
              onPressed: state.logout,
              child: Text(t.logOut),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.link_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(t.pairIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(
              key: const Key('pairCode'),
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(16),
              ],
              style: theme.textTheme.headlineSmall
                  ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _pair(),
              decoration: InputDecoration(
                labelText: t.pairCodeLabel,
                hintText: t.pairCodeHint('C2-ALL8'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _pair,
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3))
                  : Text(t.pairButton),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
