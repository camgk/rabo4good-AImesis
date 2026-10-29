import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../platform/browser.dart';
import '../../state/app_scope.dart';
import '../../state/patient_workspace.dart';
import '../../widgets/common.dart';

const _langs = {'nl': 'Nederlands', 'fr': 'Français', 'en': 'English'};

const _ui = {
  'nl': {
    'schedule': 'Schema per dag',
    'warning': 'Bel de afdeling als',
    'phone': 'Afdeling (24/7)',
    'resources': 'Meer informatie',
    'pair': 'Scan of voer code {code} in in de AImesis Family-app',
    'time': 'Uur',
    'medicine': 'Geneesmiddel',
    'amount': 'Dosis',
    'route': 'Hoe',
  },
  'fr': {
    'schedule': 'Schéma par jour',
    'warning': 'Appelez le service si',
    'phone': 'Service (24h/24)',
    'resources': "Plus d'informations",
    'pair': "Scannez ou saisissez le code {code} dans l'app AImesis Family",
    'time': 'Heure',
    'medicine': 'Médicament',
    'amount': 'Dose',
    'route': 'Comment',
  },
  'en': {
    'schedule': 'Daily schedule',
    'warning': 'Call the ward if',
    'phone': 'Ward (24/7)',
    'resources': 'More information',
    'pair': 'Scan or enter code {code} in the AImesis Family app',
    'time': 'Time',
    'medicine': 'Medicine',
    'amount': 'Dose',
    'route': 'How',
  },
};

/// Story 4 — CINV Patient Passport (one page, NL/FR/EN).
class PassportTab extends StatefulWidget {
  const PassportTab({super.key, required this.ws});
  final PatientWorkspace ws;

  @override
  State<PassportTab> createState() => _PassportTabState();
}

class _PassportTabState extends State<PassportTab> {
  late String _lang = _langs.containsKey(widget.ws.patient!.language) ? widget.ws.patient!.language! : 'en';
  Future<Passport>? _future;
  String? _planStatus;

  void _load() {
    _planStatus = widget.ws.plan?.status;
    _future = AppScope.read(context).api.passport(widget.ws.patientId, _lang);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null || _planStatus != widget.ws.plan?.status) _load();
  }

  @override
  void didUpdateWidget(covariant PassportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_planStatus != widget.ws.plan?.status) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SegmentedButton<String>(
              segments: [
                for (final e in _langs.entries)
                  ButtonSegment(value: e.key, label: Text('${e.key.toUpperCase()} · ${e.value}')),
              ],
              selected: {_lang},
              onSelectionChanged: (s) => setState(() {
                _lang = s.first;
                _load();
              }),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const StoryTag('Story 4'),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.go('/patients/${widget.ws.patientId}/passport/print?lang=$_lang'),
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print view'),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<Passport>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView(label: 'Building passport…');
            if (snap.hasError) {
              return ErrorView(title: 'Could not load the passport', error: snap.error!, onRetry: () => setState(_load));
            }
            return Center(child: PassportCard(passport: snap.data!, lang: _lang));
          },
        ),
      ],
    );
  }
}

/// The printable one-page passport. Always rendered light (paper).
class PassportCard extends StatelessWidget {
  const PassportCard({super.key, required this.passport, required this.lang, this.flat = false});
  final Passport passport;
  final String lang;

  /// No shadow / rounded border (print view).
  final bool flat;

