import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_data.dart';

enum AppScreen { semaine, preparer, pointer, rattrapages, eleve }

/// État de navigation et d'interface (écran courant, semaine affichée, toast).
class NavState extends ChangeNotifier {
  AppScreen screen = AppScreen.semaine;

  /// Écran à retrouver en quittant « Pointer ».
  AppScreen back = AppScreen.semaine;

  /// Semaine affichée dans « Ma semaine » (0 = semaine de démo).
  int week = 0;

  /// Semaine affichée dans « Préparer » (0 = en cours).
  int prepWeek = 1;
  String? sessionId;
  String studentId = 'ange';
  bool addingStudent = false;

  /// Jour vers lequel défiler dans « Ma semaine » (consommé par l'écran).
  ({int week, int day})? scrollTarget;

  String? toast;
  Timer? _toastTimer;

  void go(AppScreen s) {
    screen = s;
    notifyListeners();
  }

  void setWeek(int w) {
    week = w;
    notifyListeners();
  }

  void setPrepWeek(int w) {
    prepWeek = w < 0 ? 0 : w;
    notifyListeners();
  }

  void openPreparer(int w) {
    prepWeek = w < 0 ? 0 : w;
    screen = AppScreen.preparer;
    notifyListeners();
  }

  void openPointer(String id) {
    if (screen != AppScreen.pointer) back = screen;
    sessionId = id;
    screen = AppScreen.pointer;
    notifyListeners();
  }

  void closePointer() {
    screen = back;
    notifyListeners();
  }

  /// Ouvre « Ma semaine » sur le jour donné.
  void goDay(int w, int d) {
    week = w;
    screen = AppScreen.semaine;
    scrollTarget = (week: w, day: d);
    notifyListeners();
  }

  void goToday() => goDay(0, demoToday);

  void selectStudent(String id) {
    studentId = id;
    addingStudent = false;
    notifyListeners();
  }

  void setAdding(bool v) {
    addingStudent = v;
    notifyListeners();
  }

  void showToast(String msg) {
    toast = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
