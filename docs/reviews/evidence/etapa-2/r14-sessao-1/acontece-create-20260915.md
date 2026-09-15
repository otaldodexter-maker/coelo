---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md"
status: evidence
generated_at: 2026-09-15
---

# Acontece › Criar (`acontece.create`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `d09da7ead`, origem
`http://127.0.0.1:3014`, CDP 9414, sessão `qa-r06-publicacoes`, Owner; contexto Principal "QA R04 Cuidado
(sintetico)"). Mídia real (PNG 64×64) pelo seletor nativo interceptado por CDP
(`ferramentas/cdp_filechooser.dart`), sem picker sintético. Capturas em `capturas/acontece-create-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| acontece.create | `/principal-happens/publish`: "Adicionar fotos ou vídeos" → seletor real → miniatura e prévia com a imagem; legenda "Publicacao R14 Sessao 1 no Acontece pela rota real." (01); "Público e contexto" QA R04 Cuidado, chip "Famílias" (02) → "Publicar no Acontece" → volta ao feed `/principal-happens` com o post no topo (03). | `save_happens_draft` + Edge Function `happens-media` (prepare → PUT presignado → finalize; origem 3014 aceita) + `publish_happens_post`: post `ce6426cd-aa5d-4617-8973-8e2036656a8e` publicado (`effective_published_at 2026-09-15T13:19:04Z`, `management_version 2`, 1 mídia `image/png` com `read_ticket`), relido por `list_visible_happens_feed` na instituição `d0c40000…0001`. | Carga completa de `/principal-happens` relê o post com a imagem (04). | `save_happens_draft` com `institution_id` alheia (`…0099`) → `403 42501 happens_permission_denied`. |

Observações: nenhum defeito de código; nenhum teste alterado. Múltiplos anexos/MP4 e a origem `localhost:3000`
citados em `Principal-pos-R10.md` seguem como gate próprio daquele documento, não deste `action_id`.
