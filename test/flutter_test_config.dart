import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeko/core/utils/formats.dart';

/// Tous les tests tournent le mardi 6 octobre 2026 (semaine de la fixture).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  clock = () => DateTime(2026, 10, 6);
  // Stockage local simulé (cache hors ligne).
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
