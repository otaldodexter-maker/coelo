---
source: "Sessão 8 da R14 (Opus 5, backend), 16/09/2026; ADR 0041 D4; owner.r12-13/15/16; r14-sessao-3/child-safety-lifecycle-504-diagnostico-20260915.md; r14-sessao-1/child-safety-child-20260915.md"
status: evidence
lifecycle: current
generated_at: 2026-09-16
---

# Segurança da criança › 504 de `child_safety_change_lifecycle` — diagnóstico, causa observada e correção (16/09/2026)

Ambiente: produção Supabase `evvbomzejfijozbtgvpt` (leituras autorizadas pela ADR 0041 D1/D4, sem
mutação de dados de negócio); sessão QA `qa-r06-acessos@coelo.me` por PostgREST
(`scratchpad/rpc-timed.mjs`, mesma base do `r13-rpc-proof.mjs` com medição de tempo); metadados por
`supabase db query --linked` / `supabase inspect db` (somente leitura). Espelho próprio
`coelo_mirror_r14_seguranca` (portas 617xx) restaurado do dump de schema de hoje
(`schema-producao-20260916-r14-coord-before.sql`, SHA-256 `f1f677ca…`, 0 erros) + catálogo de
referência (`mirror-r14/supabase/seed.sql`) + permissões `child_safety.*` do Owner
(trecho da migration `20260910170500`). Massa sintética criada SÓ no espelho.

## 1. Reprodução em produção (PostgREST, sem mutação)

Autorizações reais lidas por `superadmin_child_safety_get(d0c40000…0003)`: `34d29829` e `7fcb6761`,
ambas `approved`/`suspended`, `version 4`.

| Chamada `child_safety_change_lifecycle` | HTTP | Tempo | Leitura |
|---|---|---|---|
| `p_lifecycle_status='bogus'` (guarda inicial) | 403 `42501 child safety lifecycle unavailable` | 399 ms | `current_person_id`, `has_mfa_aal2` e guarda são rápidos |
| autorização inexistente `…0000`, versão 99 | 500 `P0002 child safety record unavailable` | 201 ms | advisory lock, recibo e `select … for update` sem linha são rápidos |
| `34d29829`, versão 99 (defasada) | **504 `upstream request timeout`** | **125.071 ms** | reproduz o 504 da Sessão 1 |
| `7fcb6761`, versão 99 (defasada) | **504** | **125.065 ms** | não depende da linha |

Ou seja: o 504 ocorre exatamente no caminho **versão defasada → `raise serialization_failure`
(SQLSTATE 40001)**. A Sessão 1 também usou `expected_version 99`.

## 2. Causa observada (não inferida)

Durante a chamada em voo, `pg_stat_activity`/`pg_locks` em produção (leitura, D1):

- `supabase inspect db blocking` → **vazio** (ninguém espera lock); `long-running-queries` → vazio.
- `pg_stat_activity`: 6–9 backends `application_name = "PostgREST 14.5"`, `state = active`, todos com
  `xact_start`/`query_start` **dentro dos últimos 50 ms** da leitura, statement
  `… LATERAL (SELECT "public"."child_safety_change_lifecycle"(…))` (e, de outra sessão,
  `withdraw_happens_post`), `wait_event` nulo (um deles em `Lock: advisory`, i.e. duas reexecuções
  concorrentes do mesmo `request_id`), sem `backend_xid`.
- `pg_current_xact_id()`: 53.936.810 às 15:13:02 → 53.948.302 às 15:13:26 (**~480 transações/s**) →
  54.514.810 às 15:34:05 (**~578.000 transações em 21 min**), com **nenhuma chamada minha em voo**.
- `pg_stat_statements` (`inspect db outliers`) não contém a RPC: a instrução nunca conclui.

Conclusão: o PostgREST 14.5 (versão de produção) trata SQLSTATE `40001` como falha de serialização
transitória e **reexecuta a transação sem limite** (comportamento do `hasql-transaction`). Cada
reexecução leva ~2 ms, o gateway devolve 504 aos 125 s e o laço **continua no banco depois do 504**.
Não há lock esperando, trigger (`coelo_profile_follow_sync`, `care_notify`), cadeia de auditoria,
índice ausente nem laço na função: a versão defasada é verificada antes do `update`.

Reprodução controlada no espelho (mesma função, PostgREST **v14.5** em contêiner auxiliar apontado ao
espelho): versão defasada → cliente aborta aos 15 s; `pg_current_xact_id()` 11.272 → 20.156 em 15 s e
23.718 5 s depois (laço continua); com o PostgREST **v16.2** do `supabase start` a mesma chamada responde
`500 40001` em 242 ms sem laço. Logo a causa é a combinação `40001` × PostgREST 14.5.

## 3. Correção forward-only (`20260916152000_child_safety_lifecycle_timeout_fix_v1.sql`)

