import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../widgets/common.dart';
import '../widgets/wordmark.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Logged-in chrome: app bar with account + logout, role-aware navigation
/// rail, and the advisory banner above every page.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  List<_NavItem> _items(Account acc) => [
        const _NavItem('/worklist', 'Worklist', Icons.people_alt_outlined, Icons.people_alt_rounded),
        _NavItem(
          '/pharmacist',
          acc.isPharmacist ? 'Pharmacist queue' : 'Pharmacist queue (view)',
          Icons.fact_check_outlined,
          Icons.fact_check_rounded,
        ),
        const _NavItem('/about', 'About', Icons.info_outline_rounded, Icons.info_rounded),
      ];

  int _selected(List<_NavItem> items) {
    if (location.startsWith('/patients')) return 0;
    final i = items.indexWhere((it) => location.startsWith(it.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final acc = state.account;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (acc == null) return const Scaffold(body: SizedBox.shrink());
    final items = _items(acc);
    final selected = _selected(items);
    final width = MediaQuery.sizeOf(context).width;
    final extended = width >= 1440;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 60,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
        title: InkWell(
          onTap: () => context.go('/worklist'),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Wordmark(subtitle: 'Care team', size: 22),
          ),
        ),
        actions: [
          if (width >= 900) ...[
            RoleChip(acc.role),
            const SizedBox(width: 10),
            Text(acc.displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ] else
            Tooltip(message: acc.displayName, child: RoleChip(acc.role)),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Log out',
            child: TextButton.icon(
              onPressed: () {
                state.logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: selected,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            backgroundColor: cs.surfaceContainerLow,
            onDestinationSelected: (i) => context.go(items[i].path),
            destinations: [
              for (final it in items)
                NavigationRailDestination(
                  icon: Icon(it.icon),
                  selectedIcon: Icon(it.selectedIcon),
                  label: Text(extended ? it.label : it.label.replaceAll(' (view)', '').replaceAll(' queue', '')),
                ),
            ],
            trailing: extended
                ? Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: 188,
                          child: Text(
                            'API: ${state.config.apiUrl}',
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdvisoryBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
