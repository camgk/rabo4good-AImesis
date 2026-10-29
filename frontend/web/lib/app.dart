import 'package:aimesis_a2ui_catalog/aimesis_a2ui_catalog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

class AimesisWebApp extends StatefulWidget {
  const AimesisWebApp({super.key, required this.state});
  final AppState state;

  @override
  State<AimesisWebApp> createState() => _AimesisWebAppState();
}

class _AimesisWebAppState extends State<AimesisWebApp> {
  late final GoRouter _router = buildRouter(widget.state);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp.router(
        title: 'AImesis — Care team',
        debugShowCheckedModeBanner: false,
        theme: AimesisTheme.light(),
        darkTheme: AimesisTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
