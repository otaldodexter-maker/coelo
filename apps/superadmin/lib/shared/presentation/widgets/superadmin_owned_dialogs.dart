import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Rota de diálogo do superadmin: herda os temas do contexto de origem,
/// respeita "reduzir animações", fecha o ciclo de foco e usa o scrim do tema.
DialogRoute<T> superadminDialogRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
  String? barrierLabel,
  RouteSettings? settings,
  bool Function()? isContextCurrent,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return DialogRoute<T>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    animationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    barrierColor: barrierColor ?? DialogTheme.of(context).barrierColor ?? context.coeloScrim,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    settings: settings,
    builder: (context) =>
        isContextCurrent?.call() == false ? const SizedBox.shrink() : builder(context),
  );
}

/// Diálogos e sheets "de posse" da tela: a tela os abre, guarda a rota e os
/// derruba em `dispose`/troca de contexto com [dismissOwnedRoutes].
mixin SuperadminOwnedDialogs<T extends StatefulWidget> on State<T> {
  final Set<Route<dynamic>> _ownedRoutes = {};
  var _ownedRoutesGeneration = 0;

  /// Verdadeiro enquanto a tela está montada e nenhum [dismissOwnedRoutes]
  /// aconteceu desde [generation].
  bool isOwnedRouteCurrent(int generation) => mounted && generation == _ownedRoutesGeneration;

  int get ownedRoutesGeneration => _ownedRoutesGeneration;

  Future<R?> showOwnedDialog<R>({
    required WidgetBuilder builder,
    Color? barrierColor,
    bool barrierDismissible = true,
    bool Function()? isContextCurrent,
  }) {
    final generation = _ownedRoutesGeneration;
    final route = superadminDialogRoute<R>(
      context,
      builder: builder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      isContextCurrent: () => isOwnedRouteCurrent(generation) && isContextCurrent?.call() != false,
    );
    return pushOwnedRoute(Navigator.of(context, rootNavigator: true), route);
  }

  /// Empurra [route] em [navigator] e a mantém sob posse até fechar.
  Future<R?> pushOwnedRoute<R>(NavigatorState navigator, TransitionRoute<R> route) async {
    _ownedRoutes.add(route);
    try {
      unawaited(navigator.push<R>(route));
      return await route.completed;
    } finally {
      _ownedRoutes.remove(route);
    }
  }

  /// Registra uma rota criada por terceiros (ex.: `onRouteCreated`).
  void ownRoute(Route<dynamic> route) => _ownedRoutes.add(route);

  void disownRoute(Route<dynamic> route) => _ownedRoutes.remove(route);

  void dismissOwnedRoutes() {
    _ownedRoutesGeneration += 1;
    final routes = _ownedRoutes.toList(growable: false);
    _ownedRoutes.clear();
    if (routes.isEmpty) return;
    // Pós-frame: `dispose` corre com o Navigator travado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
  }
}
