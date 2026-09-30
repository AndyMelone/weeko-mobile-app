import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../eleves/eleve_screen.dart';
import '../pointer/pointer_screen.dart';
import '../preparer/preparer_screen.dart';
import '../rattrapages/rattrapages_screen.dart';
import '../semaine/semaine_screen.dart';

/// Cadre de l'app : écran courant, barre d'onglets, toast.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, LoadStatus>((a) => a.status);
    if (status != LoadStatus.ready) return _Loading(status: status);

    final nav = context.watch<NavState>();
    final screen = switch (nav.screen) {
      AppScreen.semaine => const SemaineScreen(),
      AppScreen.preparer => const PreparerScreen(),
      AppScreen.pointer => PointerScreen(key: ValueKey(nav.sessionId), sessionId: nav.sessionId!),
      AppScreen.rattrapages => const RattrapagesScreen(),
      AppScreen.eleve => const EleveScreen(),
    };

    return PopScope(
      canPop: nav.screen == AppScreen.semaine,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        nav.screen == AppScreen.pointer ? nav.closePointer() : nav.go(AppScreen.semaine);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: screen),
                  const _TabBar(),
                ],
              ),
              if (nav.toast != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 80 + MediaQuery.paddingOf(context).bottom,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(color: AppColors.neutral900, boxShadow: AppColors.shadowLg),
                      child: Text(nav.toast!, style: AppText.body(14, color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavState>();
    final todo = context.select<AppState, int>((a) => a.todoCount);
    final active = nav.screen == AppScreen.pointer ? AppScreen.semaine : nav.screen;

    Widget tab(AppScreen s, AppIcons icon, String label, {int badge = 0}) {
      final on = active == s;
      final fg = on ? AppColors.accent700 : AppColors.neutral700;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => nav.go(s),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: on ? AppColors.accent : Colors.transparent, width: 2)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(icon, size: 22, color: fg),
                      const SizedBox(height: 3),
                      Text(label, style: AppText.body(12, color: fg)),
                    ],
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(17, 0),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            color: AppColors.neutral900,
                            child: Center(
                              widthFactor: 1,
                              child: Text('$badge', style: AppText.body(11, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          tab(AppScreen.semaine, AppIcons.calendar, 'Semaine'),
          tab(AppScreen.preparer, AppIcons.sliders, 'Préparer'),
          tab(AppScreen.rattrapages, AppIcons.rotateCcw, 'Rattrapages', badge: todo),
          tab(AppScreen.eleve, AppIcons.users, 'Élèves'),
        ],
      ),
    );
  }
}

/// Premier chargement de l'état depuis l'API, ou erreur avec « Réessayer ».
class _Loading extends StatelessWidget {
  const _Loading({required this.status});

  final LoadStatus status;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: status == LoadStatus.loading
                ? const CircularProgressIndicator(color: AppColors.accent)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Impossible de charger le planning',
                        style: AppText.heading(20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.select<AppState, String?>((a) => a.error) ?? '',
                        style: AppText.body(15, color: AppColors.neutral700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(label: 'Réessayer', onPressed: app.retry),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
