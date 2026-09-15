---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md; review-scope.md (rota real 14/09)"
status: evidence
generated_at: 2026-09-15
---

# Circulares › Anexos (`circulars.attach`) — rota real em produção, 15/09/2026

Ambiente: Supabase de produção (`evvbomzejfijozbtgvpt`); build
`flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true` da worktree `r14/bloco-ab` (código de
`0c8add8a7`, handoff em `3321cef07`), servido por `serve.py` em `127.0.0.1:3014`; Chrome CDP
`9414` (SwiftShader, perfil `%TEMP%\coelo-r14-ab-chrome`); sessão `qa-r06-publicacoes@coelo.me`
(Owner) na instituição sintética `QA R04 Cuidado (sintetico)` (`d0c40000-…0001`).
Negativas por `packages/coelo_database/scripts/r13-rpc-proof.mjs` (PostgREST, mesma sessão,
sem chave de serviço). Capturas em `capturas/circulars-attach-*.png`.

## Método novo: seletor de arquivo real dirigido por CDP

O bloqueio da R09 (`fileChooser.setFiles` recusado) foi contornado sem emulação de picker:
`Page.setInterceptFileChooserDialog{enabled:true}` → clique em "Adicionar mídia aqui" abre o
seletor nativo do `file_picker` → evento `Page.fileChooserOpened` (`mode=selectMultiple`,
`backendNodeId`) → `DOM.setFileInputFiles{files:[caminho], backendNodeId}`. O arquivo é um PNG
real de 64×64 (7.858 bytes) gerado no scratchpad; nenhum `--dart-define` de picker sintético
foi usado (`COELO_QA_SYNTHETIC_CIRCULAR_FILE` ausente do build). Script: `ferramentas/cdp_filechooser.dart`
(ver seção "Ferramenta" abaixo).

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| circulars.attach | `/circulars/new` → "Onde publicar?" QA R04 Cuidado → Continuar → título "R14 S1 Circular com anexo pela tela" + corpo → "Adicionar mídia aqui" → seletor real → banner "Anexo enviado."; bloco Mídia com chip `7d0275a1-d872-4c6a-a442-b3…` (captura 01). | Edge Function `circular-media` prepare → PUT presignado R2 → finalize → `superadmin_circular_save_draft_v2`: circular `1f22b2b2-7d2c-4329-97f4-c87b0df73969` (draft, `management_version 2`, `attachment_count 1`) relida por `superadmin_circular_directory_v2` com `p_search "R14 S1"`. | `/circulars/1f22b2b2…/edit` após carga completa relê o chip `7d0275a1…` no bloco Mídia (captura 02); `/circulars/1f22b2b2…/read` mostra "1 arquivos · 0 perguntas" (captura 03). | `prepare_circular_media_upload` com `p_institution_id` alheia (`…0099`) e a circular real → `403 42501 circular_not_authorized`; `authorize_circular_media_read` com asset inexistente → `403 42501 active_membership_required`. |

Observações: nenhum defeito de código encontrado; nenhum teste alterado. Um clique acidental em
"Adicionar mídia aqui" após o reload abriu o seletor nativo e, cancelado, mostrou "Nenhum arquivo
selecionado." (comportamento esperado do fluxo normal). O rascunho `1f22b2b2` fica em produção
como massa sintética identificada por prefixo `R14 S1`.

## Ferramenta

`ferramentas/cdp_filechooser.dart` (Dart puro, sem dependências): conecta ao WebSocket da página, `Page.enable`,
`DOM.enable`, `Page.setInterceptFileChooserDialog{enabled:true}`, aguarda `Page.fileChooserOpened`
por N segundos, chama `DOM.setFileInputFiles` com `backendNodeId` do evento e desarma o intercept.
Executar em background, depois clicar no botão que abre o seletor.
