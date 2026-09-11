---
fonte: coordenacao R04 (E2-R04-20260911), execucao das decisoes do Owner de 11/09/2026
status: aplicado em producao
gerado_em: 2026-09-11
---

# Lotes 25 a 27 aplicados em producao apos as respostas do Owner

Projeto Supabase `coelo` (ref `evvbomzejfijozbtgvpt`). Dump por lote em
`C:/Users/adrie/Documents/Coelo-backups/schema-producao-20260911-lote2{5,6,7}.sql`.
Ledger `supabase_migrations.schema_migrations` atualizado a cada lote. Ordem
real em `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`.

| Lote | Pacote | Decisao | pgTAP local (espelho `supabase_db_coelo_baseline`) |
| --- | --- | --- | --- |
| 25 | `20260910171600_institution_role_system_templates_v1` | P31 A | 7/7 |
| 25 | `20260910171800_child_safety_platform_decision_v1` | P32 B | 25/25 + 4/4 (enum cast fix) |
| 26 | `20260910230023_notice_worker_dispatch_v1` | P30 A | 5/5 |
| 27 | `20260910230024_qa_r03_synthetic_institution_memberships_v1` | P35 "A agora" | 2/2 |

## Lote 26, worker de publicacao de notices (P30)

- Segredo `COELO_NOTICE_WORKER_SECRET` gerado localmente (32 bytes aleatorios)
  e gravado com `supabase secrets set --env-file` (arquivo temporario apagado).
  Copia unica fora do Git em `C:/Users/adrie/Documents/Coelo-backups/notice-worker-secret.env`.
- Vault: `notices_worker_url` e `notices_worker_secret` criados com
  `vault.create_secret`. O valor nunca entrou em chat, commit, log ou JSON.
- Funcao `app_private.notice_dispatch_publication_worker()` (security definer,
  `search_path=''`, revoke de `public/anon/authenticated`) e cron
  `coelo-notices-worker-dispatch` a cada minuto, no padrao de
  `form_dispatch_operations_worker`.
- Edge Function `notice-publication-worker` implantada (`ACTIVE`).
- Prova: `cron.job_run_details` `succeeded` as 13:41 UTC; `net._http_response`
  com `200` e corpo `{"processed":true,"job_id":"8a52c526-...","items":0}`:
  o job pendente de publicacao foi consumido pelo worker real.
- Achado colateral: no mesmo minuto houve uma resposta `404 Requested function
  was not found` de outro dispatch (provavelmente `forms_worker_url` do Vault
  apontando para um nome de funcao nao implantado; `form-operations` esta
  ACTIVE). Registrado como pendencia de Back-end, nao corrigido nesta rodada.

## Lote 27, membership do usuario de teste (P35)

A pessoa de servico do usuario interno `qa-r03@coelo.me` (ponte de ator
220400) recebeu membership `owner/active/institution` em `qa-r04-chat`,
`qa-r04-cuidado-sintetico` e `qa-r04-escola`. Resultado conferido em producao
apos a aplicacao. A regra de produto "Superadmin ve tudo no Principal" (P35
"B agora") e o perfil/usuario **Coelo** ficam como pendencias de Front-end +
Back-end para a proxima rodada.

## Goldens regravados com aprovacao (P26 e G-FORM)

- `error_409_light.png` e `error_409_dark.png` criados a partir das imagens
  candidatas aprovadas (bytes identicos aos de
  `docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/`); o `skip` do
  teste foi removido; suite 10/10.
- Editor de formularios: `forms_editor_light_1440`, `forms_editor_catalog_light_1440`,
  `forms_editor_catalog_groups_light_1440`, `forms_editor_date_range_light_1440`
  regravados (`forms_editor_preview_light_1440` ja coincidia). A variante
  `forms_editor_dark_1440` diverge 10,82% pelo mesmo deslocamento vertical e
  **nao** estava na lista aprovada: mantida como estava e enviada ao Owner como
  P38. Ate a resposta, esse teste falha (1 de 5) por decisao, nao por regressao.