  String t(String key) => (_ui[lang] ?? _ui['en']!)[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final p = passport;
    return Theme(
      data: AimesisTheme.light(),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(flat ? 0 : 6),
              border: flat ? null : Border.all(color: const Color(0xFFD5DDDB)),
              boxShadow: flat ? null : const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Color(0xFF1F2A28)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _header(context, cs),
                      const SizedBox(height: 18),
                      if (!p.signedOff) _draftBanner(),
                      if (!p.signedOff) const SizedBox(height: 14),
                      Text(t('schedule'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (p.days.isEmpty)
                        const Text('—')
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [for (final d in p.days) _dayTable(context, d)],
                        ),
                      const SizedBox(height: 20),
                      LayoutBuilder(builder: (context, c) {
                        final warn = _warnings(context);
                        final contact = _contact(context);
                        if (c.maxWidth > 600) {
                          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 3, child: warn),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: contact),
                          ]);
                        }
                        return Column(children: [warn, const SizedBox(height: 16), contact]);
                      }),
                      const SizedBox(height: 20),
                      _resources(context),
                      const SizedBox(height: 18),
                      const Divider(),
                      Text(
                        p.disclaimer.isEmpty ? AimesisTheme.advisoryText : p.disclaimer,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF5B6B68)),
                      ),
                    ]),
                  ),
                ),
                if (!p.signedOff)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.35,
                          child: const Text(
                            'DRAFT — not signed off',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Color(0x1FDC2626),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _header(BuildContext context, ColorScheme cs) {
    final p = passport;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AImesis · CINV Passport', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(p.title.isEmpty ? 'CINV Passport' : p.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 4),
          Text(p.alias, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (p.overallTier != null) TierBadge(tier: p.overallTier!),
        const SizedBox(height: 8),
        p.signedOff
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, size: 16, color: Color(0xFF14532D)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text('Signed off · oncologist + pharmacist',
                        style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ]),
              )
            : PlanStatusChip(p.status, dense: true),
      ]),
    ]);
  }

  Widget _draftBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(children: [
          Icon(Icons.edit_off_rounded, color: Color(0xFFB91C1C), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('DRAFT — not signed off. Do not hand to the family until oncologist and pharmacist have signed.',
                style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _dayTable(BuildContext context, PassportDay d) {
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5B6B68));
    return Container(
      width: 380,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DDDB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFFE6F2F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(d.label.isEmpty ? 'Day ${d.day}' : d.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (d.date != null) Text(d.date!, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B68))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Row(children: [
            SizedBox(width: 52, child: Text(t('time'), style: head)),
            Expanded(flex: 4, child: Text(t('medicine'), style: head)),
            Expanded(flex: 2, child: Text(t('amount'), style: head)),
            Expanded(flex: 3, child: Text(t('route'), style: head)),
          ]),
        ),
        for (final it in d.items)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 52, child: Text(it.time, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                flex: 4,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.medicine, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (it.note != null && it.note!.isNotEmpty)
                    Text(it.note!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF5B6B68))),
                ]),
              ),
              Expanded(flex: 2, child: Text(it.amount)),
              Expanded(flex: 3, child: Text(it.route)),
            ]),
          ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _warnings(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t('warning'), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF78350F))),
            ),
          ]),
          const SizedBox(height: 6),
          for (final w in passport.warningSigns)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: Color(0xFF78350F))),
                Expanded(child: Text(w, style: const TextStyle(color: Color(0xFF78350F)))),
              ]),
            ),
        ]),
      );

  Widget _contact(BuildContext context) {
    final code = passport.pairingCode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5DDDB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('phone'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5B6B68))),
        Row(children: [
          const Icon(Icons.call_rounded, size: 20, color: Color(0xFF0F766E)),
          const SizedBox(width: 6),
          Flexible(
            child: SelectableText(passport.wardPhone.isEmpty ? '—' : passport.wardPhone,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (code != null && code.isNotEmpty) ...[
          const Divider(height: 22),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            QrImageView(
              data: code,
              size: 104,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              semanticsLabel: 'Pairing code $code',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(code,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Text(t('pair').replaceAll('{code}', code), style: const TextStyle(fontSize: 12.5)),
                if (lang != 'en')
                  Text('Scan or enter code $code in the AImesis Family app',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B68))),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _resources(BuildContext context) {
    if (passport.resources.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('resources'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      for (final r in passport.resources)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(r.isPdf ? Icons.picture_as_pdf_outlined : Icons.public_rounded, size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.title} — ${r.institution}', style: const TextStyle(fontWeight: FontWeight.w600)),
                SelectableText(r.url, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F766E))),
              ]),
            ),
            IconButton(
              tooltip: 'Open link',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              onPressed: () => openUrl(r.url),
            ),
          ]),
        ),
    ]);
  }
}
