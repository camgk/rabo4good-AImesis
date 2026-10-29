import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'config.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final config = await AppConfig.load();
  final state = AppState(config: config);
  await state.restore();
  runApp(AimesisWebApp(state: state));
}
