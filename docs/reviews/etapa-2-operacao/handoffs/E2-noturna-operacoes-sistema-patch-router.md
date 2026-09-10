---
title: "Hunk proposto para o router — guarda de tenant autorizado em Cardápios"
source: "operacoes-sistema; teste vermelho na base app/router/meal_plan_production_routes_test.dart"
status: "proposta; NÃO aplicada, router é reserva do coordenador"
generated_at: "2026-09-09"
group: "operacoes-sistema"
---

# Guarda de tenant autorizado em Cardápios

## O problema

`app/router/meal_plan_production_routes_test.dart` tem um caso vermelho na base:
**"production meal plan mutation fails closed without an authorized tenant"**. Ele
navega para `/meal-plans/models/new` sem tenant autorizado e espera
`SuperadminErrorScreen` com a chave `meal-plan-authorized-tenant-unavailable`, e
que `MealPlanWizardPage` **não** seja montada.

A chave `meal-plan-authorized-tenant-unavailable` **não existe em nenhum lugar de
`apps/superadmin/lib`**. A guarda nunca foi implementada. Hoje a rota monta o
assistente com `tenantId: authorizedMealPlanTenantId?.trim() ?? ''`, ou seja com
string vazia.

Isso se soma ao que já registrei: `authorizedMealPlanTenantId` nunca é atribuído
em produção — é parâmetro opcional de `SuperadminAuthScope` e nenhuma das duas
fábricas o preenche. Então, em produção, o assistente de mutação de Cardápios
abre sem tenant autorizado e nada o barra no cliente.

O escopo real continua sendo imposto no servidor por RLS e RPC, então não estou
afirmando escalonamento de privilégio. Estou afirmando que a guarda de cliente
que o teste especifica não existe, e que o teste está vermelho por isso.

## Hunk proposto

Em `apps/superadmin/lib/app/router/superadmin_router.dart`, dentro de
`productionMealPlanWizardPage`, antes de montar a página:

```dart
  Widget productionMealPlanWizardPage(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? mealPlanId,
    String? templatePlanId,
    String? mealPlanModelId,
    bool isTemplate = false,
  }) {
    final authorizedTenantId = authorizedMealPlanTenantId?.trim() ?? '';
    if (authorizedTenantId.isEmpty) {
      // Fail-closed: sem tenant autorizado o assistente de mutação não abre.
      return SuperadminErrorScreen(
        key: const Key('meal-plan-authorized-tenant-unavailable'),
        kind: SuperadminErrorKind.unavailable,
        actionLabel: 'Voltar ao início',
        onAction: () => context.goNamed(SuperadminRoutes.homeName),
      );
    }
    return productionOperationalPage(
      context,
      title: title,
      subtitle: subtitle,
      destination: 'meal-plans',
      child: MealPlanWizardPage(
        repository: mealPlanRepository,
        imageRepository: mealPlanImageRepository,
        tenantId: authorizedTenantId,
        // ... resto inalterado
```

O padrão copia `blockedProductionMutationPage`, que já existe no mesmo escopo
algumas linhas acima, apenas com a chave específica que o teste exige.

## O que verificar ao aplicar

1. O caso vermelho passa a verde.
2. Os outros dois casos do mesmo arquivo continuam verdes — um deles é
   "production meal plan wizard routes preserve their target identifiers", que
   monta o assistente e **precisa** de tenant autorizado para continuar passando.
3. A suíte de rotas de Cardápios e `test/app/meal_plan_production_composition_test.dart`
   continuam verdes.

## Consequência que fica aberta mesmo com o hunk

Com a guarda aplicada, a rota produtiva de mutação de Cardápios passa a **não
abrir nunca** em produção, porque o tenant autorizado nunca é atribuído na
composição. Isso é coerente com fail-closed, mas significa que fechar a ação
exige também decidir quem preenche `authorizedMealPlanTenantId` — ou remover o
parâmetro e a guarda juntos. Essa segunda parte é decisão de produto, não deste
hunk.
