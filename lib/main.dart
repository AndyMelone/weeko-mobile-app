import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'features/shell/home_shell.dart';
import 'logic/app_state.dart';
import 'logic/nav_state.dart';

void main() {
  runApp(const WeekoApp());
}

class WeekoApp extends StatefulWidget {
  const WeekoApp({super.key, this.api});

  /// Client injecté (tests). Par défaut : config de `.env.json`.
  final ApiClient? api;

  @override
  State<WeekoApp> createState() => _WeekoAppState();
}

class _WeekoAppState extends State<WeekoApp> {
  late final NavState nav = NavState();
  late final AppState app = AppState(
    widget.api ?? ApiClient(baseUrl: apiUrl, apiKey: apiKey),
    onError: nav.showToast,
  )..load();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: nav),
      ],
      child: MaterialApp(
        title: 'Répétiteur',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeShell(),
      ),
    );
  }

  @override
  void dispose() {
    app.dispose();
    nav.dispose();
    super.dispose();
  }
}
