import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../pairing/pairing_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final acc = state.account;
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.language, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const LanguagePicker(),
            const SizedBox(height: 24),
            Text(t.child, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<String>(
                groupValue: state.selected?.id,
                onChanged: (id) {
                  if (id != null) state.selectPatient(id);
                },
                child: Column(
                  children: [
                    for (final p in state.patients)
                      RadioListTile<String>(
                        value: p.id,
                        minTileHeight: 56,
                        title: Text(p.alias),
                        subtitle: Text([
                          if (p.age != null) t.ageYears(p.age!),
                          if (p.cycle != null) p.cycle!,
                        ].join(' · ')),
                      ),
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.add_link_rounded),
                      title: Text(t.addChild),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PairingPage())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(t.account, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.person_rounded),
                    title: Text(acc?.displayName ?? ''),
                    subtitle: Text(acc?.email ?? ''),
                  ),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.dns_rounded),
                    title: Text(t.server),
                    subtitle: Text(state.api.baseUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('logout'),
              icon: const Icon(Icons.logout_rounded),
              label: Text(t.logOut),
              onPressed: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await state.logout();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
