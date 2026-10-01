import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/formats.dart';

/// [pointer] et [sites] : écrans sans onglet, avec retour vers [NavState.back].
enum AppScreen { semaine, preparer, pointer, rattrapages, eleve, sites }

class NavState extends ChangeNotifier {
  AppScreen screen = AppScreen.semaine;

  AppScreen back = AppScreen.semaine;

  int week = currentWeek;

  int prepWeek = currentWeek + 1;
  String? sessionId;
  String studentId = 'ange';
  bool addingStudent = false;

  /// Élève en cours de modification (formulaire ouvert), sinon null.
  String? editingStudent;

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
    prepWeek = w < currentWeek ? currentWeek : w;
    notifyListeners();
  }

  void openPreparer(int w) {
    prepWeek = w < currentWeek ? currentWeek : w;
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

  /// Réglages Succès Group (sites et classes), ouverts depuis Préparer.
  void openSites() {
    back = screen;
    screen = AppScreen.sites;
    notifyListeners();
  }

  void goDay(int w, int d) {
    week = w;
    screen = AppScreen.semaine;
    scrollTarget = (week: w, day: d);
    notifyListeners();
  }

  void goToday() {
    final t = today();
    goDay(t.week, t.day);
  }

  void selectStudent(String id) {
    studentId = id;
    addingStudent = false;
    editingStudent = null;
    notifyListeners();
  }

  void setAdding(bool v) {
    addingStudent = v;
    editingStudent = null;
    notifyListeners();
  }

  void editStudent(String? id) {
    if (id != null) studentId = id;
    editingStudent = id;
    addingStudent = false;
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
