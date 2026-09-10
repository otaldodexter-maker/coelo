import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'database_check_constraints.dart';

/// Terceira parte do contrato de tamanho de campo: afirmar que os numeros que o
/// cliente usa continuam sendo os numeros da coluna.
///
/// As duas primeiras partes ja existem — a coluna e a RPC restringem, e os
/// formularios de Agenda e de Planos passaram a limitar a entrada em 5845f01c2 e
/// 646239792. Faltava a afirmacao, e ela e a que costuma faltar: outra frente mediu
/// por mutacao, no mesmo dia, que baixar um limite espelhado de 1000 para 999 nao
/// derrubava NENHUM teste. Numero espelhado sem afirmacao e numero que ninguem ve
/// mudar.
///
/// Este teste le o lado autoritativo, o SQL versionado, e falha se algum desses
/// limites mudar. A falha nao diz que o banco esta errado: diz que os limites do
/// formulario precisam ser revistos junto, e nomeia onde eles estao.
///
/// LIMITE DECLARADO: os numeros do cliente estao hoje embutidos nos
/// `inputFormatters` dos dois formularios, e nao em constantes nomeadas como
/// `CircularLimits`. Este teste, portanto, guarda o lado do banco e **nao** compara
/// automaticamente com o cliente. Extrair `AgendaLimits` e `PlanLimits` e consumi-las
/// nos formularios fecharia a comparacao de verdade, e fica como proposta medida para
/// a proxima rodada — nao foi feito agora porque e mudanca em `lib` durante a medicao
/// de fechamento.
void main() {
  final package = Directory(
    '${repositoryRootForContracts().path}/packages/coelo_database',
  );

  test('os limites de agenda_events continuam os que o formulario aplica', () {
    final agenda = databaseCheckConstraintRanges(package, 'agenda_events');

    expect(agenda['title'], 240, reason: 'agenda_event_form_page limita o titulo a 240');
    expect(agenda['location'], 500, reason: 'agenda_event_form_page limita o local a 500');
    expect(
      agenda['description'],
      10000,
      reason: 'agenda_event_form_page limita a descricao a 10000',
    );
  });

  test('os limites de plans continuam os que o formulario aplica', () {
    final plans = databaseCheckConstraintRanges(package, 'plans');

    expect(plans['name'], 160, reason: 'plan_form_page limita o nome a 160');
    expect(plans['description'], 2000, reason: 'plan_form_page limita a descricao a 2000');
    expect(plans['code'], 80, reason: 'plan_form_page limita o codigo a 80');
  });

  test('o varredor achou os limites, senao a comparacao passaria vazia', () {
    // Sem isto, uma restricao reescrita em outra sintaxe faria os dois casos acima
    // falharem por AUSENCIA e nao por divergencia, o que manda o leitor para o
    // lugar errado. Este caso separa as duas situacoes.
    final agenda = databaseCheckConstraintRanges(package, 'agenda_events');
    final plans = databaseCheckConstraintRanges(package, 'plans');

    expect(agenda.keys, containsAll(const ['title', 'location', 'description']));
    expect(plans.keys, containsAll(const ['name', 'description', 'code']));
  });
}
