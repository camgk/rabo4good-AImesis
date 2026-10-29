import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One step in the trail; [path] null for the current page.
class Crumb {
  final String label;
  final String? path;
  const Crumb(this.label, [this.path]);
}

/// "Patients › Casus 3 › Cycle IE #3" — where you are, with links back up.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs(this.crumbs, {super.key});
  final List<Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Semantics(
      container: true,
      label: 'Breadcrumb',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
              ),
            if (crumbs[i].path != null)
              InkWell(
                key: Key('crumb-${crumbs[i].label}'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.go(crumbs[i].path!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(crumbs[i].label,
                      style: style?.copyWith(color: cs.primary, fontWeight: FontWeight.w500)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(crumbs[i].label, style: style?.copyWith(color: cs.onSurfaceVariant)),
              ),
          ],
        ],
      ),
    );
  }
}
