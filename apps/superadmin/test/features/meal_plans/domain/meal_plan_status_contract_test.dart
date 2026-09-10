import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A coluna `status` de `public.meal_plans` aceita
/// `draft, inReview, scheduled, published, updated, closed, archived`, conferido
/// na restricao check de 20260813120000_meal_plans_superadmin.sql. O enum do
/// cliente chama o mesmo estado de `ended`, e a conversao faltava nas duas
/// direcoes:
///
/// - na leitura, `closed` nao casava com nenhum ramo e caia no `_ =>
///   MealPlanStatus.draft`, entao um cardapio ENCERRADO aparecia como RASCUNHO,
///   com o rotulo, a cor e o filtro de rascunho. Falha silenciosa: nada estoura,
///   e o operador ve um estado que o plano nao tem;
/// - no filtro, o cliente enviava `ended`, que nao existe na coluna, entao
///   filtrar por Encerrado devolvia lista vazia em vez dos planos encerrados.
///
/// Nenhum teste acusava porque todos os payloads de teste usavam o nome do enum,
/// que e justamente o valor que o banco nao grava.
void main() {
  test('status closed do banco vira Encerrado, e nao Rascunho', () {
    final plan = MealPlan.fromJson(const {'id': 'meal-plan-1', 'status': 'closed'});

    expect(plan.status, MealPlanStatus.ended);
  });

  test('filtro por Encerrado pergunta pelo valor que a coluna realmente tem', () {
    const filter = MealPlanListFilter(statuses: {MealPlanStatus.ended});

    expect(filter.toJson()['statuses'], const ['closed']);
  });

  test('os demais estados continuam usando o nome do enum', () {
    const filter = MealPlanListFilter(
      statuses: {MealPlanStatus.draft, MealPlanStatus.published, MealPlanStatus.archived},
    );

    expect(
      (filter.toJson()['statuses']! as List).toSet(),
      {'draft', 'published', 'archived'},
    );
    for (final entry in const {
      'draft': MealPlanStatus.draft,
      'inReview': MealPlanStatus.inReview,
      'scheduled': MealPlanStatus.scheduled,
      'published': MealPlanStatus.published,
      'updated': MealPlanStatus.updated,
      'archived': MealPlanStatus.archived,
    }.entries) {
      expect(
        MealPlan.fromJson({'id': 'meal-plan-1', 'status': entry.key}).status,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('ended continua aceito na leitura, porque o prototipo usa o nome do enum', () {
    expect(
      MealPlan.fromJson(const {'id': 'meal-plan-1', 'status': 'ended'}).status,
      MealPlanStatus.ended,
    );
  });

  test('valor desconhecido segue caindo em rascunho, e isso e declarado', () {
    // Registrado em vez de corrigido: transformar o desconhecido em excecao
    // derrubaria a listagem inteira por uma linha, que e o modo de falha que a
    // Agenda tem e que eu nao quero trazer para Cardapios sem decisao. O que
    // importa e que `closed` deixou de ser um desconhecido.
    expect(
      MealPlan.fromJson(const {'id': 'meal-plan-1', 'status': 'estadoQueNaoExiste'}).status,
      MealPlanStatus.draft,
    );
  });
}
