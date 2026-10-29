import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../platform/browser.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'passport_tab.dart';

/// `/patients/:id/passport/print?lang=nl` — the passport alone on a white
/// page (no app chrome), so the browser's print output is just the passport.
class PassportPrintPage extends StatefulWidget {
  const PassportPrintPage({super.key, required this.patientId, required this.lang});
  final String patientId;
  final String lang;

  @override
  State<PassportPrintPage> createState() => _PassportPrintPageState();
}

class _PassportPrintPageState extends State<PassportPrintPage> {
  Future<Passport>? _future;
  bool _printing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.read(context).api.passport(widget.patientId, widget.lang);
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    // Let the toolbar disappear from the canvas before the print dialog.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    printPage();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_printing)
            Material(
              color: const Color(0xFFF1F5F4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () => context.go('/patients/${widget.patientId}/passport'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to workspace'),
                  ),
                  const Spacer(),
                  const Text('Print view · toolbar is hidden while printing',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5B6B68))),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _print,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                ]),
              ),
            ),
          Expanded(
            child: FutureBuilder<Passport>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) return ErrorView(error: snap.error!);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: PassportCard(passport: snap.data!, lang: widget.lang, flat: true)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
