---
title: "R15 — execução paralela: quatro sessões executoras (A, B, C1, C2) e uma coordenadora"
source: "Owner em 2026-09-16/17 (ADR 0042 E5: quatro prompts; Bloco C dividido em C1/C2; meta E2E 186/186); R15-prompts.md; R15-pendencias.md; R14-execucao-paralela.md (modelo histórico); review-scope.md (retomada entre worktrees, sessão QA D7)"
status: "historical"
lifecycle: "historical"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — execução paralela

> Histórico: a R15 fechou em 17/09/2026 (ADR 0043). Worktrees e branches `r15-*` foram removidas; use este arquivo só como modelo.

A fila continua sendo só `R15-pendencias.md`. Este arquivo define **quem faz o
quê, onde e como as sessões se comunicam** enquanto a R15 roda com quatro
sessões executoras em paralelo e a sessão principal (Claude, pasta principal,
`dev`) como coordenadora. Não é fila nem histórico; vira `historical` quando a
R15 fechar. Meta do Owner: **E2E 186/186** (corte de abertura 162/186) com
prova na rota real em produção, aplicando as decisões já tomadas (ADR 0041
A–D, ADR 0042 E1–E9). Nada é pedido ao Owner durante a execução; ele não
acompanha em tempo real (17/09).

## Estado verificável da infraestrutura (17/09, base `dev` `57162cee4`)

- `git worktree list`: pasta principal (`dev`), seis worktrees `r14-*`
  (protegidas, integradas por cherry-pick; disposição no fechamento da R15) e
  as quatro worktrees desta rodada, todas criadas de `dev` `57162cee4`:

| Sessão | Worktree | Branch | Servidor QA | Chrome CDP | Perfil Chrome | Espelho (Docker) | Handoff | Evidências |
|---|---|---|---|---|---|---|---|---|
| A | `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-a` | `r15/bloco-a` | `127.0.0.1:3014` | `9414` | `%TEMP%\coelo-r15-a-chrome` | nenhum (sem SQL em produção) | `R15-handoff-bloco-a.md` | `docs/reviews/evidence/etapa-2/r15-bloco-a/` |
| B | `…\r15-bloco-b` | `r15/bloco-b` | `127.0.0.1:3015` | `9415` | `%TEMP%\coelo-r15-b-chrome` | `Coelo-backups/mirror-r15-b` (`project_id coelo_mirror_r15_b`, portas `622xx`) | `R15-handoff-bloco-b.md` | `…/r15-bloco-b/` |
| C1 | `…\r15-bloco-c1` | `r15/bloco-c1` | `127.0.0.1:3016` | `9416` | `%TEMP%\coelo-r15-c1-chrome` | `Coelo-backups/mirror-r15-c1` (`coelo_mirror_r15_c1`, portas `623xx`) | `R15-handoff-bloco-c1.md` | `…/r15-bloco-c1/` |
| C2 | `…\r15-bloco-c2` | `r15/bloco-c2` | `127.0.0.1:3017` | `9417` | `%TEMP%\coelo-r15-c2-chrome` | `Coelo-backups/mirror-r15-c2` (`coelo_mirror_r15_c2`, portas `624xx`) | `R15-handoff-bloco-c2.md` | `…/r15-bloco-c2/` |
| B′ (apoio ao B; Prompt B′ acrescentado pelo Owner em 17/09, `1d941e5d1`) | `…\r15-bloco-b-apoio` | `r15/bloco-b-apoio` | `127.0.0.1:3018` | `9418` | `%TEMP%\coelo-r15-b-apoio-chrome` | `Coelo-backups/mirror-r15-b-apoio` (`coelo_mirror_r15_b_apoio`, portas `625xx`) | `R15-apoio-bloco-b.md` (saída; pedidos `AP-<n>` vivem em `R15-handoff-bloco-b.md`) | `…/r15-bloco-b-apoio/` |

