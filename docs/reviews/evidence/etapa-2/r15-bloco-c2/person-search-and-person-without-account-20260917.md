---
source: "R15 Bloco C2 (Fable), 17/09/2026; ADR 0041 B5/B6; specs/061 e specs/062; R15-pendencias.md (owner.r12-17, owner.r12-18)"
status: evidence
generated_at: 2026-09-17
---

# B5 busca de pessoa autorizada e B6 pessoa sem conta — contratos, espelho e bloqueio de aplicação

Worktree `Coelo.worktrees\r15-bloco-c2`, branch `r15/bloco-c2`. Espelho próprio
`coelo_mirror_r15_c2` (portas 624xx, `Coelo-backups/mirror-r15-c2`), restaurado
do dump de schema de produção de 17/09 08:58 (0 erros) + catálogo de referência
`mirror-r14/supabase/seed.sql`. Nenhuma escrita em produção nesta sessão.

| Item | Valor |
|---|---|
| Dump prévio (schema, produção) | `C:\Users\adrie\Documents\Coelo-backups\schema-producao-20260917-r15-c2-before.sql` (4.246.011 bytes, SHA-256 `c87f4d6770602bf4dac0ba27c642d597d15babfa05ed3f0d8782565d2b2b0095`); inclui o lote 74 e antecede o lote 75 (OQ-047) |
| B5 migration | `packages/coelo_database/migrations/20260917160000_child_safety_person_search_v1.sql` (objetos novos: `app_private.person_search_hits`, `app_private/public.superadmin_person_search_v1(text)`); aplicada 2× no espelho (idempotente) |
| B5 pgTAP | `packages/coelo_database/supabase/tests/child_safety_person_search_v1_test.sql` → **33/33** (estrutura/grants, mínimos por tipo, nome/@/e-mail/celular/CPF, CPF ausente do payload, cross-tenant vazio, crianças só do escopo, 31ª chamada → `PT422`, auditoria sem o texto, `42501` sem `child_safety.read`) |
| B6 migration | `packages/coelo_database/migrations/20260917170000_child_safety_person_without_account_v1.sql` (constraint de documento sem ciphertext + contato minimizado em `authorized_people`; `public.authorized_person_documents` RLS forçada sem grants; bilhetes de finalize; RPCs `child_safety_register_person_without_account_v1`, `child_safety_person_document_prepare_v1`, `..._authorize_finalize_v1`, `..._finalize_v1` (service_role), `..._read_v1`; `child_safety_request_authorization` = corpo de produção + ramo `authorized_person_id`); aplicada 2× no espelho |
| B6 pgTAP | `packages/coelo_database/supabase/tests/child_safety_person_without_account_v1_test.sql` → **40/40** (RLS/grants, CPF inválido, CPF com conta → `PERSON_HAS_ACCOUNT`, dedupe por CPF, recibo idempotente, sem documento → `PERSON_DOCUMENT_REQUIRED`, chave R2 canônica, descritores sem URL, prepare/finalize/leitura cross-tenant negados, finalize só service_role com bilhete único, autorização pendente criada, detalhe da criança projeta a pessoa sem conta, persistência só HMAC + últimos 4, auditoria sem CPF) |
| Edge | `packages/coelo_database/supabase/functions/child-safety-media` (prepare/finalize/read, só R2 `coelo-documents-prod`); `deno test --allow-read --allow-env --no-check index_test.ts` → **6/6**; entrada em `supabase/config.toml` (`verify_jwt = true`); **não implantada** |
| r12-38 migration | `packages/coelo_database/migrations/20260917180000_meal_plan_images_r2_v1.sql` (spec 063: `storage_provider` em `meal_plan_image_assets`, gatilho com chave R2 canônica, bilhetes, RPCs v2 prepare/authorize_finalize/finalize (service_role)/read_descriptor, claim/complete cleanup e delete_unreceipted com condição por provedor; v1 intactas); aplicada 2× no espelho |
| r12-38 pgTAP | `packages/coelo_database/supabase/tests/meal_plan_images_r2_v1_test.sql` → **26/26** |
| r12-38 Edge | `functions/meal-plan-media` (deno **7/7**) e ramo R2 em `meal-plan-image-cleanup` (worker 3/3, `deno check` ok); **não implantadas** |
| r12-38 FE | `SupabaseMealPlanImageRepository` pelo gateway (testes 9/9), `imageSelectionEnabled` nas rotas produtivas, prévia da imagem vinculada no wizard; suítes de Cardápios verdes exceto 5 goldens do diretório (`meal_plan_pages_golden_test`) que já falham em `dev` 681f0f667 pela deriva do cabeçalho (E4; não regravados aqui) |

