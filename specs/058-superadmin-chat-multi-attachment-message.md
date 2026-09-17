---
title: "058 — Chat interno: vários anexos por mensagem (E3)"
source: "ADR 0042 E3 (owner.r12-52 = B); ADR 0038 (até 10 anexos por envio); ADR 0032 (mídia privada R2); spec 028; R14-handoff-sessao-6.md (achado: prepare_v1 cria uma mensagem por anexo); lotes 67 e 72"
status: "approved"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# 058 — Chat interno: vários anexos por mensagem

## Objetivo e escopo

O compositor de Conversas do Superadmin (superfície Coelo/Principal hospedada)
envia **um lote de 1 a 10 arquivos como UMA mensagem**. O mosaico "várias
mídias da mesma mensagem" (owner.r12-52, `chat.attach`) passa a ser alcançável
pela rota normal. Fora de escopo: legenda rica, reordenar após o envio, editar
anexos de mensagem publicada, chat contextual (realm `person`).

## Contrato (migration `20260917120000_chat_attachment_batch_v2.sql`)

| RPC | Papel | Entrada | Saída (`data`) |
|---|---|---|---|
| `superadmin_chat_attachment_prepare_v2(p_request_id, p_conversation_id, p_items jsonb, p_body_text)` | `authenticated`, `chat.internal.send` | `p_items` = array de 1–10 objetos `{file_name, content_type, byte_size, sha256}` (regras da v1: MIME/limite por tipo, nome ≤255 sem `/`, sha hex); `p_body_text` legenda opcional ≤4000 | `message_id`, `message_status` (`draft`), `body_text`, `bucket`, `replayed`, `items[]` (`index`, `attachment_id`, `asset_id`, `object_key`, `file_name`, `content_type`, `byte_size`, `sha256`, `upload_status`, `finalize_ticket`, `expires_at`, `replayed`) |
| `superadmin_chat_attachment_finalize_v2(p_attachment_id, p_finalize_ticket, p_byte_size, p_checksum_sha256)` | `service_role` (só pela Edge) | medidas relidas do R2 | `attachment_id`, `message_id`, `upload_status`, `uploaded_at`, `message_status`, `attachments[]` |
| `superadmin_chat_attachment_discard_v1(p_attachment_id)` | `authenticated`, dono do ticket, mensagem `draft` | — | `attachment_id`, `message_id`, `object_key`, `previous_status`, `upload_status` (`deleted`), `message_status`, `attachments[]` |
| `superadmin_chat_thread_v2` | inalterada na assinatura | — | `attachments[]` por mensagem só com `upload_status='ready'`, na ordem do lote (`position`), `asset_id = id` (lote 72) |

Regras:

- **Uma mensagem por lote**: `prepare_v2` cria a mensagem em `draft`
  (`message_type='attachment'`, corpo = legenda, ou nome do arquivo quando há um
  item, ou `"N anexos"`), N linhas em `chat_attachment_metadata` (coluna nova
  `position` 0–9) e N tickets. O `request_id` de cada item é derivado
  (`uuid_generate_v5(request_id_do_lote, 'chat-attachment-item:<i>')`) e todos
  os tickets guardam o hash do lote: replay idêntico devolve a mesma mensagem e
  os mesmos anexos; replay divergente é `CHAT_REPLAY_MISMATCH` (409).
- **Limite**: lote com 11 itens → `CHAT_ATTACHMENT_LIMIT` (422) sem criar nada;
  a contagem do lote 67 (até 10 pendentes por autor na conversa) continua e
  inclui o lote novo. Um item inválido derruba o lote inteiro
  (`CHAT_ATTACHMENT_INVALID`, 422).
- **Publicação**: a mensagem só vira `active` quando nenhum anexo está
  `pending`, nenhum está `failed` e ao menos um está `ready`. Mismatch ou
  expiração deixam o anexo `failed` e a mensagem em `draft` (o autor remove os
  que falharam com `discard_v1`, que consome o ticket e reavalia a mensagem).
  Sem anexo `ready` restante a mensagem é arquivada (`archived`, `deleted_at`).
  Descarte em mensagem já publicada → `CHAT_ATTACHMENT_DISCARD_INVALID` (409).
- **Segurança**: escopo da conversa, RLS, ownership do ticket, auditoria
  (`chat.attachment.prepare` por anexo, `finalize`, `discard`, negativas
  `denied`) e ausência de URL permanente são os mesmos da v1. `finalize_v2`
  só é executável por `service_role`; a Edge relê bytes/MIME/sha no R2 antes.
  Cross-tenant → `CHAT_NOT_FOUND` (404) sem mutação.
- `prepare_v1`/`finalize_v1` continuam válidas para o app hospedado até a
  publicação do FE novo; a Edge mantém a ação `prepare` unitária.

## Edge `chat-media`

- `prepare` com `items[]` (e opcional `body_text`) chama `prepare_v2` e devolve
  `message_id`, `message_status`, `replayed`, `items[]` com `upload_url` +
  `required_headers` assinados por item (PUT de 300 s). Sem `items`, o caminho
  unitário v1 permanece.
- `finalize` passa a chamar `finalize_v2` (mesma validação de bytes) e devolve
  `message_status` + `attachments[]`; em mismatch o objeto é apagado do R2.
- `discard` (novo): chama `discard_v1` com a sessão do usuário e, se o anexo
  já estava `ready`, apaga o objeto no R2. Devolve `message_status` +
  `attachments[]`.

## Front-end (`apps/superadmin/lib/features/chat`)

- Seletor de arquivos com `allowMultiple`; sem teto no cliente (o servidor
  responde 422 no 11.º).
- Diálogo de envio lista os arquivos com estado por item (aguardando,
  enviando, pronto, falhou), progresso "k de N" e envia em lote: um `prepare`
  para o lote, depois PUT + `finalize` por item, sequenciais.
- Falha parcial: o diálogo mostra os que falharam e oferece **Remover os que
  falharam e publicar** (`discard` de cada um; a mensagem publica quando os
  restantes estão prontos) ou **Cancelar envio** (`discard` de todos → mensagem
  arquivada). Sem anexo pronto, só Cancelar.
- Renderização já existente: tile único, mosaico de até 3 + "+N", anexo não
  visual (spec 028, r12-coordenacao/chat-attach-mosaic-r12.md).

## Verificação

- pgTAP `superadmin_internal_chat_attachments_batch_v2_test.sql` (51) no
  espelho; suítes v1 (28) e lote 67 (9) continuam verdes.
- Edge: `deno test` do `chat-media` (fonte/CORS).
- FE: testes de widget do diálogo (lote, progresso, falha parcial, remover e
  publicar, cancelar) e do adaptador (prepare em lote, PUT/finalize por item,
  discard, replay).
- Rota real (`qa-r06-publicacoes`): tile único, mosaico 3–4 imagens + "+N",
  PDF sem PII, reload por `thread_v2`, negativa cross-tenant por PostgREST →
  `chat.attach` verified-e2e, `owner.r12-52` done.
