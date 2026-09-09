---
title: "Pacote revisável AUDIT-READ-V2 — cutover dos leitores de Auditoria"
source: "docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md; coordenacao.json rev4; candidatos 8b4dfb6a e 89949f30"
status: "revisável; NÃO aplicado; aguardando autorização nominal do Owner"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# AUDIT-READ-V2 — pacote revisável

Este pacote **não foi aplicado**. A decisão permanente da rodada de 09/09/2026 é
que não há aplicação remota nesta noite, e o Owner não está disponível para dar
autorização nominal. O replay de Auditoria permanece **0/145**. O pacote fica
pronto para que o coordenador o serialize quando houver decisão.

## Ações cobertas

`audit.list`, `audit.filter`, `audit.detail`. Não cobre `audit.export`, que
permanece `deferred-post-mvp`.

## Problema que o pacote fecha

Os leitores `public.audit_list_events_for_superadmin` e
`public.audit_get_event_for_superadmin` resolvem o ator por
`app_private.current_person_id()`, o helper legado baseado em Pessoas
(`20260812000847_audit_production.sql`, linhas 366 e 405). Enquanto isso não
mudar, não é possível afirmar o cutover para a identidade interna do Superadmin
(realm 039), e é isso que mantém as três ações em `pending-verification`.

O pacote também revoga os três entrypoints de exportação que continuavam
acessíveis a `authenticated`:
`audit_start_export_for_superadmin`, `audit_get_export_job_for_superadmin` e
`audit_authorize_export_download_for_superadmin`. Eles são validados
internamente por `audit_assert_permission('audit.export', true)`, então não
constituem escalonamento de privilégio; o problema é de política, não de
autorização: exportação geral está adiada e não deveria ter entrypoint de
cliente alcançável. O cliente Flutter já é `fail-closed`
(`supabase_audit_repository.dart` devolve `AuditUnavailableException` e fixa
`canExport: false`), de modo que a revogação alinha o servidor ao cliente e
nenhuma mudança de Front-end é necessária.

## Conteúdo e ordem de aplicação

Aplicar nesta ordem, como `postgres`, em transação única (a migration já abre e
fecha a sua própria).

| Ordem | Arquivo | SHA256 |
| --- | --- | --- |
| 1 | `packages/coelo_database/migrations/20260908230039_superadmin_internal_audit_read_v2.sql` | `3a14121447bbe21aa20acd8a291bec94ac3bb9bddc5ede8a96da8806ca1729b2` |
| 2 (teste) | `packages/coelo_database/supabase/tests/superadmin_internal_audit_read_v2_test.sql` | `411c4b1a1bb818e256a9e9d3923108defae791438bca9709f7829defabb3518b` |
| 3 (teste) | `packages/coelo_database/supabase/tests/audit_production_test.sql` | `b041efaa3a6bc9662e1d97639080190ad1fcbbb51a99b03b2664d978e6ab6e97` |
| 4 (teste) | `packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql` | `e4b405fe6d13459fc571654e22fcd52214bd160c5626e2fbfad70ba6d127155f` |

Origem: `8b4dfb6a2` (migration e três suítes) e `89949f301` (separação das
fixtures de leitor interno em `audit_production_test.sql`). Base de composição:
`d784462c168d22fdb7090b7de1ef7db554ad5107`.

## Preflight já embutido na migration

A migration aborta antes de qualquer alteração se algum destes faltar:

- aplicação por `current_user = 'postgres'`;
- `app_private.require_superadmin_internal_context(text)` e o tipo
  `app_private.superadmin_internal_context`;
- `app_private.audit_append_superadmin_internal(...)` e
  `app_private.audit_superadmin_internal_denial_if_identified(...)`;
- os dois leitores públicos atuais e a tabela `audit.audit_logs`;
- a capacidade `audit.read` ativa em `public.platform_permissions`.

É forward-only: cria funções `_v2` novas, substitui os wrappers públicos por
`create or replace` e não altera migrations já aplicadas.

## O que NÃO foi feito e por quê

- **Nenhuma execução remota.** Nada foi aplicado no projeto de produção.
- **Replay 0/145 permanece aberto.** Os 145 casos nominais continuam sem
  runtime; a lease anterior foi devolvida sem consumo.
- **Sem execução local das suítes SQL.** Exigiria subir uma instância local e
  encerrá-la dentro da janela; a revisão aqui é estática e está declarada como
  tal. Nenhum `PASS` é reivindicado.

## Efeito no rastreador

Nenhum. `audit.list`, `audit.filter` e `audit.detail` continuam
`pending-verification` nas três camadas. Um pacote revisável não promove
conclusão.
