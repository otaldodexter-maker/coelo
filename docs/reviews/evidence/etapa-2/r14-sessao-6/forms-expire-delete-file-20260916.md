---
source: "Sessão 6 da R14 (Opus 5), 16/09/2026; briefing comum R14; ADR 0031; ADR 0041"
status: evidence
generated_at: 2026-09-16
---

# Formulários › Arquivos › Expirar (`forms.expire-file`) e › Excluir (`forms.delete-file`) — 16/09/2026

Ambiente: produção Supabase (`evvbomzejfijozbtgvpt`); build
`flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true` da worktree `r14/formularios-chat` (base `dbe518101`),
servido por `serve.py` em `127.0.0.1:3017`; Chrome CDP `9417` (SwiftShader, perfil
`%TEMP%\coelo-r14-formularios-chrome`); sessão `qa-r06-formularios@coelo.me` (Owner de plataforma).
Negativas por `packages/coelo_database/scripts/r13-rpc-proof.mjs` (PostgREST, mesma identidade, sem chave
de serviço). Capturas em `capturas/forms-files-*.png`.

## Dependência da migration `20260915203000_forms_question_media_expire_audit_v1` (BE)

A rota de expiração é o worker (Edge Function `form-media`, ações `expire`/`cleanup`, disparadas pelo
`pg_cron` `coelo-form-media-r2-cleanup` a cada 5 min com bearer do Vault): não existe botão de "expirar" na
tela produtiva — o card com "Expirar acesso"/"Excluir arquivo" em `/forms/:id/files` é fixture de
desenvolvimento (`FormsFilesDevelopmentStore`, "Esta demonstração altera apenas a fixture local"). A prova
produtiva de `forms.expire-file` é, portanto: ticket vencido → worker real marca o asset `deleted`,
enfileira a limpeza R2, solta o vínculo (trigger terminal) **e registra `forms.media.expire` na auditoria**.
O gate da ação exige "registrar ciclo de expiração"; a auditoria só existe com a migration. Ela é uma
correção forward-only já versionada (`0481384f5`) dentro do escopo de Formulários do MVP (ADR 0031) e foi
aplicada pelo rito do briefing:

1. Espelho próprio `Coelo-backups/mirror-r14-formularios` (`coelo_mirror_r14_formularios`, portas 616xx),
   restaurado do dump de schema de hoje (`schema-producao-20260916-r14-coord-before.sql`, SHA-256
   `f1f677ca…`). O dump é schema-only: para o pgTAP foram copiados do espelho `mirror-r14` os catálogos
   `platform_roles`, `platform_permissions`, `platform_role_permissions`, `global_type_catalogs` e
   `access_profile_template_*`, mais a pessoa de serviço `c0e10000-…0001` (seed da migration
   `20260911130100`). Drift de ambiente do espelho: os *default privileges* do Postgres local concedem
   `EXECUTE` a `authenticated` em funções novas; alinhado ao dump por `REVOKE` explícito em
   `form_media_finalize_question_r2_v1` (produção já não tem esse grant, conforme o dump).
2. Candidato aplicado no espelho e pgTAP verde: `forms_question_media_r2_v1_test` **34/34**
   (o teste 34, "expire registra o ciclo autoritativo no diário de auditoria", foi acrescentado em
   `0481384f5` sem atualizar `plan(33)` — corrigido para `plan(34)` nesta sessão; saída em
   `pgtap-forms_question_media_r2_v1-mirror-20260916.txt`), `forms_question_media_terminal_unbind_v1_test`
   **7/7**, `forms_question_media_retry_delete_v1_test` **9/9**. `media_expire_dispatch_v1_test` 4/6: os dois
   `not ok` só conferem `cron.job` (dado, ausente do dump schema-only) — não é a migration.