## Aplicação em produção — BLOQUEADA (ambiente/permissão)

`supabase db query --linked --workdir packages/coelo_database -f <migration>` foi
**negado pelo classificador de permissões do executor** ("Production Deploy"),
mesma classe de bloqueio da R14 Sessão 8. Nenhum SQL de escrita chegou à
produção; a negativa não foi contornada. Rito pronto, nesta ordem (na worktree,
com `packages/coelo_database/supabase/.temp` do link):

1. novo dump prévio (`supabase db dump --linked --workdir packages/coelo_database -f Coelo-backups/schema-producao-<data>-lote77-before.sql`), conferir SHA-256;
2. `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260917160000_child_safety_person_search_v1.sql`
3. `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260917170000_child_safety_person_without_account_v1.sql`
3b. `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260917180000_meal_plan_images_r2_v1.sql`
4. `supabase migration repair --status applied 20260917160000 20260917170000 20260917180000 --linked --workdir packages/coelo_database`
5. `supabase migration list --linked --workdir packages/coelo_database` (ledger) e lote **78** (o 77 ficou com a C1; renumerado pela coordenadora) (próximo livre; 75 = Bloco B OQ-047, 76 = reservado pelo C1) em `ordem-de-aplicacao-producao.txt`;
6. `supabase functions deploy child-safety-media --project-ref evvbomzejfijozbtgvpt`, `supabase functions deploy meal-plan-media --project-ref evvbomzejfijozbtgvpt` e `supabase functions deploy meal-plan-image-cleanup --project-ref evvbomzejfijozbtgvpt` (CORS lê `CHILD_SAFETY_MEDIA_ALLOWED_ORIGINS`/`MEAL_PLAN_MEDIA_ALLOWED_ORIGINS` ou, na ausência, `COELO_ALLOWED_ORIGINS`, já com `127.0.0.1:3014–3024`; R2 por `COELO_R2_*` já existentes).

Sem a aplicação/deploy, `owner.r12-38` também fica bloqueado por ambiente/permissão
(prova de upload/reload/escopo em `meal-plans.create/edit/publish/model-edit`).

Sem a aplicação, as provas de rota real de `owner.r12-17` e `owner.r12-18`
(sessão `qa-r06-acessos`, massa `QA R15` do Bloco B) ficam bloqueadas por
**ambiente/permissão**; nenhum estado do inventário foi alterado.

## Decisões de contrato registradas (spec 061/062)

- CPF nunca em claro: só HMAC (`person_identity_hmac_v1`) + últimos 4. Por isso
  CPF parcial (6–10 dígitos) não encontra por CPF; o número completo encontra.
- Pessoa sem conta = `authorized_people.person_id null`; dedupe pelo índice
  único já existente `(institution_id, document_fingerprint)`; CPF de pessoa
  com conta → `PERSON_HAS_ACCOUNT` (usar a busca B5).
- Documento obrigatório (`ready`) para a autorização da pessoa sem conta.

## Aplicação em produção (coordenadora, 17/09/2026 — lote 78)

Autorização nominal do Owner em 17/09 (sessão coordenadora). Executado a partir de `dev`
(`ecf08e4f2`), cujos três arquivos de migration e as três Edges são idênticos a `r15/bloco-c2`:

- dump prévio `Coelo-backups/schema-producao-20260917-lote78-before.sql` — SHA-256
  `933d7289c599c340fe25b88d749b7b3ce129f3579243ed3c9856c11a719e86ce`;
- `supabase db query --linked --workdir packages/coelo_database -f migrations/<arquivo>` na ordem
  `20260917160000`, `20260917170000`, `20260917180000` (sem erro);
- `supabase migration repair --status applied 20260917160000 20260917170000 20260917180000 --linked`
  → `Migration history repaired`; `migration list --linked` mostra as três como `local = remote`;
- funções confirmadas em produção por `pg_proc`: `public.superadmin_person_search_v1`,
  `public.child_safety_register_person_without_account_v1`, `public.meal_plan_image_read_descriptor_v2`,
  `public.meal_plan_image_download_descriptor` e as auxiliares em `app_private`;
- Edge Functions implantadas (`supabase functions deploy … --project-ref evvbomzejfijozbtgvpt`), todas
  `ACTIVE`, `verify_jwt=true`, versão 1: `child-safety-media` (`6ea53119…`), `meal-plan-media`
  (`973d9595…`), `meal-plan-image-cleanup` (`e42122c1…`).

Estados por `action_id` e Owner items **não** mudam por esta aplicação: r12-17/18/38 seguem
`open` até a prova E2E na rota real pela C2.
