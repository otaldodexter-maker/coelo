---
title: "R14 — execução paralela: duas sessões executoras e uma coordenadora"
source: "Owner em 2026-09-15 (artefato 89AVWHKEnq5hrvYN6SFv6M, 7 decisões); R14-pendencias.md; ADR 0038; review-scope.md (rota real 14/09)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
---

# R14 — execução paralela

A fila continua sendo só `R14-pendencias.md`. Este arquivo define **quem faz o quê,
onde e como as sessões se comunicam** enquanto a R14 roda com duas sessões
executoras em paralelo e a sessão do Codex como coordenadora. Não é fila nem
histórico; vira `historical` quando a R14 fechar.

## Estado verificável da infraestrutura

Na publicação deste protocolo, em 15/09/2026, `git worktree list` contém somente
`C:\Users\adrie\Documents\Coelo` na branch `dev`; as pastas
`Coelo.worktrees\r14-ab` e `Coelo.worktrees\r14-cd` ainda não existem. Os
caminhos e branches abaixo são reservas do plano, não prova de que as sessões
estejam abertas. Só devem ser criados quando o Owner iniciar a execução
paralela; os handoffs das sessões passam a existir nesse momento.

## Papéis

| Papel | Sessão | Onde | Faz | Não faz |
|---|---|---|---|---|
| Sessão 1 | Opus 5 (médio) | worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-ab`, branch `r14/bloco-ab` | Blocos A e B: rota real no Chrome, deltas, evidências, linhas de Owner do próprio bloco, handoff 1 | SQL em produção, espelho, migrations, MDs de estado (current-state, checkpoints, cabeçalho da fila) |
| Sessão 2 | Luna (alto) | worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-cd`, branch `r14/bloco-cd` | Blocos C e D: rito ADR 0038 no espelho `mirror-r14`, SQL em produção, FE, rota real, deltas, evidências, linhas de Owner do próprio bloco, handoff 2 | MDs de estado; telas já reivindicadas pela Sessão 1 |
| Coordenadora | Codex | pasta principal `C:\Users\adrie\Documents\Coelo`, branch `dev` | `git pull --ff-only`; lê os dois handoffs; atualiza `R14-pendencias.md` (contadores, cabeçalho, H, itens da ADR, "sobra para a R15"), `current-state.md`, checkpoints, `ETAPA-2-estado-atual.md`, referências das skills, `docs/knowledge`, `entrega-atual.json` e o gate; no fim remove worktrees e branches com manifesto | executar telas, SQL ou deltas de estado; editar dentro das worktrees das sessões; abrir a R15 (é do Owner) |
| Owner | — | — | cola os avisos entre as sessões e a coordenadora; decide | — |

## Recursos exclusivos por sessão

- Sessão 1: servidor `127.0.0.1:3014`, Chrome CDP `9414`, perfil `%TEMP%\coelo-r14-ab-chrome`.
- Sessão 2: servidor `127.0.0.1:3015`, Chrome CDP `9415`, perfil `%TEMP%\coelo-r14-cd-chrome`;
  espelho `Coelo-backups/mirror-r14` (`project_id coelo_mirror_r14`, portas `614xx`,
  container `supabase_db_coelo_mirror_r14`), criado a partir de dump novo da produção.
- Só a Sessão 2 aplica SQL em produção e escreve `ordem-de-aplicacao-producao.txt`.
- Um Chrome e um `flutter test` por sessão; `flutter build web` dentro da própria worktree.
- Usuários sintéticos `qa-r06-*` (`Coelo-backups/qa-r06-<frente>.env`); as duas sessões podem
  usar o mesmo usuário em telas diferentes. Nunca imprimir credenciais.

## Fluxo git por fatia provada (as duas sessões)

1. `git add <caminhos explícitos>` — nunca `git add -A`, nunca `git stash`, nunca só em memória.
2. `git commit -m "r14(<bloco>): <tela> — <o que foi provado>"`.
3. `git fetch origin` e `git rebase origin/dev`.
4. Conflito em `docs/reviews/inventario-etapa-2.json` ou nos três rastreadores
   (`coelo-*-pendencias.md`): durante o rebase, ficar com a versão de `origin/dev`
   (`git checkout --ours -- <arquivo>`), reaplicar o próprio delta
   (`node docs/reviews/apply-tracker-delta.cjs <delta.json>`), rodar
   `node docs/reviews/validate-trackers.cjs`, `git add`, `git rebase --continue`.
   Conflito em `R14-pendencias.md`: manter as duas edições (linhas diferentes).
5. `git push origin HEAD:dev` (fast-forward). Rejeitado → repetir 3–4. Nunca `--force`.
6. Registrar a fatia no handoff próprio (mesmo commit ou o seguinte).