3. Dump prévio de produção fora do Git:
   `Coelo-backups/schema-producao-20260916-r14-s6-forms-expire-audit-before.sql` (SHA-256
   `f1f677ca9964ef87282b4647e8aa26e52a8237a5e6c9b8f4f8d699a765157b51`, idêntico ao da coordenação —
   nenhuma mudança de schema entre 11:26 e 12:15). A migration só substitui uma função (sem mutação de
   dados), então não houve dump `--data-only`.
4. `supabase db push --linked --dry-run` listou **somente** `20260915203000_forms_question_media_expire_audit_v1.sql`
   (as 15 `20260825*` + `20260910000000` do espelho CLI, ausentes do ledger remoto, foram movidas
   temporariamente para fora do espelho CLI e restauradas depois; 114 versões remotas sem arquivo local
   receberam placeholders vazios temporários, removidos ao fim). Push sem `--dry-run` → "Applying migration
   20260915203000…" → `Finished supabase db push`.
5. `supabase migration list --linked` mostra `20260915203000 | 20260915203000` (ledger 304).
   Lote 73 registrado em `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`.

## Rota real — BLOQUEADA (ambiente), 16/09 12:30–14:20 BRT

A partir de ~12:30 BRT o PostgREST de produção passou a responder `504 PGRST003 "Timed out acquiring
connection from connection pool"` a toda chamada (inclusive `superadmin_forms_context` anônima) e depois a
pendurar >40 s. Diagnóstico só-leitura por `supabase db query` em `pg_stat_activity` (ADR 0041 D1): as 10
conexões do pool `authenticator` ficaram continuamente ocupadas (`xact_start` a milissegundos de `now()`,
sem query longa) por RPCs de **outras sessões** — 6× `…(p_request_id, p_authorization_id, p_expected_version…)`
(`child_safety_change_lifecycle`), 3× `…(p_request_id, p_post_id, p_expected_version, p_reason…)` (Agora
remove/purge) e 1× `…(p_request_id, p_publication_id, …)` (Momentos/Acontece), várias em
`idle in transaction (aborted)`, isto é, chamadas que falham e são reemitidas em laço apertado. A situação
persistiu por ~110 min (sondagem a cada 20 s até 14:20) e não depende do código de Formulários nem desta
sessão (a página do Chrome desta sessão estava sem tráfego, conferido por `cdp_net`).

Estado da rota real nesta sessão:

- login `qa-r06-formularios` OK em `127.0.0.1:3017` (sessão Owner de plataforma, contexto QA R04 Cuidado);
- `/forms/new`: título "R14 S6 Formulário QA", contexto, pergunta A (texto curto), seção renomeada por diálogo
  para "Seção R14 S6 renomeada", pergunta B (única escolha) com opções Alfa/Beta/Gama digitadas
  (capturas `forms-editor-parcial-01/02`) — **sem persistência**: o autosave ficou em "Não foi possível
  concluir a ação" pelo 504 e "Salvar rascunho" não foi acionado. Nada disto certifica `forms.create`.
- `forms.expire-file`/`forms.delete-file`: nenhuma prova de rota real; permanecem `pending-verification`
  (FE) / `local-green` → o BE ganha a auditoria em produção (lote 73) mas **não é promovido** sem a prova de
  worker/rota, reload e negativa.

Roteiro para retomar (quando o pool normalizar): (1) salvar o rascunho, reload, conferir seção/posições;
(2) "Imagens da pergunta" → seletor real (`upload` no `batch.dart` do scratchpad: intercept + `DOM.setFileInputFiles`,
PNG 64×64 `r14s6-1.png`) → "Excluir imagem 1" → reload sem a imagem → `superadmin_form_media_delete_v2`
com asset inexistente/…0099 → 404 `FORM_MEDIA_NOT_FOUND`; (3) para expirar: novo upload com o PUT R2
bloqueado (`block` em `*r2.cloudflarestorage.com*`) → asset `pending` + "Imagem N não confirmada" após
reload → aguardar 30 min (ticket) + cron 5 min → reload sem a imagem, `superadmin_form_media_resolve_v2`
→ 404, e conferir `forms.media.expire` via leitura autorizada (D1) em `audit.audit_logs`.
