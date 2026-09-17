---
title: "R15 Bloco C1 — Chat › anexos por mensagem (E3, spec 058): rota real em produção"
source: "ADR 0042 E3; spec 058; migration 20260917120000_chat_attachment_batch_v2 (lote 76); Edge chat-media; R15-prompts.md (Prompt C1)"
status: "verified"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# Chat › anexos por mensagem (`chat.attach`, `owner.r12-52`) — 17/09/2026

Ambiente: produção Supabase (`evvbomzejfijozbtgvpt`); build
`flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true` da worktree `r15-bloco-c1` em `d27a829db`,
servido por `serve.py` em `127.0.0.1:3016`; Chrome CDP `9416` (SwiftShader, perfil
`%TEMP%\coelo-r15-c1-chrome`); sessão `qa-r06-publicacoes@coelo.me` (Owner de plataforma,
tenant sintético `QA R04 Cuidado`, `d0c40000…0001`), conversa `Grupo R14 Sessao 1`
(`7f54da12-37d2-42dd-b412-4d40b3ebfd87`, massa da R14 S1). Arquivos sintéticos sem dados
pessoais: quatro PNG 64×64 de cor sólida (179 B) e um PDF de uma página com o texto
"QA R15 sintetico" (441 B). Upload real pelo seletor nativo interceptado por CDP
(`Page.setInterceptFileChooserDialog` + `DOM.setFileInputFiles`, modo `selectMultiple`).

## Backend em produção (lote 76)

- Migration `20260917120000_chat_attachment_batch_v2.sql` aplicada pelo rito: espelho
  `mirror-r15-c1` (dump `c87f4d67` + catálogos de produção), pgTAP
  `superadmin_internal_chat_attachments_batch_v2` 51/51, `superadmin_internal_chat_attachments_v1`
  28/28 e `r13/chat-attachment-limit-per-send` 9/9 (logs nesta pasta); dump prévio
  `Coelo-backups/schema-producao-20260917-r15-c1-e3-before.sql` (SHA-256 `c87f4d67…`);
  `supabase db query --linked -f` + `migration repair --status applied 20260917120000`; ledger
  remoto listado com `20260917090000` (Bloco B, lote 75) e `20260917120000`. Verificação
  pós-aplicação (leitura): `prepare_v2`, `finalize_v2`, `discard_v1` presentes, coluna
  `chat_attachment_metadata.position`, `anon` sem execute, `authenticated` sem execute em
  `finalize_v2`.
- Edge `chat-media` implantada (`supabase functions deploy chat-media --project-ref
  evvbomzejfijozbtgvpt`) após `deno test` 7/7 (`index_test.ts` + `cors_test.ts`).

## Rota real

| Passo | O que foi feito | Resultado observado | Captura |
|---|---|---|---|
| Lote de 3 imagens | ícone "Adicionar imagem" → seletor nativo com 3 PNG → diálogo "Arquivos da conversa" lista os 3 ("serão enviados juntos, como uma única mensagem") → "Enviar 3 arquivos" | rede: 1 `chat-media` (prepare em lote) → 3 PUT R2 (200) → 3 `chat-media` (finalize) → `superadmin_chat_thread_v2`; **uma** mensagem "3 anexos" com mosaico de 3 tiles e as miniaturas reais (R2 privado, `read` + GET assinado 200) | `capturas/chat-attach-03-dialog-3png.png`, `…-05-mosaic-3.png` |
| Lote de 4 imagens (contador) | mesmo fluxo com 4 PNG; diálogo em "Enviando 0 de 4…" durante o envio | mensagem "4 anexos": mosaico com 3 tiles visíveis e contador **"+1"** no terceiro | `…-06-dialog-4png.png`, `…-08-sending-4.png`, `…-09-mosaic-4.png` |
| Anexo não visual | 1 PDF sintético | mensagem "qa-r15-boletim-sintetico.pdf" com tile único (`application/pdf · 441 B`, "Anexo disponível", "Abrir PDF"); inbox mostra o nome do arquivo | `…-10-dialog-pdf.png`, `…-11-pdf-tile.png` |
| Tile único visual | 1 PNG | mensagem com tile único de imagem ("Abrir imagem", miniatura inline) | `…-16-single-tile.png` |
| Falha parcial / total | `Network.setBlockedURLs(*coelo-media-prod*)` na mesma sessão CDP, lote de 2 PNG → "Enviar 2 arquivos" | os dois PUT falham; diálogo mostra "Falhou" por item, "2 de 2 arquivos não foram enviados." e só **"Cancelar envio"** (sem anexo pronto); "Cancelar envio" → `discard` ×2 → diálogo fecha, nenhuma mensagem nova; no banco a mensagem `bb73a02f` ficou `archived` com os 2 anexos `deleted`. O bloqueio também exercitou o fail-closed das miniaturas ("Não foi possível carregar a imagem" + "Carregar novamente") | `…-13-partial-failure.png`, `…-14-after-cancel.png` |
| Reload | reinício completo do Chrome (sessão mantida) e `Page.reload` | thread relida por `superadmin_chat_thread_v2` com as mesmas mensagens e miniaturas | `…-07-reload.png` (após reinício), `…-17-reload-final.png` |