## Handoffs — como as sessões conversam

- `R14-handoff-sessao-1.md` (só a Sessão 1 escreve) e `R14-handoff-sessao-2.md` (só a
  Sessão 2 escreve), nesta pasta, `lifecycle: current`. A coordenadora lê; não escreve neles.
- **Antes de cada tela**: `git fetch origin` e ler o handoff da outra sessão em `origin/dev`
  (`git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-<n>.md`).
  Tela reivindicada pela outra sessão não se toca.
- Seções fixas de cada handoff:
  - `## Reivindicações` — tela, action_ids, hora; retirar quando fechar ou desistir.
  - `## Fatias entregues` — SHA, action_ids → estados, linhas de Owner alteradas, evidência.
  - `## Avisos para a outra sessão` — ex.: "lote 70 em produção às 14:10; funções X/Y alteradas".
  - `## Sobra para a R15` — sugestão; a coordenadora leva para `R14-pendencias.md`.
  - `## Contadores` — FE/BE/E2E/Owner após a última fatia (`validate-trackers`).
- **Aviso à coordenadora**: a cada bloco fechado (e ao parar por cota), a sessão publica no chat
  um aviso curto (≤ 12 linhas: SHA, bloco, action_ids/Owner items fechados, contadores, sobra)
  que o Owner cola na coordenadora. A sessão não espera resposta; continua.

## O que cada um edita

- Sessões: código, testes, migrations e `supabase/tests` (Sessão 2), evidências em
  `docs/reviews/evidence/etapa-2/r14-sessao-<n>/` (+ `capturas/`), deltas JSON, inventário e
  rastreadores (só via script), a própria linha de Owner item em `R14-pendencias.md` (só IDs do
  próprio bloco; tokens exatos `done / verified / done / verified-e2e`) seguida de
  `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`, o próprio handoff.
- Coordenadora: o restante de `docs/agent`, `docs/reviews/etapa-2-operacao` (exceto handoffs e
  linhas de Owner reivindicadas), `docs/knowledge`, skills, `entrega-atual.json` e relatório do gate.

## Decisões do Owner de 15/09/2026 (artefato 89AVWHKEnq5hrvYN6SFv6M)

1. **Worktrees separadas** para as duas sessões (recria `Coelo.worktrees`); push para `dev` por rebase.
2. **Bloco B**: sete ações `mvp` → `deferred-post-mvp` — `plans.assign`, `institutions.status`,
   `institutions.locations-map`, `catalog.list`, `catalog.validate`, `catalog.sync`,
   `catalog.publish` (BE e E2E = `deferred-post-mvp`; FE fica como está). MFA ×3 já está em
   `gate-formal-mvp`; sem mudança. E2E ativo 199 → 192; FE 231 e BE 224 não mudam.
   `apply-tracker-delta.cjs` ganha o campo opcional `escopo` para gravar `scope`.
3. **Catálogo de UI**: registrar "V1 ou Etapa 3 (a definir)".
4. **OQ-033 = B** (exclusão real só sem vínculo/auditoria; lógica nos demais) + regra de pessoas:
   instituição/unidade não excluem pessoas, só **desvinculam**; a pessoa pertence ao app e só o
   superadmin exclui ou **suspende por período**. Vira spec de ciclo de vida na **R15**;
   `institutions.status` volta ao escopo dentro dela.
5. **OQ-034**: Locais com mapa por imagem vai inteira para a **R15**.
6. **Bloco C** na ordem: Cardápios → Segurança infantil → Arquivos de Formulários →
   Avaliações Fechar/Reabrir → Perfis de acesso (último; se não couber, R15).
7. **Bloco D** completo: r12-29/30 → OQ-031 → readers de Planos (039) e reader self da Conta →
   `localhost` na allowlist de redirect do Supabase Auth (autorizado; não toca SMTP, DNS, senha
   nem token) → H08 Duplicar Aviso (+ H23, H13).

Sessão 1, se fechar A e B com folga, só pega do Bloco C o que não precisa de SQL e ainda não foi
reivindicado pela Sessão 2 (Segurança infantil; Arquivos › Upload/Resolver), avisando no handoff.

## Cota e fechamento

- A ~4% de cota: commit/push verde, handoff atualizado, `node docs/reviews/validate-trackers.cjs`,
  `& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1 -Root (Get-Location).Path`,
  `python docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json`, relatório final
  PASS COMPLETE / PASS DOCUMENTED_PARTIAL / FAIL com SHA, contadores e sobra.
- Fim da R14 (coordenadora): `git worktree remove` das duas cópias, apagar branches `r14/*` já
  integradas em `dev`, manifesto em `docs/agent`, `RODADAS.md`; este arquivo passa a `historical`.
