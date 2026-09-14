---
source: R12-35 / R12-cardapios-owner.md
status: local-green-fe
generated: 2026-09-13
---

# R12-35 — Datas específicas de cardápio

## Aceite executado

Em `meal-plans.model-create` e `meal-plans.model-edit`, o campo livre com
datas separadas por vírgula foi substituído por um seletor canônico baseado no
`showDatePicker` do Flutter. As datas aparecem como `InputChip`, podem ser
removidas individualmente, são ordenadas e não aceitam duplicação. O conjunto
continua sendo serializado no mesmo `specificDates` do contrato existente;
valores legados continuam sendo lidos como fallback para não quebrar drafts
anteriores.

## Evidência

- RED: o novo teste falhou antes da implementação porque não existia
  `meal-plan-specific-dates-selector`.
- GREEN: `flutter test test/features/meal_plans/presentation/development_meal_plan_wizard_test.dart`
  — 57 testes passaram.
- GREEN: `flutter analyze lib/features/meal_plans/presentation/meal_plan_wizard_page.dart`
  — sem issues.
- Teste focal: `specific recurrence uses a canonical date selector instead of free text`.

## Limite do aceite

O frontend está local-green e o contrato backend permanece compatível, sem
alteração SQL. Persistência/reload pela rota real, RLS cross-tenant e aprovação
visual do Owner seguem `pending-verification`; não são inferidos pelos testes
locais.
