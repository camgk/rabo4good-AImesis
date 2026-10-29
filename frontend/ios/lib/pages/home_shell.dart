import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import 'history/history_page.dart';
import 'log/log_page.dart';
import 'passport/passport_page.dart';
import 'settings/settings_page.dart';
import 'today/today_page.dart';

/// Bottom navigation: Today · Log · History · Passport.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final child = state.selected;
    final pages = [
      TodayPage(onLogTap: () => _go(1)),
      const LogPage(),
      const HistoryPage(),
      const PassportPage(),
    ];
    final titles = [t.navToday, t.navLog, t.navHistory, t.navPassport];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_index]),
            if (child != null)
              Text(child.alias,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('settings'),
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            tooltip: t.settings,
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              selectedIcon: const Icon(Icons.today_rounded),
              label: t.navToday),
          NavigationDestination(
              icon: const Icon(Icons.add_circle_outline_rounded),
              selectedIcon: const Icon(Icons.add_circle_rounded),
              label: t.navLog),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart_rounded),
              label: t.navHistory),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book_rounded),
              label: t.navPassport),
        ],
      ),
    );
  }
}