As quatro RPCs de mutação da família (`child_safety_change_lifecycle`, `child_safety_decide_authorization`,
`child_safety_edit_pending_authorization`, `child_safety_acknowledge_alert`) passam a sinalizar versão
defasada com `raise exception using errcode='PT409', message='stale child safety version',
detail='CHILD_SAFETY_STALE_VERSION'`: o PostgREST mapeia `PT409` para **HTTP 409 sem retentativa**. Os
corpos são os do dump de produção de hoje; o diff por função é **só a linha do `raise`** (assinatura,
SECURITY DEFINER, `search_path=''`, recibo idempotente, auditoria, notificações e grants preservados).
Preflight (`postgres`, funções existem), pós-verificação (`prosrc` sem `serialization_failure`),
`lock_timeout 5s`, `statement_timeout 120s`, idempotente (aplicada 2× no espelho).

FE: `supabase_child_safety_repository.dart` mapeia `PT409` para `ChildSafetyConflictException`
(junto de `23505`/`40001`); `supabase_child_safety_repository_test.dart` cobre o código
(`flutter test … 10/10`).

### Espelho (após a migration, PostgREST v14.5 auxiliar)

| Chamada | HTTP | Tempo | Efeito |
|---|---|---|---|
| versão 99 | **409 `PT409` CHILD_SAFETY_STALE_VERSION** | 44 ms | 1 transação; linha inalterada |
| versão 2, `suspended` | 200 `{version 3, lifecycle_status suspended}` | 26 ms | `status=suspended`, `suspension_reason` gravado |
| replay do mesmo `request_id` | 200 (recibo idêntico) | 4 ms | sem nova mutação |
| versão 99 pelo PostgREST v16.2 | 409 `PT409` | 86 ms | idem |

pgTAP no espelho: `child_safety_lifecycle_timeout_fix_v1_test.sql` **15/15** (estrutura sem 40001 /
com PT409, grants, três negativas PT409 sem mutação, suspensão com versão correta, replay idempotente,
auditoria única); `child_safety_platform_decision_v1_test.sql` 22/25 (asserção da versão obsoleta
ajustada para `PT409`; os 3 restantes são drift do espelho local — `anon` recebe execute por
`ALTER DEFAULT PRIVILEGES` local, ausente em produção — e já falhavam antes da migration). As demais
suítes da família param na fixture (`follow_links` FK da pessoa técnica Coelo; bucket de evidência;
default privileges), drift já registrado pela Sessão 3, não relacionado à correção.

## 4. Aplicação em produção — BLOQUEADA (ambiente/permissão)

- Dump prévio do schema: `C:\Users\adrie\Documents\Coelo-backups\schema-producao-20260916-s8-child-safety-before.sql`
  (4.201.759 bytes, SHA-256 `D0B36E45C51DBE558EE8EB8506CF06E4FCBD3B948329F152FF8002145581B530`);
  função `child_safety_change_lifecycle` idêntica ao dump da coordenação.
- `supabase db push --dry-run` **inviável**: o ledger remoto tem 51 versões (ex.: `20260729154458`,
  `20260811180804`…) sem arquivo em `migrations/`, `migrations-historico/` ou no espelho CLI da pasta
  principal; a CLI recusa com `LegacyDbPushMissingLocalError` e sugere `repair --status reverted`
  (não executado: reescreveria o ledger). O mesmo limite explica por que a Sessão E aplicou o lote 71 por
  `db query -f` + `migration repair --status applied`.
- `supabase db query --linked -f <migration>` foi **negado duas vezes pelo classificador de permissões
  do executor** (razões "Blind Apply" e "Blocked by classifier"), mesmo após exibir o diff completo.
  Nenhum SQL de escrita chegou à produção. Causa classificada: **ambiente** (permissão do executor),
  não decisão nem massa.
- Comando pronto para o Owner/coordenadora (na worktree, com `.temp` do link copiado):
  `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260916152000_child_safety_lifecycle_timeout_fix_v1.sql`
  e depois `supabase migration repair --status applied 20260916152000 --linked --workdir packages/coelo_database`,
  `supabase migration list --linked …` e o lote em `ordem-de-aplicacao-producao.txt`.

## 5. Efeito colateral em produção que exige ação (aviso)

Os laços de retentativa **continuam ativos** em produção (medido às 15:34 UTC: ~460 tx/s, 6 backends
PostgREST ativos em `child_safety_change_lifecycle` e `withdraw_happens_post`), consumindo CPU e XIDs.
Aplicar a migration encerra os laços de `child_safety_change_lifecycle` (a próxima reexecução recebe
PT409). `withdraw_happens_post` (Agora) tem o mesmo padrão `raise serialization_failure` e pertence a
outra fatia; até a correção dela, só um restart da API (painel Supabase) ou `pg_terminate_backend`
dos pids PostgREST em laço encerra esses. **Há 173 `raise serialization_failure` em produção
(221 nas migrations)**: qualquer negativa de versão defasada por PostgREST tem o mesmo defeito
sistêmico — registrado como OQ-047 para decisão do Owner.

## Separação FE / BE / E2E

- FE: mapeamento `PT409` → conflito (local-green, teste 10/10). Nenhuma tela provada nesta fatia.
- BE: causa observada em produção + espelho; migration e pgTAP 15/15 no espelho; **não aplicada em
  produção** (bloqueio de ambiente). Estados do inventário inalterados.
- E2E: `child-safety.edit`/`suspend` e `owner.r12-13/15/16` seguem pendentes até a aplicação; a prova
  pela tela (rotas `/safety/...`) fica preparada para logo após o Owner aplicar.
