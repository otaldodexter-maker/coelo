import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O Chat do Principal chegou ao shell persistente com duas lacunas que nenhum
/// teste de composição pegava, porque a tela montava certo: a rota não era
/// reconhecida por `_destinationForLocation`, e a folha `principal-chat` do
/// menu não tinha caso em `_navigateFromPersistentShell` — o item de menu era
/// inerte em produção e nada falhava.
///
/// As duas lacunas são de ida e volta entre três arquivos, então a guarda lê a
/// fonte em vez de montar widget: um teste de rota só pega o caso que alguém
/// lembrou de escrever, e o que falta aqui é exatamente o que ninguém lembrou.
/// A leitura é de nomes literais, não de prosa.
void main() {
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();
  final navigation = File('lib/app/navigation/superadmin_navigation.dart').readAsStringSync();

  test('every navigation leaf reaches a route in the production shell', () {
    final productionCases = _casesOf(router, 'void _navigateFromPersistentShell(');
    final leaves = RegExp(r"_leaf\(\s*'([a-z0-9-]+)'")
        .allMatches(navigation)
        .map((m) => m.group(1)!)
        .toSet();
    expect(leaves, isNotEmpty, reason: 'a varredura precisa encontrar folhas de menu');

    // Uma folha sem caso correspondente é um item de menu que não leva a lugar
    // nenhum: clicar não navega e nenhuma exceção é lançada.
    expect(leaves.difference(productionCases), isEmpty);
  });

  test('every destination the router can derive is navigable in the production shell', () {
    final productionCases = _casesOf(router, 'void _navigateFromPersistentShell(');
    final start = router.indexOf('String _destinationForLocation(');
    final end = router.indexOf('void _navigateFromPersistentShell(');
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    final derived = RegExp(r"return '([a-z0-9-]+)';")
        .allMatches(router.substring(start, end))
        .map((m) => m.group(1)!)
        .toSet();
    expect(derived, isNotEmpty);

    // Um destino derivável mas não navegável significa que o shell reconhece a
    // localização para marcar o menu e suprimir o launcher, mas não sabe voltar
    // para ela — o par precisa existir nos dois sentidos.
    //
    // Assimetria encontrada em 09/09/2026 e ainda NÃO classificada como
    // defeito: estes três só têm caso no shell de desenvolvimento
    // (`_navigateFromDevelopmentShell`), não no de produção. Nenhuma folha de
    // menu os emite, então o impacto depende de haver, em produção, alguma
    // página que peça esses destinos ao shell — coisa que não verifiquei.
    // Pertencem a Planos e Cardápios, fora do recorte de chat e comunicações,
    // e estão roteados ao dono. A lista existe para a guarda valer agora e
    // ficar vermelha se a assimetria CRESCER; ela deve encolher, nunca crescer.
    const knownAsymmetry = {'plan-create', 'meal-plan-create', 'meal-plan-model-create'};
    expect(derived.difference(productionCases).difference(knownAsymmetry), isEmpty);
  });
}

Set<String> _casesOf(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, greaterThan(-1), reason: 'assinatura não encontrada: $signature');
  final body = source.substring(start, _endOfFunction(source, start));
  return RegExp(r"case '([a-z0-9-]+)':").allMatches(body).map((m) => m.group(1)!).toSet();
}

int _endOfFunction(String source, int start) {
  var depth = 0;
  var seenOpen = false;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth++;
      seenOpen = true;
    } else if (char == '}') {
      depth--;
      if (seenOpen && depth == 0) return i;
    }
  }
  return source.length;
}
