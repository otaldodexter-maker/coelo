---
title: "R16 — execução paralela: duas sessões executoras (FORMS, AGORA) e uma coordenadora"
source: "Owner em 2026-09-17 (ADR 0043, ADR 0044, Foco da R16; meta FE 199/199, BE 186/186, E2E 186/186); R16-prompts.md (Prompts 0, 1 e 2); R16-pendencias.md; R15-execucao-paralela.md (modelo histórico); review-scope.md (retomada entre worktrees, sessão QA D7, rota real 17/09)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — execução paralela

A fila continua sendo só `R16-pendencias.md` (seção "Foco da R16"). Este arquivo
define **quem faz o quê, onde e como as sessões se comunicam** enquanto a R16 roda
com duas sessões executoras em paralelo e a sessão principal (Claude `coelo-2c`,
pasta principal, `dev`) como coordenadora. Não é fila nem histórico; vira
`historical` quando a R16 fechar. Meta do Owner: **FE 199/199, BE 186/186, E2E
186/186** do MVP (corte de abertura 198/199, 185/186, 184/186) com prova na rota
real em produção. Owner items, resíduos H e UI/UX ficam em reserva (revisão de
telas antes da Etapa 3) e **não** são executados nem apresentados nesta rodada,
salvo pergunta do Owner. O Owner não acompanha em tempo real: decisão em aberto
vira bloqueio com causa no handoff; ninguém inventa contrato.

## Estado verificável da infraestrutura (17/09 ~20:15 BRT, base `dev` `cd5b7493e`)

- `git worktree list`: pasta principal (`dev`) e as duas worktrees desta rodada,
  ambas criadas de `dev` `cd5b7493e` **pelas próprias sessões** (lançadas pelo Owner
  com os Prompts 1 e 2 antes de a coordenadora criar qualquer worktree; a
  coordenadora conferiu por `ListAgents` + identificação nominal e **não** criou
  duplicatas — lição da R15):

| Sessão | Sessão Claude | Worktree | Branch | Servidor QA | Chrome CDP | Perfil Chrome | Espelho (Docker) | Handoff | Evidências |
|---|---|---|---|---|---|---|---|---|---|
| FORMS (Prompt 1) | `coelo-2a` | `C:\Users\adrie\Documents\Coelo.worktrees\r16-forms` | `r16/forms-location-answer` | `127.0.0.1:3014` | `9414` | `%TEMP%\coelo-r16-forms-chrome` | nenhum (sem SQL em produção) | `R16-handoff-forms.md` | `docs/reviews/evidence/etapa-2/r16-forms/` |
| AGORA (Prompt 2) | `coelo-5a` | `…\r16-agora` | `r16/agora-publish` | `127.0.0.1:3015` | `9415` | `%TEMP%\coelo-r16-agora-chrome` | `Coelo-backups/mirror-r16-agora` (`project_id coelo_mirror_r16_agora`, portas `626xx`) | `R16-handoff-agora.md` | `docs/reviews/evidence/etapa-2/r16-agora/` |
| Coordenadora (Prompt 0) | `coelo-2c` | `C:\Users\adrie\Documents\Coelo` | `dev` | — | — | — | — | este arquivo + `R16-checkpoint-<data>.md` | `docs/reviews/evidence/etapa-2/r16-coordenacao/` (se houver) |

- Sessões pares que **não** são da R16 (identificadas em 17/09 20:1x): `coelo-02`
  (pasta principal, `dev`, sem prompt) e `coelo-38` (coordenadora da R15, só
  contexto). Nenhuma delas escreve em `dev` nem nas worktrees.
- `apps/superadmin/.env.local` (URL + chave pública) e o vínculo do CLI
  (`packages/coelo_database/supabase/.temp`, ignorado pelo Git) foram copiados da
  pasta principal: para `r16-forms` pela própria sessão FORMS; para `r16-agora`
  pela coordenadora.
- Produção: projeto `evvbomzejfijozbtgvpt`; único remoto. Último lote registrado:
  **80** (`packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`);
  **próximo livre: 81 (reservado à sessão AGORA)**. Quem aplica anota no ledger e
  avisa no handoff. Edge Functions em produção: `chat-media`, `child-safety-media`
  v2, `meal-plan-media`, `meal-plan-image-cleanup`, `now-media`, `form-media` v23.
