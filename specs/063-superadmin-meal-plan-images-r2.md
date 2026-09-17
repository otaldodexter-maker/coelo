---
title: "Imagens de Cardápios em R2 privado pelo Media Gateway (r12-38)"
source: "docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md (R12-38); R15-pendencias.md (owner.r12-38); decisions/0032-mvp-private-media-r2.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.meal_plan_image_assets, app_private.meal_plan_image_upload_intents, app_private.meal_plan_image_delete_requests, app_private.meal_plan_prepare_image_upload, app_private.meal_plan_finalize_image_upload(_unreceipted), app_private.meal_plan_image_download_descriptor, public.meal_plan_claim_image_cleanup, public.meal_plan_complete_image_cleanup, app_private.meal_plan_request_image_delete_unreceipted; Edge now-media/moments-media/meal-plan-image-cleanup; apps/superadmin SupabaseMealPlanImageRepository"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Imagens de Cardápios em R2 privado (`owner.r12-38`)

## Objetivo

O adapter `SupabaseMealPlanImageRepository` e os contratos de vínculo usam
Supabase Storage (`coelo-meal-plans-private`), incompatível com a mídia
privada do MVP (ADR 0032, R2). Esta spec migra o fluxo para o Media Gateway
(prepare → PUT assinado → finalize com verificação server-side → leitura por
URL assinada curta) e habilita o envio de imagem no wizard (hoje desabilitado).
Nenhum ativo legado é migrado: linhas existentes ficam `supabase_mvp` e
continuam legíveis pelo caminho legado.

## Modelo de dados (forward-only)

- `public.meal_plan_image_assets.storage_provider` (`supabase_mvp` |
  `r2`, default `supabase_mvp`); `storage_bucket` passa a aceitar
  `coelo-media-prod` quando `r2`. Chave R2 opaca no formato canônico:
  `tenants/<tenant>/meal_plans/<resource_kind>/<resource_id>/image/<asset>/original/<uuid>.<ext>`
  (gatilho `meal_plan_image_asset_parent_guard` valida os dois formatos).
- `app_private.meal_plan_image_finalize_tickets`: bilhete de finalize (2 min),
  consumido uma vez pelo gateway.

## RPCs novas (v1 intactas)

| RPC | Ator | Efeito |
|---|---|---|
| `meal_plan_prepare_image_upload_v2(p_resource_kind, p_resource_id, p_file_name, p_mime_type, p_size_bytes, p_alt_text, p_idempotency_key)` | `meal_plans.manage` + `meal_plan_scope_allowed` | mesmas validações da v1; cria ativo `pending` em R2; devolve descritor (`asset_id`, `storage_provider`, `bucket_id`, `object_key`, `mime_type`, `max_bytes`, `expires_at`); idempotente por `p_idempotency_key` |
| `meal_plan_authorize_image_finalize_v2(p_request_id)` | dono da intenção | bilhete + descritor |
| `meal_plan_finalize_image_upload_v2(p_request_id, p_finalize_ticket, p_byte_size, p_mime_type, p_checksum_sha256, p_alt_text, p_replace_asset_id)` | **service_role** | consome o bilhete; exige bytes/MIME iguais ao declarado; ativa o asset, substitui o anterior (`pending_delete` + pedido de limpeza); idempotente pela intenção; auditado |
| `meal_plan_image_read_descriptor_v2(p_asset_id)` | `meal_plans.read` + escopo | descritor para URL assinada de 300 s (sem URL no payload) |

Ajustes em funções existentes (corpo de produção + condição por provedor):
`meal_plan_claim_image_cleanup` devolve `storage_provider` e o bucket real;
`meal_plan_complete_image_cleanup` só consulta `storage.objects` para
`supabase_mvp`; `meal_plan_request_image_delete_unreceipted` trata ativo R2
como "objeto existe" (vai a `pending_delete` e à fila de limpeza).

## Media Gateway

Edge `meal-plan-media` (modelo `now-media`, ramo R2): `prepare`, `finalize`
(bytes relidos do R2, assinatura JPEG/PNG/WebP, checksum calculado no
servidor) e `read`. `meal-plan-image-cleanup` ganha o ramo R2 (delete pela
`R2Client`). CORS: `MEAL_PLAN_MEDIA_ALLOWED_ORIGINS` ou `COELO_ALLOWED_ORIGINS`.

## Frontend

`SupabaseMealPlanImageRepository` passa a usar o gateway (prepare → PUT →
finalize; leitura pelo `read`); a exclusão continua por
`meal_plan_request_image_delete` (revisão). Rotas produtivas de Cardápios
ligam `imageSelectionEnabled`. O wizard mostra uma prévia da imagem já
vinculada (URL assinada) após reload.

## Aceite

- pgTAP: prepare v2 gera chave R2 canônica e ativo `pending`; finalize v2 só
  `service_role`, só com bilhete, bytes iguais; ativo `active` com `r2`;
  substituição enfileira limpeza com `storage_provider`; descritor sem URL;
  escopo cross-tenant negado; v1 intacta para legado; nenhum 40001.
- Edge: `deno test` local; deploy `meal-plan-media` e `meal-plan-image-cleanup`.
- Flutter: adapter com transporte falso (prepare/PUT/finalize/read), rotas
  com envio habilitado, wizard sem regressão (suítes de Cardápios verdes).
- Rota real (`qa-r06-operacoes`/`publicacoes`): upload real em
  `meal-plans.create`, vínculo persistido, prévia após reload em `edit`,
  `publish` e `model-edit` sem regressão; negativa de leitura de asset alheio
  (403) → `owner.r12-38` done.