A worktree `r15-bloco-b-apoio` já existia em `1d941e5d1` quando a coordenadora
foi criá-la (aberta pela sessão do Owner que acrescentou o Prompt B′); a
coordenadora só copiou `.env.local` e o vínculo do CLI para dentro dela.
A sessão B′ não tem fila própria: atende pedidos `AP-<n>` registrados pelo
Bloco B na seção `## Pedidos de apoio` do handoff B e responde em
`R15-apoio-bloco-b.md` (passo a passo, commit para cherry-pick ou "assumo a
fatia"). Como o Owner não acompanha em tempo real em 17/09, a **coordenadora**
faz o relé: lê o handoff B, aciona a B′ com o pedido e devolve a resposta ao B.

- `apps/superadmin/.env.local` (URL + chave pública) e o vínculo do CLI
  (`packages/coelo_database/supabase/.temp`, ignorado pelo Git) foram copiados
  da pasta principal para as quatro worktrees pela coordenadora.
- Docker Desktop ligado pela coordenadora em 17/09 (ADR 0041 D8); cada espelho
  nasce de **dump novo** de schema da produção (`supabase db dump --linked
  --schema-only`), nunca do espelho de outra sessão. Espelhos `mirror-r14-*`
  ficam parados como proveniência.
- Produção: projeto `evvbomzejfijozbtgvpt` `ACTIVE_HEALTHY`; incidente do
  PostgREST encerrado (lote 74); CORS das Edge liberado para
  `127.0.0.1:3014–3024`. Último lote registrado: **74**
  (`packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`). Os
  próximos lotes são numerados na ordem em que forem aplicados (75, 76, …);
  quem aplica anota no ledger e avisa no handoff para evitar colisão.
- Credenciais QA (ADR 0041 D7): `C:\Users\adrie\Documents\Coelo-backups\qa-r06-<área>.env`
  (acessos, estrutura, formularios, operacoes, publicacoes, principal, realm) e
  `qa-r03.env`. Carregar no processo (`QA_EMAIL`/`QA_PASSWORD`); nunca
  imprimir, nunca copiar para o repositório. Massa nova leva prefixo `QA R15`
  e senha só em `Coelo-backups/qa-r15-*.env`.

## Papéis

| Papel | Sessão / modelo | Onde | Faz | Não faz |
|---|---|---|---|---|
| Sessão A | Opus (Prompt A) | worktree `r15-bloco-a` | Rota real já pronta: Perfis de acesso, Instituições, Conta, Formulários, Momentos, `errors.409`, `auth.recover/reset` (E8); deltas, evidências, linhas de Owner do próprio bloco, handoff A | SQL em produção, espelho, migrations, MDs de estado |
| Sessão B | Fable (Prompt B) | worktree `r15-bloco-b` | OQ-047 sistêmica (E1), massa E2, Segurança da criança, Assiduidade (r12-05/08, B2, B3), Medicação B8+E7, Arquivar B1, Agora remove/expire; rito de produção; handoff B | MDs de estado; telas reivindicadas por outra sessão |
| Sessão C1 | Fable (Prompt C1) | worktree `r15-bloco-c1` | E3 Chat multi-anexo (`chat.attach`, r12-52), B9 "ver como" (`principal.for-you`, `principal.profile-edit`); specs, migrations, Edge `chat-media`, rito; handoff C1 | MDs de estado; Momentos sem combinar com A |
| Sessão C2 | Fable (Prompt C2) | worktree `r15-bloco-c2` | B5 busca de pessoa (r12-17), B6 pessoa sem conta (r12-18), Cardápios imagem R2 (r12-38); specs, migrations, Edge `meal-plan-media`, rito; handoff C2 | MDs de estado; wizard de Segurança da criança além dos campos de B5/B6 sem combinar com B |
| Coordenadora | Fable (Prompt 0) | pasta principal, `dev` | Cria/lança as sessões; integra por cherry-pick; atualiza `R15-pendencias.md` (cabeçalho, contadores, projeção), `current-state.md`, `ETAPA-2-estado-atual.md`, `entrega-atual.json`, gate; executa pelo rito as escritas em produção que uma sessão não conseguir por permissão; checkpoint final | executar telas; editar dentro das worktrees; abrir R16 |

## Recursos exclusivos e limites

- Um Chrome, um servidor e um `flutter test`/`flutter build web` por sessão,
  sempre dentro da própria worktree. Portas/CDP/perfis da tabela acima; não
  reutilizar `3016–3021`/`9416–9421` das worktrees `r14-*` além dos pares
  atribuídos aqui (C1 = 3016/9416, C2 = 3017/9417 são desta rodada).
- Só B, C1 e C2 escrevem em produção, e só pelo rito completo: espelho
  restaurado de dump novo → pgTAP verde → dump prévio de schema fora do Git
  (`Coelo-backups/schema-producao-20260917-<sessão>-<fatia>-before.sql`, com
  SHA-256) → `Sync-SupabaseCliMigrations.ps1 -Mode Clean` → `supabase db query
  --linked --workdir packages/coelo_database -f <migration>` → `supabase
  migration repair --status applied <carimbo> --linked` → `supabase migration
  list --linked` → lote em `ordem-de-aplicacao-producao.txt`. Edge Functions:
  `supabase functions deploy <nome> --project-ref evvbomzejfijozbtgvpt` só
  após teste local, registrado na evidência.
- Carimbos de migration e números de spec: `git fetch origin` e conferir
  `origin/r15/*` antes de escolher; B usa carimbos `20260917 0xxxxx–11xxxx`,
  C1 `20260917 12xxxx–15xxxx`, C2 `20260917 16xxxx–19xxxx`; specs: B 055–057,
  C1 058–060, C2 061–064. A coordenadora renumera se houver colisão.
- Massa `QA R15` (E2) é criada pelo Bloco B na fatia 2 e publicada no handoff B
  (IDs, sem senha); A (`agora.publish`) e C2 (B5/B6) leem o handoff B em
  `origin/r15/bloco-b` antes de depender dela.
- Goldens: regravar só com `isolatedDiff` restrito ao cabeçalho global (E4)
  ou por mudança decidida (B2), suíte a suíte, com registro na evidência.
- PT409, nunca 40001, para versão defasada. Negativas de versão defasada por
  PostgREST em famílias ainda com `serialization_failure` só depois de o
  Bloco B aplicar a migração sistêmica (E1) e avisar no handoff.

## Fluxo git por fatia provada (as quatro sessões)

1. `git add <caminhos explícitos>` — nunca `git add -A`, nunca `git stash`.
2. `git commit -m "r15(bloco-<x>): <tela> — <o que foi provado>"`.
3. `git push -u origin r15/bloco-<x>` (backup). **Sem push em `dev`, sem
   rebase, sem `--force`**: a coordenadora integra por cherry-pick.
4. Estados por `action_id` só via `node docs/reviews/apply-tracker-delta.cjs
   <delta.json>` com `certificacao{evidence,revision,environment:"producao",recordedAt}`;
   `node docs/reviews/validate-trackers.cjs` PASS antes do commit.
5. Owner items: editar só a própria linha em `R15-pendencias.md` (IDs do
   próprio bloco; tokens exatos `done / verified / done / verified-e2e`) e rodar
   `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
6. Registrar a fatia no handoff próprio (mesmo commit ou o seguinte).

## Handoffs — como as sessões conversam

- `R15-handoff-bloco-a|b|c1|c2.md` nesta pasta, `lifecycle: current`; só a
  sessão dona escreve; a coordenadora lê e integra.
- **Antes de cada tela**: `git fetch origin` e ler os outros handoffs em
  `origin/r15/bloco-*` (`git show origin/r15/bloco-b:docs/reviews/etapa-2-operacao/next-round/R15-handoff-bloco-b.md`).
  Tela reivindicada por outra sessão não se toca.
- Seções fixas: `## Reivindicações` (tela, action_ids, hora), `## Fatias
  entregues` (SHA, action_ids → estados, Owner items, evidência), `## Avisos
  para as outras sessões e para a coordenadora` (lotes aplicados, funções
  alteradas, massa criada, colisões), `## Bloqueios` (causa classificada:
  sessão/massa/RPC/ambiente/decisão), `## Sobra` (sugestão), `## Contadores`
  (`validate-trackers` após a última fatia).
