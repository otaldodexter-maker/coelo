---
source: R12-35 / R12-cardapios-owner.md
status: local-green-fe
generated: 2026-09-13
---

# R12-34–36 — Datas do modelo e publicação programada

## Aceite executado

Correção da evidência anterior: o commit inicial alterou somente a recorrência
do cardápio; o campo do modelo ainda estava livre. Nesta retomada,
`meal-plans.model-create` e `meal-plans.model-edit`, em Modelo > Aplicar por,
também usam `showCoeloDateRangePicker` em modo single, compondo um conjunto.
O mesmo seletor atende a recorrência do cardápio. As datas aparecem como `InputChip`, podem ser
removidas individualmente, são ordenadas e não aceitam duplicação. O conjunto
continua sendo serializado no mesmo `specificDates` do contrato existente;
valores legados continuam sendo lidos como fallback para não quebrar drafts
anteriores.

## Evidência

- GREEN atual: wizard + serialização — 58 testes passaram (45 + 13).
- O teste do modelo exercita cancelar sem adicionar, duas datas, duplicação,
  remoção individual e payload salvo. Calendário em português do componente Coelo.
- R12-36: `CoeloDateTimeField` substitui intervalo na publicação; o draft envia
  UTC e a edição hidrata em hora local. Teste confere o mesmo instante após
  navegação e publicação no repositório de desenvolvimento.
- R12-34: nome da refeição agora atualiza o título enquanto digita; o prato
  tem rótulo separado, `Nome do prato`.
- GREEN: `flutter analyze lib/features/meal_plans/presentation/meal_plan_wizard_page.dart`
  e teste alterado — sem issues.
- Teste focal: `specific recurrence uses a canonical date selector instead of free text`.

## Limite do aceite

O frontend está local-green e o contrato backend permanece compatível, sem
alteração SQL. Persistência/reload pela rota real, RLS cross-tenant e aprovação
visual do Owner seguem `pending-verification`; não são inferidos pelos testes
locais.

O validador visual global continua FAIL: 21 ocorrências fora dos arquivos
alterados, incluindo controles legados de chat/agenda/instituições/Principal
e entradas antigas da allowlist. Não foi ampliada a allowlist. Esse resultado
é pendência global e não certifica a apresentação em runtime desta fatia.