- Credenciais QA (ADR 0041 D7): `C:\Users\adrie\Documents\Coelo-backups\qa-r06-<área>.env`
  e `qa-r15-responsavel.env`. Carregar no processo (`QA_EMAIL`/`QA_PASSWORD`);
  nunca imprimir, nunca copiar para o repositório.
- Massa já verificada em produção (leituras D1 de 17/09, nos Prompts 1 e 2):
  pessoa-ator de `qa-r06-formularios` `9f944691-6a32-450d-b65d-b8bfb7dd07d9`
  elegível na ocorrência `7256b047…` do form `4555ba07…` (versão publicada antiga
  `49c338d7` sem Local; v4 só na versão de trabalho; agendamento "Diário");
  responsável `da915f98…` ativa com login `ff3682a1…`, `guardian_links` para
  `93457405…`/`14d70a25…` (turma `368a5cea`, unidade `d0c4…0002`, tenant
  `d0c40000-…0001`), `can_view`, **sem** membership (OQ-048); story de Famílias
  `d9580375…` publicada; `list_visible_now_publications` como a responsável → 403
  `42501 now_permission_denied`.

## Papéis

| Papel | Sessão | Onde | Faz | Não faz |
|---|---|---|---|---|
| FORMS | `coelo-2a` (Prompt 1) | worktree `r16-forms` | Publicar a v4 do form `4555ba07…`, agendamento "Uma vez" (desfaz o "Diário"), responder a pergunta de Local como `qa-r06-formularios` pela rota real, negativas por PostgREST, deltas `forms.location-answer` (FE verified, BE done, E2E verified-e2e), evidência, handoff FORMS | SQL em produção, espelho, migrations, MDs de estado, telas da AGORA |
| AGORA | `coelo-5a` (Prompt 2) | worktree `r16-agora` | Spec 070 (leitor do Agora reconhece o responsável por `guardian_links` + `can_view`), migration `now_guardian_reader_v1` + pgTAP no espelho, rito em produção (**lote 81**), prova de leitura pela responsável por PostgREST (+ tela se abrir), delta `agora.publish integrated → verified-e2e`, evidência, handoff AGORA | MDs de estado; `recipients` de cuidado; memberships; candidato `20260917113000` (não aplicar); telas da FORMS |
| Coordenadora | `coelo-2c` (Prompt 0) | pasta principal, `dev` | Integra por cherry-pick; atualiza `R16-pendencias.md` (cabeçalho, contadores, projeção), `current-state.md`, `ETAPA-2-estado-atual.md`, `entrega-atual.json`, gate; leituras D1 (só metadados) quando pedidas; relé de bloqueios de permissão ao Owner; checkpoint e fechamento | executar telas; editar dentro das worktrees; aplicar em produção por uma sessão sem autorização nominal do Owner; abrir R17 |

## Recursos exclusivos e limites

- Um Chrome, um servidor e um `flutter test`/`flutter build web` por sessão, sempre
  dentro da própria worktree. Portas/CDP/perfis da tabela acima; não reutilizar
  os pares da outra sessão.
- Só a sessão AGORA escreve em produção, e só pelo rito completo: espelho
  restaurado de dump novo (`r15-bloco-b-apoio/ferramentas/restaurar-espelho.sh`,
  ACL fiel + catálogo) → pgTAP verde → dump prévio de schema fora do Git
  (`Coelo-backups/schema-producao-<data>-r16-agora-before.sql`, com SHA-256) →
  `Sync-SupabaseCliMigrations.ps1 -Mode Clean` → `supabase db query --linked
  --workdir packages/coelo_database -f migrations/<arquivo>` → `supabase migration
  repair --status applied <carimbo> --linked` → `supabase migration list --linked`
  → lote 81 em `ordem-de-aplicacao-producao.txt`. Carimbo da migration
  `20260917<HHMMSS>` com HHMMSS ≥ `200000`.
- Escrita em produção **negada por permissão** a uma sessão: a sessão registra o
  comando exato no handoff e avisa a coordenadora; a coordenadora registra aqui e
  pede **autorização nominal ao Owner**; ninguém executa pela outra sessão sem
  isso (sem lavagem de permissão).