- Sem Owner em tempo real: um bloqueio de decisão é registrado com a causa e a
  sessão segue para a próxima fatia; não inventar contrato.

## Integração pela coordenadora

Por entrega (commit publicado em `origin/r15/bloco-*`): `git fetch origin`;
`git cherry-pick <sha>` em `dev`. Conflito em `inventario-etapa-2.json` ou nos
três rastreadores: manter `dev`, reaplicar o delta JSON da sessão,
`validate-trackers`. Conflito em `R15-pendencias.md`: manter as duas linhas.
Conflito Dart: manter os dois comportamentos, `flutter analyze` + suítes das
famílias tocadas. Depois: cabeçalho/contadores/projeção de `R15-pendencias.md`,
`current-state.md`, `ETAPA-2-estado-atual.md`, `entrega-atual.json`
(worktrees protegidas, branches `patch-equivalent` com `successor`,
`formalActions`), `validate-trackers.cjs`, `Test-CoeloKnowledge.ps1`, `git
diff --check`, commit, `git push origin dev`, `python
docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json` (PASS).

## Cota e fechamento

- A ~5% de cota ou bloqueio sem rota: commit/push verdes, handoff atualizado,
  Chrome/servidor/espelho encerrados (`supabase stop --project-id <id>`),
  relatório ≤ 25 linhas.
- Fim da R15 (coordenadora): `R15-checkpoint-<data>.md` com contadores
  antes→depois, action_ids certificados, bloqueios por causa, gate PASS, stash
  vazio, worktrees listadas com disposição; este arquivo passa a `historical`.
