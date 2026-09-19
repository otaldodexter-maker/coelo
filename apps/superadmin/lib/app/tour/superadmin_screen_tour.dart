import 'package:coelo_ui_core/coelo_ui_core.dart';

/// Tour de uma tela do Superadmin: o destino do menu ([destinationId], o
/// mesmo `currentDestination` do shell) e os passos, um por elemento.
final class SuperadminScreenTour {
  const SuperadminScreenTour({required this.destinationId, required this.steps});

  final String destinationId;
  final List<CoeloTourStep> steps;
}
