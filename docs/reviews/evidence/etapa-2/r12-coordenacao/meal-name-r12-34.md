---
source: R12-34; R12-cardapios-owner.md
status: local-green
generated_at: 2026-09-13
---

# R12-34 — nome da refeição

Cada item do cardápio agora possui `mealName` separado de `dishName`. O título
do bloco usa o nome definido, com fallback temporário `Refeição N`; o prato
continua sendo campo próprio. O valor é hidratado, serializado, duplicado,
reordenado e enviado no payload sem alterar campos existentes.

Provas: teste de round-trip do domínio e `development_meal_plan_wizard_test.dart`:
56 testes PASS. Persistência/reload e cross-tenant pela rota real permanecem
pending-verification.
