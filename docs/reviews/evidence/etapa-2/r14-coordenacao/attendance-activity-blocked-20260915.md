---
title: "R14 — attendance.create: contexto Atividade bloqueado"
source: "docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md; packages/coelo_database/migrations/20260910220700_attendance_dashboard_access_and_context_options_v1.sql"
status: "blocked"
lifecycle: "current"
generated_at: 2026-09-15
audience: "team"
---

# `attendance.create` — contexto Atividade

## Recorte

`apps/superadmin` → Assiduidade → Nova chamada → `attendance.create`, somente
o contexto Atividade. O fluxo de Turma já está verde e não foi repetido. Não
houve alteração de cliente, RPC, RLS, migration, dados remotos ou contador.

## Verificação do contrato e da rota

- A rota normal `/attendance/new` chama
  `public.superadmin_attendance_context_options(date)` com `p_date`, conforme
  o contrato da migration `20260910220700_attendance_dashboard_access_and_context_options_v1.sql`.
- A RPC devolve `institutions`, `units`, `groups`, `activities` e
  `can_manage`; a opção de atividade é derivada de
  `activity_group_links` + `activity_definitions`, com estado ativo, janela
  de data e escopo do ator.
- A prova produtiva de 15/09 confirmou a rota, criação, persistência/reload e
  negativas do contexto Turma em
  `docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md`.

## Bloqueio reproduzido/documentado

Nas sessões QA `qa-r06-publicacoes` e `qa-r06-estrutura`, para `p_date`
2026-09-15, a RPC devolveu a atividade “Atividade R05 Estrutura (editada)”
(`95b98978`) com:

- institution `190dd028`;
- unit `f5284f2f`;
- group `4214106c`.

A mesma resposta não continha esse institution/unit/group em
`institutions`/`units`/`groups`; a cascata normal do cliente filtra a
atividade pela turma e o contexto “Atividade” não aparece. A evidência atual
classifica corretamente a causa como inconsistência de escopo na RPC ou massa
autorizada insuficiente. Não é seguro escolher uma correção sem decisão.

## Negativas disponíveis

- `superadmin_attendance_create_call` com institution alheia foi recusada com
  `403`/`42501` (`attendance call context outside scope`);
- `superadmin_attendance_call_detail` com ID inexistente retornou `null`, sem
  enumeração.

Não existe ainda negativa específica do fluxo Atividade, porque o caminho
positivo não chega a uma opção elegível pela rota normal.

## Parada e próximo gate

Não implementar por aproximação e não criar massa sintética em produção. Para
continuar, a coordenação/Owner precisa escolher uma destas entradas oficiais:

1. massa QA autorizada que contenha institution, unit, group e
   `activity_group_links` coerentes; ou
2. correção forward-only da RPC, com contrato explícito de escopo e teste
   server-side.

Depois disso, provar pela rota normal a seleção de Atividade, criação,
persistência, reload e negativa cross-tenant específica. Até lá, o item fica
`pending-verification`/bloqueado, sem promoção de estado.
