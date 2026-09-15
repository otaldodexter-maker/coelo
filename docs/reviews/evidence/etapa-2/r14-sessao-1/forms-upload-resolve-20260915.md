---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; folga do Bloco C"
status: evidence
generated_at: 2026-09-15
---

# Arquivos de Formulários › Upload (`forms.upload`) e › Resolver (`forms.resolve-file`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `065a5a59f`, origem
`http://127.0.0.1:3014`, CDP 9414, sessão `qa-r06-publicacoes`, Owner). Formulário sintético `[R08-G0…]`
(`afa8f922-b27d-4258-9322-8b3f96ee7df9`, instituição QA R04 Cuidado). O upload real está no editor
("Imagens da pergunta", contrato `question-image`) e na resposta (Galeria/Foto); a ocorrência do fixture R08
(`5762fe8f`) não abre para este ator ("Não foi possível abrir a resposta"), então a prova usou o editor. Mídia real
(PNG 64×64) pelo seletor nativo interceptado por CDP (`ferramentas/cdp_filechooser.dart`).
Capturas em `capturas/forms-upload-*.png` e `capturas/forms-resolve-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| forms.upload | `/forms/afa8f922…/edit` › pergunta "teste" › "Imagens da pergunta" → diálogo "Até 5 imagens. JPEG, PNG ou WebP, até 4 MB" › "Selecionar imagem" → seletor real → "Imagem da pergunta confirmada." com "Ver imagem 1 / Excluir imagem 1" (01). | Edge Function `form-media` (`purpose question-image`): `superadmin_form_media_prepare_v2` → PUT presignado R2 (`coelo-media-prod`) → `superadmin_form_media_authorize_finalize_v2` + `form_media_finalize_question_r2_v1` (vínculo pergunta↔asset no servidor). | Carga completa do editor + "Imagens da pergunta" relê "Ver imagem 1" (02). | `superadmin_form_media_resolve_v2` com asset inexistente → `404 FORM_MEDIA_NOT_FOUND` (não enumerável); pgTAP `forms_question_media_r2_v1` já certificado no BE. |
| forms.resolve-file | "Ver imagem 1" → `/forms/media/:assetId` "Mídia protegida": a imagem enviada é renderizada a partir da URL assinada curta (resolve-01). | `superadmin_form_media_resolve_v2` → ticket de leitura R2 (TTL curto) via EF `form-media`. | Ticket expira por desenho; o vínculo relido pelo editor (02) garante nova resolução. | idem (`FORM_MEDIA_NOT_FOUND`); sem `Authorization` a EF devolve 401 (R09). |

Observações: nenhum defeito de código; nenhum teste alterado. O upload em **resposta** (Galeria/Foto) não foi
exercitado nesta fatia porque exige ocorrência aberta e identificada para o ator; fica registrado como sobra de
massa (criar ocorrência para o Owner sintético), não como bloqueio de contrato — o mesmo pipeline
prepare/PUT/finalize/resolve foi provado pelo caminho `question-image`.
