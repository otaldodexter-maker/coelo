---
source: "R10-dev-senior; R08-G4 private attachment QA"
status: "local-green-photo; video-gated"
generated_at: "2026-09-13"
---

# C1 — Chat inline media

## Recorte

`Etapa 2 -> apps/superadmin -> Comunicação -> Conversas -> R08-G4 PNG privado QA -> chat.attach`.

O tile tratava `ready` como “Pronto para enviar” e somente oferecia o diálogo
de imagem. A correção troca o estado por “Anexo disponível” e exibe imagem
inline depois de `readAttachment(attachment_id)`. Loading, falha de leitura,
ticket expirado e sessão invalidada são estados explícitos; falha e expiração
oferecem uma única reautorização sob ação do operador. A URL curta fica somente
em memória, é limpa no vencimento e no purge de `MediaSession`; o tile não
segue `downloadUrl` nem cria acesso público.

## Provas locais

- `flutter test test/features/chat/presentation/superadmin_chat_attachment_tile_test.dart`: PASS, 19 testes, incluindo loading, read negado/retry, expiração sem loop e purge.
- `flutter analyze lib/features/chat/presentation/widgets/superadmin_chat_attachment_tile.dart lib/features/chat/presentation/widgets/superadmin_chat_inline_media.dart test/features/chat/presentation/superadmin_chat_attachment_tile_test.dart`: PASS, sem issues.
- Sem build, Chrome, remoto, SQL ou alteração de inventário/rastreadores centrais.

## Gate de vídeo

Vídeo não pode ser entregue só pela UI atual. `ChatAttachmentUpload.validate`,
o seletor de extensão do chat, `chat-media/index.ts` e
`chat-media/stored_bytes.ts` permitem apenas JPEG, PNG, WebP e PDF; o teste da
Edge Function afirma explicitamente a ausência de `video/mp4`. O player também
não existe no `pubspec.yaml`.

Para `video/mp4` privado sem Stream, a fatia coordenada precisa definir o
limite aprovado e alterar, com testes negativos de MIME/tenant/expiração:

1. allowlists e limites em `chat_repository.dart` e `superadmin_chat_page.dart`;
2. prepare/finalize/read e validação de assinatura real em `chat-media`;
3. contrato/RLS de `chat_attachment_metadata` e pgTAP;
4. `video_player` oficial e tile de vídeo que inicia pausado, usa somente a URL
   de `readAttachment`, pausa e descarta o controller no vencimento, purge ou
   troca de contexto.

Nenhum Stream, URL persistida, segredo ou fallback de autorização foi introduzido.
