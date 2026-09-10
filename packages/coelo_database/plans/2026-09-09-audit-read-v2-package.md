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
| 1 | `packages/coelo_database/migrations/20260909190000_superadmin_internal_audit_read_v2.sql` | `3a14121447bbe21aa20acd8a291bec94ac3bb9bddc5ede8a96da8806ca1729b2` |
| 2 (teste) | `packages/coelo_database/supabase/tests/superadmin_internal_audit_read_v2_test.sql` | `411c4b1a1bb818e256a9e9d3923108defae791438bca9709f7829defabb3518b` |
| 3 (teste) | `packages/coelo_database/supabase/tests/audit_production_test.sql` | `b041efaa3a6bc9662e1d97639080190ad1fcbbb51a99b03b2664d978e6ab6e97` |
| 4 (teste) | `packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql` | `e4b405fe6d13459fc571654e22fcd52214bd160c5626e2fbfad70ba6d127155f` |

### Carimbo renomeado

O candidato nasceu como `20260908230039_superadmin_internal_audit_read_v2.sql`.
Esse carimbo cai **antes** de cinco migrations que já existem na fila
(`20260908235110`, `20260909165000`, `20260909173000`, `20260909173100`,
`20260909174500`), e forward-only exige que um pacote novo entre no fim da fila,
não no meio dela. O arquivo foi renomeado para `20260909190000`, posterior à
cauda real. O conteúdo não mudou: SHA256 idêntico ao do candidato. Os
rastreadores que citam o candidato pelo carimbo antigo referem-se a este mesmo
arquivo.

### Preflight conferido contra a cauda real

Nenhuma das cinco migrations posteriores toca
`audit_list_events_for_superadmin`, `audit_get_event_for_superadmin`,
`audit_assert_permission` ou `audit_start_export_for_superadmin`, e nenhuma
delas contém `drop function` ou `drop type`. Quatro delas são **consumidoras**
do contexto interno (`require_superadmin_internal_context`,
`audit_append_superadmin_internal`), o que confirma que os pré-requisitos do
preflight continuam presentes na cauda. Verificação estática, sobre os arquivos
da fila; não substitui a execução do preflight no alvo.

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

## Alterações nas suítes de teste

`superadmin_internal_auth_context_test.sql` muda **32 linhas inseridas contra 33
removidas**, não cerca de 200: o número 65 do `--stat` é a soma das duas. Não é
redução de cobertura por descuido, e sim adaptação obrigatória:

- as fixtures deixam de criar a identidade por `public.people` +
  `person_auth_links` + `platform_memberships` e passam a criar
  `superadmin_internal_identities` + `superadmin_internal_auth_links` +
  `superadmin_internal_memberships`, porque é exatamente esse o cutover;
- as claims passam a incluir `session_id`, exigido pelo contexto interno;
- a asserção de exportação deixa de verificar como o snapshot renderiza
  `auth_session` e passa a verificar que `authenticated` **não** tem mais
  `execute` nos três entrypoints de exportação. A asserção antiga não teria como
  passar depois do pacote, já que o caminho que ela exercitava deixa de ser
  alcançável pelo cliente.

**Perda real a registrar:** a asserção removida também cobria a minimização do
snapshot produzido por `audit_materialize_export_for_worker`, que continua
existindo para o worker `service_role`. Essa cobertura não foi recriada em outro
lugar. Não é bloqueante para o pacote, porque o worker não é superfície de
cliente, mas fica anotada como pendência de teste a recriar quando a exportação
geral sair do adiamento.

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
