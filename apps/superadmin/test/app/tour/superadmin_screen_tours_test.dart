import 'package:coelo_superadmin/app/navigation/superadmin_navigation.dart';
import 'package:coelo_superadmin/app/tour/superadmin_screen_tours.dart';
import 'package:flutter_test/flutter_test.dart';

/// Destinos roteados do menu (nós com `routeName`), na ordem do menu.
List<String> _routedDestinations() {
  final ids = <String>[];
  void visit(CoeloNavigationNode node) {
    if (node.routeName != null) ids.add(node.id);
    node.children.forEach(visit);
  }

  coeloSuperadminNavigation.forEach(visit);
  return ids;
}

void main() {
  test('todo destino roteado tem tour ou está na lista de exclusão com motivo', () {
    final routed = _routedDestinations();
    expect(routed, isNotEmpty);
    for (final id in routed) {
      final hasTour = superadminScreenTours.containsKey(id);
      final excluded = superadminScreenTourExclusions[id];
      expect(
        hasTour || (excluded != null && excluded.isNotEmpty),
        isTrue,
        reason: 'destino "$id" sem tour e sem exclusão justificada',
      );
      expect(hasTour && excluded != null, isFalse, reason: 'destino "$id" com tour e excluído');
    }
  });

  test('todo tour aponta um destino roteado, sem repetição, na ordem do menu', () {
    final routed = _routedDestinations();
    final ids = superadminScreenTourList.map((tour) => tour.destinationId).toList();
    expect(ids.toSet().length, ids.length, reason: 'destino repetido no registro');
    for (final id in ids) {
      expect(routed, contains(id), reason: 'tour de "$id" sem destino roteado');
    }
    final expectedOrder = routed.where(ids.contains).toList();
    expect(ids, expectedOrder, reason: 'registro fora da ordem do menu');
  });

  test('cada tela tem passos, com âncora, título e texto de até 220 caracteres', () {
    for (final tour in superadminScreenTourList) {
      expect(tour.steps, isNotEmpty, reason: 'tela "${tour.destinationId}" sem passos');
      for (final step in tour.steps) {
        expect(step.anchorId, isNotEmpty);
        expect(step.title.trim(), isNotEmpty);
        expect(step.text.trim(), isNotEmpty);
        expect(
          step.text.length,
          lessThanOrEqualTo(superadminScreenTourStepMaxLength),
          reason: '"${tour.destinationId}" › "${step.title}" tem ${step.text.length} caracteres',
        );
      }
    }
  });

  test('o primeiro passo de cada tela é a página (cabeçalho ou navegação do Principal)', () {
    for (final tour in superadminScreenTourList) {
      final first = tour.steps.first.anchorId;
      expect(
        first.startsWith('page.') ||
            first.startsWith('principal.') ||
            first.startsWith('publish.') ||
            first.startsWith('now.') ||
            first.startsWith('chat.') ||
            first.startsWith('profile.'),
        isTrue,
        reason: '"${tour.destinationId}" começa por "$first"',
      );
    }
  });
}
