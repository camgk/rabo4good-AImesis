import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final baseUrl = await resolveApiUrl();
  final state = AppState(api: AimesisApi(baseUrl: baseUrl), prefs: prefs);
  WidgetsBinding.instance.addObserver(state);
  runApp(AimesisFamilyApp(state: state));
  await state.restore();
}
