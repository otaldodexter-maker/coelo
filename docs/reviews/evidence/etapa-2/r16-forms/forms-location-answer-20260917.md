---
source: "Sessão FORMS da R16 (Fable 5.1), 17/09/2026; R16-prompts.md (Prompt 1); R16-execucao.md (autorização 3); R15-handoff-bloco-a.md (roteiro); inventario-etapa-2.json (forms.location-answer)"
status: evidence
generated_at: 2026-09-17
---

# Formulários › Responder com Local (`forms.location-answer`) — rota real, 17/09/2026

Ambiente: produção (`evvbomzejfijozbtgvpt`), build QA de `r16/forms-location-answer` (base `dev cd5b7493e`,
`flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`), servidor `serve.py` em `127.0.0.1:3014`, Chrome CDP `9414`
(`--use-angle=swiftshader`, perfil novo `%TEMP%\coelo-r16-forms-chrome`, tema escuro, viewport 1424×1125).
Sessão `qa-r06-formularios@coelo.me` (Owner de plataforma, contexto QA R04 Cuidado (sintetico)); pessoa-ator
`9f944691-6a32-450d-b65d-b8bfb7dd07d9`. Login pela tela: `tap` do driver não responde (como em 17/09 de manhã);
usados `cdp_sem.dart clickxy` por coordenada + `enter_text` do driver (credencial só no ambiente do processo).
Readback e negativas por PostgREST com a mesma identidade (`packages/coelo_database/scripts/r13-rpc-proof.mjs`).
Capturas em `capturas/` (sem PII: identidades sintéticas, ids de massa QA).

## Passos e resultado

| # | Passo (tela) | Resultado em produção | Captura |
|---|---|---|---|
| 1 | `/forms/4555ba07…/edit` → "Visualizar prévia" mostra "1. Nova pergunta de texto curto *" e "2. Em qual local? *" (v4 de trabalho) → "Publicar ou agendar" → diálogo "Publicar formulário" (Quando publicar: Publicar agora) → "Publicar agora" | `form_publish` promoveu a versão de trabalho: `form_get_overview` devolve `status published`, `management_version 5` (era 4) e a definição publicada com o item `location` `90d33a71…` "Em qual local?" (opção `0792b3e5…` "[R04-QA] Local Sala Azul", `location_id fc446535…`, `active`, `available true`). | 01, 02, 03, 04, 05 |
| 2 | Visão geral → "Distribuir" → passo "Público e agendamento" (Instituição QA R04 Cuidado (sintetico), Toda a instituição) → "Continuar" → "Editar agendamento" (estava Diário, 11/09 12:55 → 11/10) → Frequência "Uma vez", Data de início 17/09/2026 20:00 → "Salvar" | `form_save_application` + `form_save_schedule` (mesmo `schedule_id`, `recurrence_kind once`, `starts_at_local 2026-09-17 20:00`); o worker `generate_occurrences` criou uma ocorrência nova: `occurrence_count` 31 → 32 (`form_get_overview`). As 31 ocorrências diárias antigas permanecem (o gerador só insere; não apaga), mas nenhuma nova será gerada. | 06, 07, 07b, 07c, 07d, 08, 09 |
| 3 | Leitura D1 da coordenadora (23:41Z, só metadados) | Ocorrência nova `c42cf334-c72f-488b-9604-47fc574447f9`: `open`, `scheduled_local 2026-09-17 20:00`, `opens_at 23:00Z`, `closes_at 24/09 23:00Z`, `form_version_id e0107c9d…` = versão publicada nova (`version_number 2`, `published_at 23:30:15Z`; `forms.published_version_id = e0107c9d`, `working_version_id null`; a antiga `49c338d7…` `superseded`). O cron `coelo-forms-occurrences` (*/5, `form_run_periodic_maintenance → form_reconcile_due_audiences`) reconciliou às 23:40Z: 11 participações; a pessoa `9f944691…` tem participation `12aa895e-2c54-4c6e-9f78-09ba720fb393`, `eligible`, `pending`. | — |
| 4 | Deep link `/forms/4555ba07…/occurrences/c42cf334…/respond` logada como `qa-r06-formularios` → "Responder formulário · Resposta identificada" com "Nova pergunta de texto curto *" e "Em qual local? *" (chip "[R04-QA] Local Sala Azul") → texto "R16 FORMS resposta com Local" → chip do local selecionado → "Salvar rascunho" → "Rascunho salvo." → "Revisar resposta" (Revisão da resposta lista as duas respostas) → "Enviar resposta" → "Resposta enviada · Esta resposta foi confirmada pela fonte autorizada." | `form_get_occurrence_for_response(c42cf334)` → `can_edit true`, `form_version_number 2`, `participation_id 12aa895e…`; `form_open_response_draft`/`form_save_response_draft`/`form_submit_response` pela tela → resposta `b1d52e77-782e-49e6-9e2f-cace222b4b54` (`submitted_at 23:43:50Z`, `form_version_id e0107c9d…`), relida por `form_list_responses` (filtro por ocorrência) e por `form_get_response_detail`: answer `location` item `90d33a71…` com `option_ids ["0792b3e5-1721-4c72-8fc5-07adc5221e48"]` (Local `fc446535…`) e `short_text` com o texto. | 10, 11, 12, 13, 14 |
| 5 | Carga completa da mesma URL (`Page.reload`) | Tela volta em "Resposta enviada" com o resumo "Em qual local?: [R04-QA] Local Sala Azul" e botão "Editar resposta" — resposta relida do servidor. | 15 |