- PT409, nunca 40001, para versão defasada. Nunca `git add -A`, `git stash`,
  rebase, push em `dev` ou `--force` nas sessões.

## Fluxo git por fatia provada (as duas sessões)

1. `git add <caminhos explícitos>`.
2. `git commit -m "r16(forms|agora): <ação> — <o que foi provado>"`.
3. `git push -u origin r16/<branch>` (backup). A coordenadora integra em `dev` por
   cherry-pick e apaga a branch no fechamento.
4. Estados por `action_id` só via `node docs/reviews/apply-tracker-delta.cjs
   <delta.json>` com `certificacao{evidence,revision,environment:"producao",recordedAt}`;
   `node docs/reviews/validate-trackers.cjs` PASS antes do commit.
5. Registrar a fatia no handoff próprio (mesmo commit ou o seguinte).

## Handoffs — como as sessões conversam

- `R16-handoff-forms.md` e `R16-handoff-agora.md` nesta pasta, `lifecycle:
  current`; só a sessão dona escreve; a coordenadora lê (em `origin/r16/*`) e
  integra.
- Seções fixas: `## Reivindicações`, `## Fatias entregues` (SHA, action_ids →
  estados, evidência), `## Avisos para a outra sessão e para a coordenadora`
  (lote aplicado, funções alteradas, massa criada/alterada), `## Bloqueios`
  (causa classificada: sessão/massa/RPC/ambiente/decisão/permissão), `## Sobra`,
  `## Contadores` (`validate-trackers` após a última fatia).
- Mensagens diretas entre sessões (`SendMessage`) servem para pedidos pontuais à
  coordenadora (leitura D1, aviso de push, bloqueio de permissão); o que vale como
  registro é o handoff commitado.

## Integração pela coordenadora

Por entrega (commit publicado em `origin/r16/*`): `git fetch origin`; `git
cherry-pick <sha>` em `dev`. Conflito em `inventario-etapa-2.json` ou nos três
rastreadores: manter `dev`, reaplicar o delta JSON da sessão,
`validate-trackers`. Conflito em `ordem-de-aplicacao-producao.txt`: manter os dois
lotes. Conflito Dart: manter os dois comportamentos, `flutter analyze` + suítes das
famílias tocadas. Depois: cabeçalho/contadores/projeção de `R16-pendencias.md`,
`current-state.md`, `ETAPA-2-estado-atual.md`, `entrega-atual.json`
(`generate-delivery-report.py`; worktrees `r16/*` protegidas; branches `r16/*` como
`patch-equivalent` com `successor`; `formalActions` para as ações certificadas),
`validate-trackers.cjs`, `Test-CoeloKnowledge.ps1`, `git diff --check`, commit
`r16(coord): …`, `git push origin dev`, `python docs/reviews/delivery_gate.py
docs/reviews/entrega-atual.json` (PASS).

## Registro de integrações e leituras D1

| Hora (BRT) | Evento | Detalhe |
|---|---|---|
| 20:1x | Identificação das sessões | `coelo-2a` = FORMS (dona de `r16-forms`); `coelo-5a` = AGORA (dona de `r16-agora`); `coelo-02`/`coelo-38` fora da R16 |
| 20:2x | `.env.local` + `.temp` copiados para `r16-agora` pela coordenadora | FORMS copiou os seus |

## Cota e fechamento

- A ~5% de cota ou bloqueio sem rota: commit/push verdes, handoff atualizado,
  Chrome/servidor/espelho encerrados (`supabase stop --project-id
  coelo_mirror_r16_agora`), relatório ≤ 20 linhas.
- Fim da R16 (coordenadora): `R16-checkpoint-<data>.md` (contadores antes→depois,
  action_ids certificados, lotes, bloqueios por causa); skills `coelo-supabase`,
  `coelo-flutter-review`, `review-scope.md` e `coelo-knowledge` com os percentuais
  finais; bundle em `Coelo-backups/r16-fechamento`; branches `r16/*` remotas e
  locais apagadas e worktrees removidas com árvore limpa (só `dev`); gate PASS;
  stash vazio; este arquivo passa a `historical`.