Leitura da thread por PostgREST (`superadmin_chat_thread_v2`, sessão `qa-r06-publicacoes`):
5 mensagens `attachment` — `fc6f4087` "3 anexos" (3 `ready`), `169e11a8` "4 anexos" (4 `ready`),
`9e873392` PDF (1 `ready`), `7fc1f19b` "2 anexos" (2 `ready`), `4dba28fa` PNG (1 `ready`) — todos
com `asset_id = id` e na ordem do lote (`position`). Leitura direta do banco (coordenação,
`supabase db query --linked`, só leitura): mesmas mensagens `active`; `bb73a02f` `archived` +
`deleted_at` com `deleted:0,deleted:1`.

## Negativas por PostgREST (sem chave de serviço)

| Identidade | Chamada | Resposta |
|---|---|---|
| `qa-r06-publicacoes` | `superadmin_chat_attachment_prepare_v2` com `p_conversation_id` inexistente/alheio | `CHAT_NOT_FOUND` 404 (não enumerável) |
| `qa-r06-publicacoes` | `superadmin_chat_attachment_prepare_v2` com **11 itens** na conversa real | `CHAT_ATTACHMENT_LIMIT` 422, nada criado |
| `qa-r06-acessos` e `qa-r06-principal` (outras identidades internas) | `superadmin_chat_attachment_discard_v1` sobre o anexo `71a68ced` de `qa-r06-publicacoes` | `CHAT_NOT_FOUND` 404 (ticket de outro dono) |
| `qa-r06-acessos` | `superadmin_chat_attachment_discard_v1` sobre anexo já descartado | `CHAT_ATTACHMENT_DISCARD_INVALID` 409 |

Cross-tenant com instituição de outro tenant está coberto pelo pgTAP (`owner B` → `CHAT_NOT_FOUND`
em prepare_v2/discard/authorize_finalize, sem mutação); as identidades QA disponíveis têm escopo no
mesmo tenant sintético, por isso a negativa de rota usa conversa alheia/inexistente (mesmo padrão
de `chat.create-group` na R14 S1). Os dois rascunhos criados pelas sondas (`76e59db9`, `249b1531`)
foram descartados pelas próprias identidades (`archived`, anexo `deleted`).

## Resultado

- `chat.attach`: FE `verified` (rota real 1440, tile único, mosaico 3 e 3+1, PDF, progresso,
  falha e cancelamento), BE `done` (lote 76 + Edge), integrado `verified-e2e` (produção, reload,
  negativas).
- `owner.r12-52`: **done** — o mosaico "várias mídias da mesma mensagem" é alcançável pela rota
  normal com o contrato E3.
- Resíduo: mensagens sintéticas ficam na conversa `Grupo R14 Sessao 1` como massa (sem PII);
  objetos R2 dos anexos `deleted` foram apagados pela Edge (`discard`) quando já haviam subido.
- Observação: o seletor nativo do Chrome entregou a ordem 2,3,1 no primeiro lote; a ordem exibida
  segue a ordem recebida do seletor (`position`), não a ordem alfabética.

Ferramentas: `serve.py`, `cdp_sem.dart`, `batch.dart` (upload/block/unblock/scroll/shot),
`cdp_login.dart` (login via `window.$flutterDriver`, credencial só do ambiente, marca "Manter
sessão aberta"), `r13-rpc-proof.mjs`.
