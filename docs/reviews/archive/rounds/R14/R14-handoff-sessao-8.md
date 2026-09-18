---
title: "R14 — handoff da Sessão 8 (Segurança da criança + Assiduidade, backend)"
source: "Sessão 8 da R14 (Opus 5), 16/09/2026; briefing comum da coordenadora; ADR 0041 D3/D4; R14-pendencias.md; docs/reviews/evidence/etapa-2/r14-sessao-8/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 8

Worktree `Coelo.worktrees\r14-seguranca-assiduidade`, branch `r14/seguranca-assiduidade` (base `dev`
`dbe518101`). Porta 3019 / CDP 9419 reservados, **não usados** (nenhuma tela executada: as duas
fatias pararam antes da prova de tela por bloqueio de aplicação em produção). Espelho próprio
`coelo_mirror_r14_seguranca` (portas 617xx), restaurado do dump de schema de 16/09.

## Reivindicações

- Nenhuma tela reivindicada no momento. As telas `/safety/...` (child-safety.edit/suspend) e
  `/attendance/new` (contexto Atividade) ficam livres; quem retomar deve aplicar antes as duas
  migrations abaixo em produção.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| `cbd1c32ee` | Segurança da criança — 504 de `child_safety_change_lifecycle` (ADR 0041 D4) | nenhum estado alterado (`child-safety.edit` local-green/done/pending-verification; `child-safety.suspend` local-green/done/blocked-backend). Causa observada em produção e reproduzida no espelho; migration `20260916152000_child_safety_lifecycle_timeout_fix_v1.sql` (4 RPCs: 40001 → PT409) + pgTAP `child_safety_lifecycle_timeout_fix_v1_test.sql` 15/15; FE mapeia `PT409` → conflito (teste 10/10). | `owner.r12-13/15/16` inalterados (linhas não editadas) | `r14-sessao-8/child-safety-lifecycle-504-20260916.md`; OQ-047 |
| `bf6066655` | Assiduidade — escopo de `activities` em `superadmin_attendance_context_options` (ADR 0041 D3) | nenhum estado alterado (`attendance.create` segue verified/done/verified-e2e pelo contexto Turma). Migration `20260916154500_attendance_context_options_activity_scope_v1.sql` + pgTAP `attendance_context_options_activity_scope_v1_test.sql` 11/11 (3/11 falham com o corpo de produção). | `owner.r12-05` inalterado; `owner.r12-08` confere: linha diz "bloqueado por decisão (D6)" — não alterada | `r14-sessao-8/attendance-context-activity-scope-20260916.md` |

Nenhum delta JSON aplicado (nenhum estado por `action_id` mudou); `validate-trackers` PASS com os
contadores do corte.

## Avisos para as outras sessões e para a coordenadora

1. **Incidente ativo em produção (prioridade):** o PostgREST 14.5 de produção **reexecuta sem limite**
   qualquer RPC que termine com SQLSTATE `40001` (`raise serialization_failure`). Medido em 16/09:
   ~460–500 transações/s, 6–9 backends `PostgREST 14.5` ativos em `child_safety_change_lifecycle` e
   `withdraw_happens_post` (Agora), laço continua **depois** do 504 (578 mil transações em 21 min sem
   chamada em voo). Isso é o "504 de Segurança infantil" e afeta **toda** negativa de versão defasada
   (173 `raise serialization_failure` em produção). Ações: (a) aplicar `20260916152000` (encerra os
   laços de child_safety: a próxima reexecução recebe PT409); (b) para `withdraw_happens_post`, corrigir
   a função do Agora com o mesmo padrão e/ou reiniciar a API no painel Supabase; (c) decidir OQ-047
   (padronizar SQLSTATE não retentável, ex. `PT409`, em todas as famílias + mapeamento FE). **Não
   provar negativas de versão defasada por PostgREST em produção até isso** — cada tentativa abre um
   laço novo que sobrevive ao 504.
