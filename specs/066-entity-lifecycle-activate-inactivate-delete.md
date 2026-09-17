---
title: "Ciclo de vida ativar / inativar / excluir (OQ-033 opção B) e institutions.status"
source: "docs/open-questions.md (OQ-033, decidido em 15/09/2026, opção B); decisions/0041-owner-decisions-r14-mesa-20260916.md (B1, B7); specs/054-archive-activity-routine-models.md; docs/reviews/inventario-etapa-2.json (institutions.status deferred-post-mvp); AGENTS.md; ADR 0032; docs/security/lgpd-security-media.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.record_status (draft/active/inactive/suspended/archived), institutions/units/groups/activity_definitions/people/forms/memberships"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Ciclo de vida: ativar, inativar e excluir

Spec **sem prova**; consolida a decisão do Owner de 15/09 (OQ-033, opção B)
como regra única para todas as entidades e traz `institutions.status` de
volta ao escopo dentro dela. Arquivar/restaurar de modelos (spec 054) é o
primeiro caso concreto e permanece válido.

## Regras (decisão do Owner)

1. **Ativar/inativar** vale para todas as entidades operacionais:
   instituições, unidades, turmas, atividades, pessoas (vínculos), formulários,
   modelos, cardápios, avisos. Inativo some das listas padrão e das opções de
   seleção; permanece em histórico, auditoria e detalhes já vinculados.
2. **Excluir** é **real** só para registro **sem vínculo nem trilha de
   auditoria** (ex.: turma vazia criada por engano). Nos demais casos é
   **exclusão lógica**: some das telas, fica no histórico (`deleted_at` +
   `status='archived'`), sem apagar filhos nem mídia (retenção da ADR 0032).
3. **Instituição e unidade não excluem pessoas, só desvinculam.** A pessoa
   pertence ao app; apenas o Superadmin pode excluir (regra 2) ou **suspender
   por período** (`suspended_from`/`suspended_until`), com motivo e auditoria.
4. Toda transição exige `expected_version` (PT409 em conflito), `request_id`
   idempotente, motivo quando restritiva (inativar/suspender/excluir), auditoria
   before/after minimizada e notificação apenas por evento server-side.
5. Reativar restaura o estado anterior sem recriar vínculos removidos.

## Vocabulário canônico

`public.record_status`: `draft` → `active` ⇄ `inactive`; `suspended` (só
pessoas/memberships, por período); `archived` = excluído logicamente
(terminal, com `deleted_at`/`archived_at`). Entidades que hoje usam `text`
(ex.: `routine_models`) mantêm o texto, mas com os mesmos códigos.

## Predicado "pode excluir de verdade"

`app_private.lifecycle_can_hard_delete_v1(p_entity, p_id)`: verdadeiro só se
não existe linha dependente (FKs de negócio), nenhuma mídia/asset, nenhum
recibo e nenhuma entrada em `audit.audit_logs` além do próprio `create`.
Caso contrário a exclusão é lógica. O predicado é único e testado por
entidade.

## `institutions.status` (volta ao MVP dentro desta spec)

- `superadmin_institution_change_status_v1(p_request_id, p_institution_id,
  p_expected_version, p_status in ('active','inactive'), p_reason)` no
  contexto interno (`institution.status.change`, AAL2 já exigido pelo
  catálogo). Inativar uma instituição inativa em cascata **a visibilidade**
  (unidades/turmas/atividades somem das listas) sem alterar o status físico
  dos filhos; reativar devolve tudo.
- Exclusão de instituição: só lógica (sempre há trilha); exige confirmação
  dupla e motivo.
- FE: ação no detalhe/⋯ do card, diálogo com motivo, estado "Inativa" na lista
  com filtro "Inativas".

## Pessoas

- `superadmin_person_suspend_v1(p_request_id, p_person_id, p_expected_version,
  p_from, p_until, p_reason)` e `..._reactivate_v1`; suspensão bloqueia login
  do Principal/Admin no período (`person_auth_links` continua, a sessão é
  negada por `require_*_context`), e é visível no detalhe da pessoa.
- Desvincular (instituição/unidade) = inativar a membership/contexto, nunca
  a pessoa.

## Aceite (futuro recorte, por família)

pgTAP por entidade: transições válidas, PT409 em versão defasada, exclusão
real só quando `lifecycle_can_hard_delete_v1`, exclusão lógica mantém filhos
e mídia, cross-tenant negado, auditoria uma vez; FE: ações e filtros
"Inativos"/"Arquivados"; rota real por família (ordem sugerida: instituições
(`institutions.status`), unidades, turmas, atividades, pessoas/suspensão).
