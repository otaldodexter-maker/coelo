---
title: "R14 — OQ-046: reconciliação do ledger remoto (ADR 0041 D1/D2)"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (D1, D2); docs/open-questions.md OQ-046; packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt (lote 72); ledger remoto de 16/09"
status: "done"
lifecycle: "current"
generated_at: 2026-09-16
audience: "team"
---

# OQ-046 — leitura de metadados e renome do carimbo do Chat

## Recorte

Coordenação R14, sem tela, sem `action_id` promovido. Objetivo: confirmar em
produção (somente leitura) os objetos declarados pela Sessão E e alinhar o
ledger remoto à ordem real, conforme autorizações D1 e D2 da ADR 0041. Nenhum
SQL de negócio foi executado; a única escrita foi na tabela de histórico da
CLI (`supabase migration repair --status applied`).

## D1 — leitura (sem mutação)

- Dump de schema de produção fora do Git:
  `C:\Users\adrie\Documents\Coelo-backups\schema-producao-20260916-r14-coord-before.sql`
  (4.201.264 bytes, SHA-256 `f1f677ca9964ef87282b4647e8aa26e52a8237a5e6c9b8f4f8d699a765157b51`).
- Encontrados no dump:
  - `public.person_avatar_assets` (+ índice `person_avatar_assets_tenant_idx`),
    `app_private.superadmin_account_avatar_tickets`,
    `app_private.account_avatar_extension_v1`, `app_private.account_profile_projection`
    e as RPCs `superadmin_account_avatar_{prepare,finalize,authorize_read,
    authorize_finalize,expire,remove}_v1` → conteúdo de `20260915120000` presente.
  - `public.superadmin_chat_thread_v2` devolve `'asset_id',attachment.id` nos
    anexos → conteúdo de `chat_media_asset_binding_v1` presente.
  - `app_private.seed_qa_r14_chat_cross_tenant_user(p_email,p_institution_id,p_cpf)`
    com `REVOKE ALL … FROM PUBLIC` → fixture existe. A tentativa anterior de
    negativa do Agora usou PostgREST/`authenticated`, que não enxerga
    `app_private`; a fixture só é chamável como `postgres`.
  - Também presentes, para as fatias seguintes: `app_private.child_safety_change_lifecycle`
    (D4) e `app_private.superadmin_attendance_context_options` (D3).
- Ledger remoto antes (`supabase migration list --linked`): `20260915130000`
  aparecia uma única vez (colisão Chat × `health_care_collection_limit_v1`);
  `20260915120000` ausente.

## D2 — renome forward-only e ledger

- `git mv 20260915130000_chat_media_asset_binding_v1.sql → 20260915130100_chat_media_asset_binding_v1.sql`
  (conteúdo inalterado; posição entre o lote 70 e `131500`).
- `supabase migration repair --status applied 20260915120000 20260915130100 --linked`
  → `Migration history repaired`. Ledger depois: `…130000, 130100, 131500, 133000, 185048…`
  (versões 302–303). Nenhuma migration foi reexecutada.
- `ordem-de-aplicacao-producao.txt`: lote 72 registrado; nota de
  reconciliação reduzida ao único resíduo real (`20260915203000` de
  Formulários, não aplicada, R15).
- Efeito colateral do `Sync-SupabaseCliMigrations.ps1 -Mode Prepare` (necessário
  para o `repair` achar o arquivo local): o espelho `supabase/migrations`
  recebeu cópias não rastreadas (ignoradas pelo Git). O script `-Mode Clean`
  não pôde rodar nesta sessão; **não executar `supabase db push` sem revisar
  o espelho**.

## Separação FE / BE / E2E

- FE: nenhum.
- BE: reconciliação de metadados; sem mudança de contrato.
- E2E: nenhum. Destrava o passo 5 (Agora) do plano da coordenação.