2. **Aplicação em produção bloqueada nesta sessão (ambiente):** `supabase db push --dry-run` falha com
   `LegacyDbPushMissingLocalError` porque o ledger remoto tem 51 versões sem arquivo em `migrations/`,
   `migrations-historico/` ou no espelho CLI da pasta principal (ex.: `20260729154458`,
   `20260811180804`, `20260820114916`…); `supabase db query --linked -f` foi negado pelo classificador de
   permissões do executor. Comandos prontos (na worktree, com `packages/coelo_database/supabase/.temp`
   copiado da pasta principal):
   `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260916152000_child_safety_lifecycle_timeout_fix_v1.sql`
   `supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260916154500_attendance_context_options_activity_scope_v1.sql`
   e depois `supabase migration repair --status applied 20260916152000 20260916154500 --linked --workdir packages/coelo_database`,
   `supabase migration list --linked …` e o lote em `ordem-de-aplicacao-producao.txt` (hoje anotadas
   como PENDENTE). Dumps prévios fora do Git: `schema-producao-20260916-s8-child-safety-before.sql`
   (SHA-256 `D0B36E45…`).
3. **Ledger remoto:** `20260915203000_forms_question_media_expire_audit_v1` **aparece como aplicada** no
   `supabase migration list --linked` de 16/09 15:2x UTC, embora o lote 72 a registre como não
   aplicada. A coordenadora deve confirmar (dump/`to_regprocedure`) antes de mexer.
4. **Drift do espelho local** (restaurado só com schema): `anon` recebe execute em funções `public`
   por `ALTER DEFAULT PRIVILEGES` locais (produção não tem), pessoa técnica Coelo `c0e10000…01`
   ausente (trigger de follows), `unit_types.code='sede'` e permissões `attendance.*`/`child_safety.*`
   de plataforma ausentes do catálogo de 10/09. As suítes antigas de child_safety/attendance falham
   por isso, não pela migration; as suítes novas semeiam o que precisam.
5. Massa em produção **não** alterada (D6 respeitado; nenhuma criança/vínculo/atividade criada).
   `superadmin_child_safety_get` mostra as duas autorizações reais `34d29829`/`7fcb6761` ainda
   `approved`/`suspended`, versão 4.

## Sobra para a R15 (sugestão)

- Prova pela tela de `child-safety.edit`/`child-safety.suspend` e `owner.r12-13/15/16` (rotas
  `/safety/...`: criar/editar autorização, aprovar, suspender, reload, negativas 403/409) — logo após a
  aplicação de `20260916152000`; alvo +2 E2E, +3 Owner.
- Prova pela tela do contexto Atividade em `/attendance/new` + `owner.r12-05` após `20260916154500`,
  precedida da criação de uma atividade "R14 S8 …" vinculada à turma `368a5cea` pela tela
  (as duas atividades existentes pertencem à instituição `190dd028` em `draft`).
- OQ-047: lote forward-only por família trocando `serialization_failure` por SQLSTATE não retentável.
- `owner.r12-10` / C1: golden `child_safety_directory_light_1440.png` continua **0,34% / 4.857 px**
  (deriva do cabeçalho global); referência **não** regravada nesta sessão.

## Bloqueios

| Gate | Causa classificada | Detalhe |
|---|---|---|
| Aplicar `20260916152000` e `20260916154500` em produção | **ambiente** (permissão do executor + ledger sem arquivos locais) | `db push` recusado pela CLI; `db query -f` negado 2× pelo classificador. Migrations validadas no espelho. |
| E2E `child-safety.edit/suspend`, `owner.r12-13/15/16` | ambiente (depende da aplicação) | tela não executada |
| Contexto Atividade / `owner.r12-05` | ambiente (depende da aplicação) + massa (nenhuma atividade elegível na instituição ativa do escopo QA; criar pela tela permitido) | tela não executada |
| `owner.r12-08` | decisão (D6) | linha conferida, não alterada |

## Contadores

`node docs/reviews/validate-trackers.cjs` → PASS `{"actions":232,"families":39,"frontendCompleted":186,
"backendCompleted":168,"e2eCompleted":159,"activeE2E":186}` — inalterados (FE 186/232, BE 168/219,
E2E 159/186, Owner 21/53).
