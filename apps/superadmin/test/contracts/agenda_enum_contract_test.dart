import 'dart:io';

import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'database_check_constraints.dart';

/// Contrato de dominio entre os valores que o banco aceita nas colunas de Agenda
/// e os enums que o cliente sabe mapear.
///
/// O mapeamento no repositorio de Agenda e `values.firstWhere(... orElse: throw
/// FormatException)`. Como a leitura converte a lista inteira de uma vez e o
/// tratamento de erro fecha em indisponibilidade, **um unico valor desconhecido
/// derruba a tela toda, e nao a linha**. Ou seja: se uma migration futura
/// acrescentar um tipo de item, uma prioridade ou um modo de resposta, a Agenda
/// inteira passa a dizer "tente novamente" para todos os usuarios ate o app ser
/// publicado de novo, e nenhum teste de repositorio acusaria, porque todos usam
/// payload escrito a mao com os valores que o cliente ja conhece.
///
/// Este teste le o lado do banco do proprio SQL versionado, entao a divergencia
/// aparece no momento em que a migration entra no repositorio.
void main() {
  final constraints = databaseCheckConstraints(
    Directory('${repositoryRootForContracts().path}/packages/coelo_database'),
    'agenda_events',
  );

  // Cada coluna com o enum do cliente que a representa. Manter esta lista e
  // barato; o que custa caro e descobrir a divergencia em producao.
  final contract = <String, Set<String>>{
    'context_kind': AgendaContextLevel.values.map((value) => value.name).toSet(),
    'item_type': AgendaItemType.values.map((value) => value.name).toSet(),
    'priority': AgendaPriority.values.map((value) => value.name).toSet(),
    'status': AgendaItemStatus.values.map((value) => value.name).toSet(),
    'origin': AgendaItemOrigin.values.map((value) => value.name).toSet(),
    'response_mode': AgendaResponseMode.values.map((value) => value.name).toSet(),
    'guardian_response_policy': GuardianResponsePolicy.values.map((value) => value.name).toSet(),
  };

  test('todo valor aceito pelo banco tem enum correspondente no cliente', () {
    final missing = <String>[];
    for (final entry in contract.entries) {
      final accepted = constraints[entry.key];
      if (accepted == null || accepted.isEmpty) continue;
      final unknown = accepted.difference(entry.value).toList()..sort();
      if (unknown.isNotEmpty) {
        missing.add('${entry.key} aceita $unknown e o cliente nao sabe mapear');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('o varredor encontrou as restricoes, senao o teste passaria vazio', () {
    // Sem isto um `check` reescrito em outra sintaxe faria o teste acima passar
    // por nao ter nada para comparar, que e o modo classico de morte deste tipo
    // de verificacao.
    for (final column in const ['item_type', 'status', 'priority', 'response_mode']) {
      expect(
        constraints[column],
        isNotNull,
        reason: 'nenhuma restricao check encontrada para $column',
      );
      expect(constraints[column], isNotEmpty, reason: column);
    }
    expect(constraints['status'], contains('canceled'));
    expect(constraints['item_type'], contains('resourceReservation'));
  });

  test('o cliente pode conhecer valor que o banco nao aceita, e isso e inofensivo', () {
    // O inverso nao e defeito: `fixture` existe no enum de origem para os dados
    // de prototipo e nunca chega ao banco. O teste registra a assimetria para que
    // ninguem a "corrija" apertando a direcao errada.
    expect(
      AgendaItemOrigin.values.map((value) => value.name).toSet().difference(
        constraints['origin'] ?? const <String>{},
      ),
      contains('fixture'),
    );
  });
}