## Negativas por PostgREST (mesma sessão QA; nenhuma mutação — `form_get_response_detail` idêntico antes e depois)

| Caso | Chamada | Resultado |
|---|---|---|
| Localização inválida (opção inexistente) | `form_edit_response` v4 da resposta `b1d52e77…` com `option_ids ["00000000-…-0099"]` no item Local | **`400 22023` "answer option unavailable"** |
| Localização com duas opções / sem opção | idem com `option_ids [0792b3e5…, 0000…0099]` e com `[]` | **`400 23514` "multiple choice selection count is out of range"** (Local exige exatamente 1) |
| Versão defasada da resposta | `form_edit_response` com `p_expected_version` 0–3, 5, 6 | `409 PT409 FORMS_STALE_VERSION` "expected_version mismatch" (PT409, nunca 40001) |
| Ocorrência inexistente | `form_get_occurrence_for_response(0000…0099)`; `form_open_response_draft` com `occurrence_id 0000…0099` | `500 P0002` "form occurrence unavailable" (fail-closed, sem enumeração; o mapeamento 500 é resíduo já conhecido, igual a `form_get_editor` em 17/09) |
| Participação alheia | `form_open_response_draft(c42cf334, participation_id 0000…0099)` | `500 P0002` "form occurrence unavailable" |
| Ocorrência fora da janela (`scheduled`, abre 18/09 15:55Z) | `form_get_occurrence_for_response(90272261-cea3-4ca9-bbbc-d0b49a455cb5)`; `form_open_response_draft(90272261…)` | `200 can_edit false`; `500 P0002` "form occurrence unavailable" |
| Formulário/ocorrência de outro tenant → 403 | — | **Sem massa**: a leitura D1 da coordenadora confirma que não existe `form_occurrence` fora do tenant `d0c40000-…0001` em produção, e a pessoa `9f944691…` é participante de todas as 32 ocorrências deste form (cron reconciliou), logo "mesma instituição sem participação" também não tem massa. A rejeição de escopo fica provada por id inexistente/participação alheia (P0002) e pela janela fechada. |

## Observações / resíduos (sem action_id novo)

- **`form-diario`** (fora do foco da R16): trocar o agendamento de "Diário" para "Uma vez" não cancela as ocorrências já geradas — as 24 `scheduled` de 18/09 a 11/10 permanecem (agora apontando para `e0107c9d…`) e a de hoje `7256b047…` (versão antiga) segue `open`. O gerador só insere (`on conflict do nothing`); não há tela para remover ocorrências. A massa "Diário" deixa de crescer, mas não foi desfeita.
- Após "Publicar agora" o editor não mostra feedback (nem snackbar nem mudança de rótulo); a confirmação só aparece na Visão geral ("Publicado", versão de gestão 5). Foram necessários dois cliques no botão do diálogo (o primeiro após abrir o popup não registra — comportamento já anotado em 17/09).
- O `tap` do driver segue sem responder no login; `clickxy` + `enter_text` funcionou na primeira tentativa com perfil novo (sem travamento do SwiftShader nesta sessão).
- A chave de conflito das ocorrências é `(schedule_id, scheduled_local, time_zone)`: um "Uma vez" no mesmo horário de uma ocorrência existente não gera nada; por isso a ocorrência única foi criada às 20:00 e não às 12:55.
- `form_get_response_detail` é `(p_response_id)` no servidor; chamada com `p_query` responde PGRST202 (a tela usa o wrapper correto; sem impacto).
