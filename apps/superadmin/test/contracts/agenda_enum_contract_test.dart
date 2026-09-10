import 'dart:io';

import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final root = _repositoryRoot();
  final constraints = _checkConstraints(
    Directory('${root.path}/packages/coelo_database'),
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

Directory _repositoryRoot() {
  var directory = Directory.current;
  for (var level = 0; level < 6; level++) {
    if (Directory('${directory.path}/packages/coelo_database').existsSync()) return directory;
    directory = directory.parent;
  }
  throw StateError(
    'packages/coelo_database nao encontrado a partir de ${Directory.current.path}',
  );
}

/// Coleta `check (<coluna> in ('a','b'))` de dentro da definicao de UMA tabela.
///
/// O escopo por tabela e obrigatorio e foi aprendido errando: nomes como
/// `status`, `origin` e `context_kind` se repetem em dezenas de tabelas do
/// pacote, e a uniao indiscriminada acusou a Agenda de nao mapear valores de
/// convites, importacoes e auditoria. Varredura fora de escopo nao mede
/// contrato nenhum.
Map<String, Set<String>> _checkConstraints(Directory package, String table) {
  final constraints = <String, Set<String>>{};
  final pattern = RegExp(
    r"check\s*\(\s*([a-z_]+)\s+in\s*\(([^)]*)\)\s*\)",
    caseSensitive: false,
  );
  final header = RegExp(
    'create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?(?:[a-z_]+\\.)?$table\\s*\\(',
    caseSensitive: false,
  );
  final alter = RegExp(
    'alter\\s+table\\s+(?:[a-z_]+\\.)?$table[^;]*;',
    caseSensitive: false,
  );
  for (final file in package.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    if (file.path.replaceAll(r'\', '/').contains('/tests/')) continue;
    final text = file.readAsStringSync();
    final scoped = StringBuffer();
    for (final start in header.allMatches(text)) {
      var depth = 0;
      for (var index = start.end - 1; index < text.length; index++) {
        if (text[index] == '(') depth++;
        if (text[index] == ')') {
          depth--;
          if (depth == 0) {
            scoped.write(text.substring(start.end, index));
            break;
          }
        }
      }
    }
    for (final constraint in alter.allMatches(text)) {
      scoped.write(constraint.group(0));
    }
    for (final match in pattern.allMatches(scoped.toString())) {
      final values = RegExp("'([^']*)'")
          .allMatches(match.group(2)!)
          .map((entry) => entry.group(1)!)
          .toSet();
      constraints.putIfAbsent(match.group(1)!, () => <String>{}).addAll(values);
    }
  }
  return constraints;
}
