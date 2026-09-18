import 'package:coelo_superadmin/app/navigation/superadmin_navigation.dart';
import 'package:coelo_superadmin/app/tour/superadmin_menu_tour_steps.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nós de primeiro e segundo nível que o rascunho do Owner deixa sem passo:
/// "Itens que não existem no ambiente do usuário (Planos, Catálogo,
/// Importações) não recebem passo." Qualquer outro nó novo precisa de passo.
const _withoutStep = <String>{'plans', 'catalog', 'import'};

void main() {
  test('cobre todo nó de primeiro e segundo nível do menu', () {
    final anchors = superadminMenuTourSteps.map((step) => step.anchorId).toSet();
    final missing = <String>[];
    for (final section in coeloSuperadminNavigation) {
      if (!anchors.contains(section.id) && !_withoutStep.contains(section.id)) {
        missing.add(section.id);
      }
      for (final child in section.children) {
        if (!anchors.contains(child.id) && !_withoutStep.contains(child.id)) {
          missing.add(child.id);
        }
      }
    }
    expect(missing, isEmpty, reason: 'nós do menu sem passo no tour');
  });

  test('toda âncora é um nó do menu ou uma âncora do shell', () {
    for (final step in superadminMenuTourSteps) {
      final known =
          superadminTourShellAnchors.contains(step.anchorId) ||
          coeloNavigationNodeById(step.anchorId) != null;
      expect(known, isTrue, reason: 'âncora desconhecida: ${step.anchorId}');
    }
  });

  test('começa e termina no botão "Fazer tour", com busca, sino e conta antes do fim', () {
    expect(superadminMenuTourSteps.first.anchorId, 'tour-button');
    expect(superadminMenuTourSteps.last.anchorId, 'tour-button');
    final tail = superadminMenuTourSteps
        .skip(superadminMenuTourSteps.length - 4)
        .map((step) => step.anchorId)
        .toList();
    expect(tail, ['navigation-search', 'notifications', 'account', 'tour-button']);
  });

  test('segue a ordem do menu e respeita o limite de 220 caracteres', () {
    final menuOrder = <String>[
      for (final section in coeloSuperadminNavigation) ...[
        section.id,
        for (final child in section.children) child.id,
      ],
    ];
    final tourOrder = superadminMenuTourSteps
        .map((step) => step.anchorId)
        .where(menuOrder.contains)
        .toList();
    final expected = menuOrder.where(tourOrder.contains).toList();
    expect(tourOrder, expected);
    for (final step in superadminMenuTourSteps) {
      expect(step.title, isNotEmpty);
      expect(
        step.text.length,
        lessThanOrEqualTo(superadminTourStepMaxLength),
        reason: 'passo ${step.anchorId} passa de 220 caracteres',
      );
    }
  });
}
