---
title: "Deltas propostos às skills — realm-interno, Rodada 6"
grupo: "realm-interno"
source: "candidatos/realm-interno/20260912210000; handoff.md"
generated_at: "2026-09-11"
status: "proposta ao coordenador (escritor central das skills)"
---

# Deltas propostos às skills (R06, realm-interno)

## `coelo-backend` (`.agents/skills/coelo-supabase/SKILL.md`), seção "Execução e evidência" — regras da Rodada 6

- **Identidade interna escopada nunca herda capacidade de plataforma.** Desde
  `20260912210000`, `app_private.has_platform_permission(text)` (um argumento)
  devolve `false` para a membership espelhada de uma identidade interna com
  escopo de instituição; só a forma `has_platform_permission(text, uuid)` com a
  instituição certa concede. Helper people-based novo que precise servir
  identidade escopada passa `institution_id` (ou decide por
  `has_context_permission` na membership da própria instituição, como Rotina e
  Cuidado). P7 continua valendo para pessoas do realm people-based.
- **O sincronizador "Superadmin vê tudo" (130000) é escopado:** a fonte do
  escopo é `app_private.superadmin_internal_actor_scope_targets()` (plataforma
  → todas as instituições ativas; instituição → só a própria). Pacote que mude
  o papel concedido pelo sync (P48) altera só o `role_code`/papel, nunca a
  fonte do escopo, e desativa memberships fora do escopo com
  `status='inactive', revoked_at=now()`.
- **Regressão comparada, não absoluta:** com 201 suítes e dezenas de falhas
  históricas, a prova de um pacote transversal é rodar tudo, reverter as
  funções tocadas no mesmo descartável, reexecutar só as suítes vermelhas e
  exigir resultado idêntico linha a linha (padrão de
  `r06-realm-interno/regressao-pgtap-2026-09-11.md`).
- **180060 fechado:** `has_activity_capability` exigir `instructor` não muda
  comportamento (a tabela de turma só recebe `instructor`; admins vivem em
  `activity_admin_assignments`); nenhuma decisão de produto pendente.

## `coelo-frontend-backend` (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- Tela que servir usuário interno com escopo de instituição nas famílias
  people-based (Pessoas, Segurança infantil, Formulários, Suporte, Conta,
  Perfis, Arquivos, Identidade da instituição) recebe `SAI_PERMISSION_DENIED`/
  42501 até o backend passar a decidir por contexto; hoje não existe usuário
  assim em produção. Registrar como `fail-closed`, não como defeito da tela.
