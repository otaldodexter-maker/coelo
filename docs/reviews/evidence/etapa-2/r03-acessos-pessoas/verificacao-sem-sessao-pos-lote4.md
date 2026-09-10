---
title: "Verificacao sem sessao, depois do lote 4"
source: "Producao (evvbomzejfijozbtgvpt) apos o lote 4; dump schema-only e chamadas HTTP com a chave publicavel, em 2026-09-10"
status: "verificado-sem-sessao; NAO promovido a verified"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
author: "Rodada 3, grupo acessos-pessoas"
---

# Verificacao sem sessao das 18 RPCs do lote 4

## O que esta verificado, e o que NAO esta

A regua do MVP tem quatro partes: a rota normal abre, o CRUD persiste, o RLS
nega outro tenant e o reload mantem o estado. Sem sessao autenticada em producao
so as duas primeiras metades da primeira parte sao alcancaveis.

**Verificado:**

| | resultado |
| --- | --- |
| As 18 funcoes existem em producao | 18/18 |
| Resolvem pela assinatura publicada | 18/18 |
| Negam anonimo | 18/18, todas com `42501 permission denied for function` |
| `REVOKE ALL ... FROM PUBLIC` | 18/18 |
| `EXECUTE` para `authenticated` | 18/18 |
| Concedem a `anon` | 0/18 |
| Contrato de argumentos bate com o cliente | 18/18, zero divergencia |

**NAO verificado, e por isso nada aqui vira `verified`:** CRUD persistindo,
reload mantendo estado e negativa cross-tenant em producao. A negativa
cross-tenant esta provada em pgTAP sobre a baseline, o que nao e a mesma coisa
que prova-la no banco de producao.

## Por action_id

| action_id | RPC | existe | resolve | nega anonimo |
| --- | --- | --- | --- | --- |
| `people.links`, `people.reload` | `superadmin_person_detail_v2` | sim | sim | sim |
| `invites.list` | `superadmin_invite_directory_v2` | sim | sim | sim |
| `invites.create` (opcoes) | `superadmin_invite_options_v2` | sim | sim | sim |
| `invites.detail` | `superadmin_invite_detail_v2` | sim | sim | sim |
| `invites.create` | `superadmin_invite_issue_v2` | sim | sim | sim |
| `invites.resend` | `superadmin_invite_resend_v2` | sim | sim | sim |
| `invites.revoke` | `superadmin_invite_revoke_v2` | sim | sim | sim |
| `internal-users.list` | `superadmin_internal_users_list`, `superadmin_internal_user_profiles` | sim | sim | sim |
| `internal-users.edit` | `superadmin_internal_user_detail` | sim | sim | sim |
| `child-safety.list` | `superadmin_child_safety_directory` | sim | sim | sim |
| `child-safety.child` | `superadmin_child_safety_get` | sim | sim | sim |
| `child-safety.create` | `child_safety_request_authorization`, `superadmin_child_safety_search_children` | sim | sim | sim |
| `child-safety.edit` | `child_safety_edit_pending_authorization`, `child_safety_decide_authorization` | sim | sim | sim |
| `child-safety.suspend` | `child_safety_change_lifecycle` | sim | sim | sim |
| `child-safety.list` (export) | `superadmin_request_child_safety_export` | sim | sim | sim |

## Nota de metodo, porque a primeira tentativa errou

A primeira versao do sondador **chutava** os nomes de parametro e colhia
`PGRST202` em 8 das 14 chamadas. `PGRST202` significa "nao achei funcao com
esses parametros", que e indistinguivel de funcao ausente — eu quase reportei
oito ausencias que nao existiam.

A versao correta le a assinatura real do dump de producao e monta o corpo a
partir dela. Com isso o PostgREST resolve a funcao e o que sobra e a
autorizacao. Nesta versao, um `PGRST202` passaria a significar de verdade "o
contrato que o cliente usa nao existe em producao".

Fica a licao para as outras frentes: sonda por HTTP com parametro chutado nao
prova ausencia; prova que voce chutou errado.

## Uma quebra encontrada, que nao e minha

Na conferencia de assinatura contra o dump pos-lote 4, uma unica quebra apareceu
em todo o cliente, e e do grupo `principal-chat-sistema`:

`list_visible_happens_posts`, chamada em
`features/principal_happens/data/supabase_principal_happens_feed_repository.dart`,
envia `p_cursor_post_id` e `p_cursor_published_at`, que **producao nao conhece**.
A chamada e recusada com `PGRST202`. A migration que acrescenta a paginacao,
`20260910150000_happens_feed_pagination_v1`, ainda nao foi aplicada.
