---
title: "Chat — recusa de envio parcial no adapter textual v2"
source: "superadmin_chat_send_message_v2; ChatSendMessageCommand; teste do adapter Supabase"
status: "local-green; no-remote-or-e2e-promotion"
generated_at: "2026-09-07"
---

# Resultado

O adapter Supabase aceitava `attachmentIds` e `childContextIds` no comando,
mas enviava somente conversa, texto e chave de idempotência à RPC v2. Isso
permitia sucesso aparente de um comando parcialmente descartado.

A RPC interna atual é textual. O adapter agora recusa comandos com anexos ou
contextos antes de emitir a requisição. O envio textual existente permanece
inalterado; esta correção não implementa upload, vínculo ou download de anexos.
O servidor continua sendo a autoridade de autorização de toda operação real.

## Prova

- RED: 9 testes existentes passaram e 2 novos falharam porque receberam
  `ChatMessage` quando deveriam receber `ChatFailureException`.
- GREEN: 11/11 testes do adapter; os dois novos também comprovam zero
  requisições para comandos não representáveis na RPC textual.
- `flutter analyze --no-pub` dos dois arquivos: nenhum problema.
- Review independente do diff: aprovado, sem achados acionáveis.
- Nenhuma migration, recurso remoto, UI ou contrato SQL foi alterado.

Arquivos: `apps/superadmin/lib/features/chat/data/supabase_chat_repository.dart`
e `apps/superadmin/test/features/chat/data/supabase_chat_repository_test.dart`.
Contrato conferido em
`packages/coelo_database/migrations/20260901101500_superadmin_internal_chat_v2.sql`.

## Handoff

- Branch `codex/e2e-comunicacao-midia-principal`; base
  `1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
- `chat.send`: correção local do adapter; não promove Front-end a verified.
- `chat.attach`: permanece aberto, sem implementação produtiva de mídia.
- Back-end e E2E: inalterados. Ainda exigem gateway, autorização, objeto privado,
  negativas, persistência/reload e cleanup aplicáveis.
- Gate de memória: `no-op`; aplica o contrato textual existente, sem decisão
  nova ou alteração de conhecimento de produto aprovado.
