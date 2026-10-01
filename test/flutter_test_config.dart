import 'dart:async';

import 'package:weeko/core/utils/formats.dart';

/// Tous les tests tournent le mardi 6 octobre 2026 (semaine de la fixture).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  clock = () => DateTime(2026, 10, 6);
  await testMain();
}
