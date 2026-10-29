import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../widgets/common.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Logged-in chrome (GOV.UK pattern): AImesis header with account + log out,
/// service navigation, "Prototype" phase banner and the advisory strip.
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
    if (acc == null) return const Scaffold(body: SizedBox.shrink());
    final items = _items(acc);
    final selected = _selected(items);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: GovukHeader(
        serviceName: 'Care team',
        logo: AimesisBrand.logo(height: 38),
        onHomeTap: () => context.go('/worklist'),
        actions: [
          if (width >= 900) ...[
            RoleChip(acc.role),
            const SizedBox(width: 10),
            Text(acc.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: GovukColours.black)),
            const SizedBox(width: 10),
          ] else
            Tooltip(message: acc.displayName, child: RoleChip(acc.role)),
          const SizedBox(width: 6),
          GovukLink(
            'Log out',
            style: GovukType.style(context, GovukType.p19, color: GovukColours.link),
            onTap: () {
              state.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceNavigation(
            items: items,
            selected: selected,
            onSelect: (i) => context.go(items[i].path),
          ),
          GovukPhaseBanner(
            maxWidth: double.infinity,
            text: 'This is a prototype. Not for clinical use.',
            trailing: width >= 1100
                ? Text('API: ${state.config.apiUrl}',
                    style: GovukType.style(context, GovukType.p16, color: theme.colorScheme.onSurfaceVariant))
                : null,
          ),
          const AdvisoryBanner(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// GOV.UK service navigation: a light brand-tinted bar of links under the
/// header; the current page is bold with a 5px brand underline.
class _ServiceNavigation extends StatelessWidget {
  const _ServiceNavigation({required this.items, required this.selected, required this.onSelect});

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      decoration: BoxDecoration(
        color: dark ? GovukColours.darkSurface : GovukColours.brandTintLight,
        border: Border(bottom: BorderSide(color: dark ? GovukColours.darkBorder : GovukColours.brandTint)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: GovukSpacing.s4),
      child: Semantics(
        container: true,
        label: 'Menu',
        child: Wrap(
          spacing: GovukSpacing.s6,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavLink(
                label: narrow ? items[i].label.replaceAll(' (view)', '') : items[i].label,
                icon: i == selected ? items[i].selectedIcon : items[i].icon,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final link = dark ? GovukColours.darkLink : GovukColours.link;
    final text = dark ? GovukColours.darkText : GovukColours.text;
    final accent = dark ? GovukColours.brandOnDark : GovukColours.brand;
    return Semantics(
      selected: selected,
      child: GovukFocusRing.builder(
        onTap: onTap,
        isButton: false,
        semanticLabel: label,
        builder: (context, focused, hovered) {
          final c = focused ? GovukColours.focusText : (selected ? text : link);
          final row = Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 6),
            Text(label,
                style: GovukType.style(context, GovukType.p19, bold: selected, color: c).copyWith(
                  decoration: !selected && hovered && !focused ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: c,
                  decorationThickness: 3,
                )),
          ]);
          return Container(
            padding: const EdgeInsets.only(top: 12, bottom: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? accent : Colors.transparent, width: GovukSpacing.s1),
              ),
            ),
            child: focused ? GovukFocusedText(child: row) : row,
          );
        },
      ),
    );
  }
}
