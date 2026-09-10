import 'dart:io';

import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'database_check_constraints.dart';

/// Contrato de dominio entre os valores que `public.meal_plans` aceita e os enums
/// de Cardapios.
///
/// Existe porque a divergencia aqui JA aconteceu e passou despercebida: a coluna
/// `status` grava `closed` e o enum do cliente chama o mesmo estado de `ended`.
/// Sem conversao, a leitura caia no ramo de rascunho por omissao e um cardapio
/// encerrado aparecia como rascunho, enquanto o filtro perguntava por um valor que
/// a coluna nao tem. Nada falhava, porque todo payload de teste usava o nome do
/// enum — que e exatamente o valor que o banco nao grava.
///
/// A conversao vive em `MealPlanStatusDatabaseValue`, e e ela que este teste
/// confere. Comparar `name` aqui seria reproduzir o defeito dentro da verificacao.
void main() {
  final constraints = databaseCheckConstraints(
    Directory('${repositoryRootForContracts().path}/packages/coelo_database'),
    'meal_plans',
  );

  test('todo status aceito pelo banco tem enum correspondente no cliente', () {
    final accepted = constraints['status'];
    expect(accepted, isNotNull, reason: 'nenhuma restricao check encontrada para status');
    expect(accepted, contains('closed'));

    final mapped = MealPlanStatus.values.map((value) => value.databaseValue).toSet();

    expect(accepted!.difference(mapped), isEmpty);
  });

  test('todo tipo de origem e nivel de escopo aceito pelo banco e mapeavel', () {
    expect(
      constraints['source_type']?.difference(
        MealPlanSourceType.values.map((value) => value.name).toSet(),
      ),
      isEmpty,
    );
    expect(
      constraints['scope_level']?.difference(
        MealPlanScopeLevel.values.map((value) => value.name).toSet(),
      ),
      isEmpty,
    );
  });

  test('o varredor achou as tres listas, senao a comparacao passaria vazia', () {
    for (final column in const ['status', 'source_type', 'scope_level']) {
      expect(constraints[column], isNotEmpty, reason: column);
    }
  });

  test('hoje nao existe valor conhecido so pelo cliente em scope_level', () {
    // Eu escrevi este caso esperando que `activity` existisse apenas no enum, e
    // a medicao derrubou: um `alter table` posterior acrescentou `activity` a
    // coluna, e a varredura que le somente o corpo do `create table` nao o
    // enxergava. O caso fica, invertido, com o numero medido — e como lembrete de
    // que restricao de coluna tambem muda por alter, nao so por criacao.
    expect(
      MealPlanScopeLevel.values.map((value) => value.name).toSet().difference(
        constraints['scope_level'] ?? const <String>{},
      ),
      isEmpty,
    );
  });
}
