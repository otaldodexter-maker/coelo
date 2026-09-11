---
title: "Prova em produção do chat interno v2 com a sessão qa-r03 (Rodada 4)"
grupo: "realm-interno"
source: "packages/coelo_database/scripts/chat-internal-production-proof.ts; supabase db query --linked (somente leitura)"
environment: "Supabase coelo / evvbomzejfijozbtgvpt (produção, sem clientes reais)"
generated_at: "2026-09-10"
---

# Prova em produção — chat interno v2 (lote 9, aplicado pelo coordenador às 22:25)

Sessão: `qa-r03@coelo.me`, Owner de plataforma no realm interno, AAL1, entrada
por senha via GoTrue; RPCs chamadas por PostgREST com o token da sessão. A
credencial veio de `Coelo-backups/qa-r03.env` e a chave anon do CLI, ambas só
no ambiente do processo. Fixture sintética
`chat-internal-production-fixture.sql` aplicada antes (1 instituição, 2
adultos com vínculo, 1 criança).

## Resultado do script (22:32, relógio da máquina)

```text
PASS auth.sign_in
PASS chat.list.unread_total total_unread=0
PASS chat.list.inbox total=0 items=0
PASS chat.create-group conversation_id=3134931a-... member_count=2
PASS chat.create-group.replay
PASS chat.send message_id=8d4231b1-...
PASS chat.send.replay
PASS chat.open+chat.receipts total=1 can_manage=true
PASS chat.edit
PASS chat.list.pin
PASS chat.list.flag
PASS chat.list.reload fixada primeiro com bandeira azul
PASS chat.list.cleanup-preference
PASS chat.receipts.mark_read updated_count=0 (a única mensagem é do próprio ator interno)
PASS chat.revoke mensagem sintética revogada
PASS chat.create-group.members total=2
PASS chat.open.not_found (id inexistente responde CHAT_NOT_FOUND)
PASS rls.anon_denied http 401
resumo: 18 PASS, 0 FAIL, 0 SKIP
```

## Persistência conferida no banco (leitura como postgres, depois do script)

| Objeto | Estado |
| --- | --- |
| conversa | `group/institution/active`, título "QA R04 …" |
| participantes ativos | 2 |
| mensagem | `archived`, `deleted_at` preenchido, `author_kind=superadmin_internal`, corpo editado |
| trilha de edição interna | 1 linha |
| recibo de idempotência do grupo | 1 linha |
| preferência | `pinned_at=null`, `flag=none` (desfeita pelo próprio script) |
| auditoria (`actor_kind=superadmin_internal`) | group.create 1, message.send 1, message.edit 1, message.revoke 1, conversation.read 1, conversation.preference 4, todos `success` |

## Régua do MVP por action_id (ADR 0034)

Rota normal com sessão: pelo script (RPC direta com a sessão real); a UI é do
grupo principal-chat-sistema. CRUD persistiu em produção (tabela acima).
RLS/escopo nega outro tenant: pgTAP das cinco suítes (cross-tenant
`CHAT_NOT_FOUND` em thread, edit, revoke, pin, create-group e members) e, em
produção, `anon` negado e id inexistente não enumerável. Reload: inbox relida
após fixar/bandeira devolveu a conversa fixada com a bandeira.

| action_id | Backend | Observação |
| --- | --- | --- |
| chat.list | done | inbox, unread, fixar, bandeira, reload |
| chat.open | done | thread com receipt e can_manage; not_found |
| chat.send | done | envio + replay idempotente |
| chat.edit | done | edição na janela, trilha persistida |
| chat.receipts | done | receipt projetado; mark_read persistiu (0 linhas porque só há mensagem própria) |
| chat.revoke | done | soft delete auditado |
| chat.create-group (P8) | done no backend | ID a registrar no inventário; UI pendente |
| chat.attach | blocked-environment | gateway de mídia comum ausente |

## Limpeza

`chat-internal-production-cleanup.sql`: grupos, mensagens, recibos,
preferências, trilhas e as pessoas sintéticas removidos. A instituição
sintética `9f040000-…-0010` não pode ser apagada porque `audit.audit_logs`
(append-only) a referencia por FK; fica com `deleted_at` preenchido e nome
"QA R04 …". Ver o JSON do grupo para o estado final.
