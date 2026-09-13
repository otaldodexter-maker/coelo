---
source: R12 C0 — chat.attach mosaic acceptance
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-52 — primeiro aceite do mosaico

Recorte: Etapa 2 → `apps/superadmin` → Coelo (Principal) → Conversas →
thread → múltiplas mídias visuais da mesma mensagem → `chat.attach`.

O consumidor agora agrupa as mídias visuais já vinculadas à mensagem em um
mosaico de até três itens, preserva os anexos reais e exibe a quantidade de
itens adicionais. Mensagens com uma mídia ou anexos não visuais mantêm o tile
existente. O contrato produtivo `SupabaseChatRepository`/`chat-media` não foi
alterado; cada preview continua reautorizado pelo binding privado.

Provas locais, Windows, checkout `dev`, base `8202d3bf8`:

- `flutter test test/features/chat/presentation/superadmin_chat_page_test.dart`: 32 PASS;
- `flutter test test/features/chat/presentation/superadmin_chat_attachment_tile_test.dart`: 21 PASS;
- `flutter test test/features/chat/presentation/superadmin_chat_inline_video_test.dart`: 4 PASS;
- `flutter analyze --no-fatal-infos`: PASS, sem issues.

O teste novo foi conduzido em TDD: primeiro falhou sem o mosaico, depois passou
com a composição atual. O aceite fechado nesta fatia é FE `local-green` para
composição/redução visual local. Não há certificado novo de rota real, upload
MP4, reload ou negativa cross-tenant; o estado integrado permanece
`pending-verification` e o backend permanece inalterado.

Próximo gate: provar a rota normal com a sessão QA, mídia R2 real, reload e
negação de escopo, sem usar fixture como certificado.
