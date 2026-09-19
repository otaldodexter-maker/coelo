import 'package:flutter/material.dart';

/// Dá ao botão "Fazer tour" acesso ao tour do shell que desenha o menu.
class SuperadminTourScope extends InheritedWidget {
  const SuperadminTourScope({
    super.key,
    required this.startMenuTour,
    required this.startScreenTour,
    required this.startCompleteTour,
    required this.menus,
    required super.child,
  });

  final Future<void> Function() startMenuTour;

  /// Devolve false quando a tela atual não tem tour.
  final Future<bool> Function() startScreenTour;
  final Future<void> Function() startCompleteTour;
  final SuperadminTourMenuHandles menus;

  static SuperadminTourScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperadminTourScope>();

  @override
  bool updateShouldNotify(SuperadminTourScope oldWidget) =>
      startMenuTour != oldWidget.startMenuTour ||
      startScreenTour != oldWidget.startScreenTour ||
      startCompleteTour != oldWidget.startCompleteTour ||
      menus != oldWidget.menus;
}

/// Controladores de menus que o tour precisa abrir (menu da conta). Quem
/// desenha o menu registra o controller a cada build; o shell que roda o tour
/// usa o mais recente.
class SuperadminTourMenuHandles {
  MenuController? account;
}
