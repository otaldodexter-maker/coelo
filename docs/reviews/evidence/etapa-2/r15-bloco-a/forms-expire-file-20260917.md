---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 4); r14-sessao-6/forms-expire-delete-file-20260916.md (roteiro de retomada, lote 73); ADR 0031; ADR 0032"
status: evidence
generated_at: 2026-09-17
---

# Formulários › Arquivos › Expirar (`forms.expire-file`) — rota real, 17/09/2026

Mesmo ambiente de `forms-create-edit-delete-file-20260917.md` (produção, build `ab96072de`, `127.0.0.1:3014`,
CDP 9414, tema claro, viewport 1424×2200), sessão `qa-r06-formularios@coelo.me`, formulário
`90b905a1-923a-4cec-bd96-fbdb63fa0be6` ("R15 A Formulario QA"), pergunta B (`80f7ad3b…`). Não existe botão
"expirar" na tela produtiva (o card de `/forms/:id/files` é fixture de desenvolvimento): a expiração é o worker
`form_media_expire_question_r2_v1` disparado pelo `pg_cron` (`coelo-forms-media-expire`, a cada 5 min) sobre
tickets de upload vencidos (30 min), com auditoria `forms.media.expire` (lote 73). Capturas em
`capturas/forms-expire-*.png`.

| Passo | Rota normal | Produção | Reload | Negativa |
|---|---|---|---|---|
| Upload interrompido | Editor → "Imagens da pergunta" → com o PUT presignado do R2 bloqueado por CDP (`Network.setBlockedURLs *r2.cloudflarestorage.com*`) → "Selecionar imagem" → seletor nativo → PNG real → o diálogo mostra "Não foi possível concluir o envio. Verifique ou descarte a imagem." com "Verificar envio" e "Descartar envio" (00), sem falso sucesso. | `form-media prepare` criou o asset `9e437fa9-06ca-4292-a7df-2d55b460355a` (`question-image`, **`status pending`**, 16:53:47Z) — relido em `form_get_editor.media_context.question_images[0]` após carga completa. | Carga completa do editor → "Imagens da pergunta" lista "**Imagem 1 não confirmada**" + "Excluir imagem 1" (01); nada é servido. | `form-media resolve` do asset pendente → `409 {"error":"FORM_MEDIA_NOT_READY","message":"O arquivo ainda não terminou de ser enviado."}` (sondado a cada 60 s a partir de 17:09Z). |
| Expiração pelo worker | Sem ação do usuário: ticket vence às 17:23:23Z (`expires_at`, leitura D1); o cron `coelo-forms-media-expire` (`*/10 * * * *`, `app_private.forms_media_dispatch_cleanup_worker()`) executa "succeeded, 1 row" (17:50Z) — mas isso é só o `net.http_post` enfileirado para a Edge `form-media` (`{"action":"cleanup"}` com o bearer do Vault). | **Bloqueio de ambiente/config (17/09 ~15:00 BRT)**: em `net._http_response` cada disparo recebe `401 {"code":"UNAUTHORIZED_INVALID_JWT_FORMAT"}` — a Edge `form-media` está publicada com `verify_jwt=true` (versão 22), então o gateway rejeita o bearer do worker (segredo do Vault, não é JWT) antes de `handleWorker` chamar `form_media_expire_question_r2_v1`/`form_media_claim_cleanup_r2_v1`. O asset `9e437fa9…` segue `pending` (54+ min após o upload, `used_at null`), 409 `FORM_MEDIA_NOT_READY` a cada sondagem (17:09–17:5xZ). Correção em dev (config `verify_jwt=false` para `form-media`, mesmo padrão de `circular-media`; o handler valida o JWT do usuário e o bearer do cron por conta própria); deploy depende de autorização do Owner. | (após o deploy: reload do editor sem "Imagem 1 não confirmada"; `resolve` → 404 `FORM_MEDIA_NOT_FOUND`; `forms.media.expire` em `audit.audit_logs` por D1) | (idem) |

## Estado

FE do fluxo (upload interrompido → "não confirmada" → nada servido) provado; a expiração autoritativa fica **bloqueada por ambiente** até a Edge ser reimplantada com `verify_jwt=false`. Nenhum estado por action_id alterado nesta fatia.

## Observações

- A imagem pendente não foi descartada pelo usuário de propósito: a prova é do ciclo autoritativo do servidor.
- A auditoria `forms.media.expire` em `audit.audit_logs` não é legível pela identidade QA via PostgREST (RLS
  deny-by-default); a confirmação depende de leitura autorizada (D1) pela coordenação, quando disponível.
