---
name: coelo-backend
description: Use when a Coelo task involves Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Cloudflare R2, Media Gateway, migrations or production.
metadata:
  status: "active"
  updated_at: "2026-09-18"
---

# Coelo Back-end (modo de construção, ADR 0045 §7)

Construa, teste, aplique, mostre. Sem recorte, evidência, handoff ou rodada.
Versão anterior (com o rito completo) em `docs/archive/skills-20260918/`.

## Onde está

- Migrations: `packages/coelo_database/migrations/` (forward-only, carimbo
  `YYYYMMDDHHMMSS_nome_vN.sql`); cópia em `packages/coelo_database/supabase/migrations/`.
- pgTAP: `packages/coelo_database/tests/`. Edges: `packages/coelo_database/supabase/functions/`.
- Produção = único remoto: projeto `evvbomzejfijozbtgvpt`. Último lote: ver a
  última linha de `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`.

## Como aplicar

1. Escreva a migration e o pgTAP; rode o pgTAP num Postgres local ou espelho.
2. `supabase db query --linked --workdir packages/coelo_database -f migrations/<arquivo>`
3. `supabase migration repair --status applied <carimbo> --linked` (exige a cópia em `supabase/migrations/`), depois `supabase migration list --linked`.
4. Anote o arquivo no fim de `ordem-de-aplicacao-producao.txt`.
5. Edge: `supabase functions deploy <nome> --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database`; Edge chamada por pg_cron usa `verify_jwt = false` e valida o bearer no handler.

Dump prévio, espelho de ACL e SHA-256 só quando o Owner pedir revisão formal.

## Regras que não mudam

- RLS deny-by-default; RPC valida ator, capacidade, tenant e hierarquia no servidor. Nada de IDOR/BOLA.
- `service_role`, token, CPF, dado de criança e mídia privada nunca em cliente, Git, log ou URL.
- Mídia: R2 privado via Media Gateway (ADR 0032); Postgres guarda catálogo, permissões e auditoria.
- Versão defasada: `raise exception using errcode = 'PT409', detail = '<FAMÍLIA>_STALE_VERSION'`. **Nunca 40001** (derruba o PostgREST).
- Busca por dado pessoal: mínimo de caracteres, escopo no servidor, CPF nunca no resultado.
- Responsável sem membership: leitor reconhece por `guardian_links` + `can_view` (`app_private.now_reader_actor`); escrita continua só de equipe.
- Identidades QA: `qa-r06-<area>`, `qa-r15-responsavel`; credenciais em `C:\Users\adrie\Documents\Coelo-backups\`, nunca impressas.
- Acesso contextual (lote 84): `app_private.has_context_permission` e `has_active_institution_membership` ignoram a membership bloqueada por `app_private.staff_access_blocked` (regra/afastamento do vínculo, fuso da unidade, header `x-coelo-surface`); RPC nova que resolva membership de equipe sem passar por elas precisa filtrar também.
- Horário por perfil (lote 86): a regra efetiva do vínculo sai só de `app_private.staff_access_effective_rule` (própria > perfil atribuído > nenhuma); nunca leia `staff_access_rules`/`staff_access_profile_rules` direto para decidir. Negação com motivo: `app_private.staff_access_assert(inst, unit, group[, person])` no começo do resolvedor de ator (`errcode PT403`, `message STAFF_ACCESS_DENIED`, `detail` JSON) — em leitores com caminho de família, só depois que equipe e família falharam. Leitor novo que junte `institution_memberships` para destinatário/notificação/feed acrescenta `and not app_private.staff_access_blocked(m.id)`.
- @ estrutural (lote 100): o @ da atividade é `stem.@daunidade` ou `stem.@dainstituicao` (`app_private.activity_canonical_handle_for`), stem normalizado por `activity_handle_stem_normalize` (sem hífen); unicidade global do @ completo em `structure_handle_in_use` (inclui `activity_handle_aliases`); `availability_v1('activity', …)` só confere unicidade quando recebe o @ com ponto; gatilho de alias ouve todo UPDATE (UPDATE OF coluna não vê mudança feita no BEFORE).
- Carimbo de migration: antes de criar, `git fetch` e `supabase migration list --linked`; sessões paralelas já colidiram no mesmo `YYYYMMDDHHMMSS` (o `migration repair` sobrescreve o nome no ledger).
- Conta de pessoa real (`person_auth_links`) e identidade interna são realms separados por trigger: a mesma conta nunca abre o shell do Superadmin; fixture QA de pessoa real prova pela API, e a prova visual no Principal hospedado usa um espelho interno (`qa-r06-principal`).
- Ciclo de vida (lote 94, spec 066): "pode excluir de verdade" é só `app_private.lifecycle_can_hard_delete_v1(entity, id)` (varre FKs de `public`/`audit`, trilha além do create e mídia; vínculos de serviço dos operadores internos não contam); sem isso, exclusão é lógica (`status='archived'` + `deleted_at`). Motivo de transição vai na coluna da entidade (`lifecycle_reason`), porque `audit_logs.reason_code` só aceita código (`LIFECYCLE_OPERATOR_REASON`); `after_json` passa por `audit_mask_payload` (allowlist de chaves — `source_notice_id` some, `id` fica).
- Catálogos read-only (health_care_catalog_items, official_profiles, location_map_markers): RLS deny sem grant a cliente; a leitura é sempre por RPC `superadmin_*_v1`. Ids de catálogo em `health_care_profile_items` obedecem `^[a-z][a-z0-9_]*$` (sem ponto).
- Mais de um perfil com regra no mesmo vínculo (lote 102): `staff_access_evaluate` reavalia cada perfil (`staff_access_effective_rule(membership, role)`) e devolve o primeiro bloqueio — regra nova de horário nunca escolhe "o mais antigo"; regra própria segue acima de todos.
- Mídia sempre pela Edge (lotes 85–89, 92, 99, 103): upload binário = POST `application/octet-stream` com o envelope do prepare em base64url no header `x-coelo-media-envelope` (a Edge faz prepare → PUT no R2 → finalize); leitura = `inline: true` devolve bytes + `X-Coelo-Content-Type`. Vale para entity-media, moments/now/happens/circular/chat/meal-plan/child-safety-media e form-media (`_shared/edge_bytes.ts`). O navegador nunca recebe URL assinada do R2. `entity_image_assets`: leitura em lote (`superadmin_entity_images_list_v1`, `internal_user` chaveado pela identidade), leitor do Principal (`principal_entity_images_list_v1` por `guardian_links`+`can_view`), `icon_vector` SVG ao lado do PNG, `floor_plan` só institution/unit raster, rascunhos expiram no pg_cron `coelo-entity-media-expire`. Leitor de família dos feeds (`app_private.family_reader_actor` → moments/happens/circular_reader_actor) e `author_person_id` projetado em list_visible_moments/happens_posts/now_publications.
