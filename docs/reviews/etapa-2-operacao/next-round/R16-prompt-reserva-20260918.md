---
title: "R16 — prompt da Sessão RESERVA (decisões D2, D4, D5, D6, D7 do Owner em 18/09)"
source: "R16-levantamento-fechamento-mvp-20260918.md §4; decisões do Owner em 18/09/2026 (conversa com a coordenadora); R16-pendencias.md; ADR 0041 (D6, E7), 0042, 0044; ordem-de-aplicacao-producao.txt (lote 74)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# Prompt — Sessão RESERVA (colar numa conversa nova do Claude Code)

> Para abrir: numa conversa nova em `C:\Users\adrie\Documents\Coelo`, cole:
> **"Você é a SESSÃO RESERVA da R16. Leia e execute
> `docs/reviews/etapa-2-operacao/next-round/R16-prompt-reserva-20260918.md`
> do início ao fim."**

---

Você é a SESSÃO RESERVA da R16 do Coelo. A coordenadora está na pasta principal
(`dev`) fazendo a definição do MVP e a revisão de telas com o Owner; você executa
as decisões D2, D4, D5, D6 e D7 tomadas pelo Owner em 18/09/2026. Não abra R17
nem Etapa 3.

## Ambiente

- Antes de criar a worktree: `ListAgents` e pedir identificação às sessões pares.
- Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-reserva`, branch
  `r16/reserva-20260918` criada de `dev` (HEAD ≥ `83d5478bd`). Todo comando roda
  dentro da worktree. Porta 3014, CDP 9414, perfil `%TEMP%\coelo-r16-reserva-chrome`.
  Espelho de banco `mirror-r16-reserva` a partir de dump novo de produção.
- Handoff: `docs/reviews/etapa-2-operacao/next-round/R16-handoff-reserva.md`
  (criar; atualizar a cada bloco). Evidências em
  `docs/reviews/evidence/etapa-2/r16-reserva/<tema>-20260918.md`.
- Entrada obrigatória: AGENTS.md; `docs/agent/current-state.md`;
  `source-of-truth.md`; ADR 0041 (D6, E7), 0042, 0044; `R16-pendencias.md`;
  `R16-levantamento-fechamento-mvp-20260918.md`; skills `coelo-supabase`,
  `coelo-flutter-review`, `coelo-flutter-supabase-review` (`review-scope.md`:
  rota real 14/09, 15/09, 17/09 e "Sessão QA autenticada");
  `docs/knowledge/team/stale-version-pt409-and-production-rite.md`.

## Skills a invocar (na ordem em que o trabalho pede)

- `/rtk` no início da sessão (e `RTK.md` do repositório): toda saída grande de
  terminal (`flutter test`, `supabase`, `git log`, pgTAP) passa pelos wrappers
  `rtk` para não estourar o contexto.
- `/coelo-flutter-supabase-review` para o recorte de cada bloco (objetivo,
  incluído, fora, ordem, parada, evidências) — é ponta a ponta.
- `/coelo-supabase` nos blocos 1 (sino v2), 2 (fixture), 3 (E.164 no servidor),
  4 (projeção `can_remove`) e no lote 82: migration, pgTAP, rito.
- `/coelo-flutter-review` no bloco 3 (máscara, testes de widget) e no bloco 5
  (testes vermelhos); `/coelo-ui` para o componente de Celular.
- `/systematic-debugging` antes de corrigir qualquer teste vermelho ou defeito
  de rota real; `/test-driven-development` ao escrever pgTAP e widget tests.
- `/verification-before-completion` antes de marcar qualquer item `done`;
  `/finishing-a-development-branch` ao fechar a branch para a coordenadora.
- `/supabase` só para consulta de CLI/Auth quando a skill do Coelo não cobrir.

## Regras (não negociáveis)

- Estados por `action_id` só por `node docs/reviews/apply-tracker-delta.cjs
  <delta.json>` com `certificacao{evidence,revision,environment:"producao",recordedAt}`;
  Owner items editados na linha de `R16-pendencias.md` +
  `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`;
  `node docs/reviews/validate-trackers.cjs` PASS antes de cada commit.
- Nunca `git add -A`, `stash`, rebase, push em `dev`, `--force`. Commits pequenos
  na branch `r16/reserva-20260918`; publicar a branch como backup; a coordenadora
  integra por cherry-pick.
- Credenciais QA: `C:\Users\adrie\Documents\Coelo-backups\qa-r06-<area>.env` e
  `qa-r15-responsavel.env`; nunca em log, evidência ou commit.
- PT409 (nunca 40001). Produção `evvbomzejfijozbtgvpt` é o único remoto.
- Escrita em produção só pelo rito por lote: espelho de dump novo + pgTAP verde +
  dump prévio com SHA-256 em `Coelo-backups` + `supabase db query --linked
  --workdir packages/coelo_database -f migrations/<arquivo>` + `migration repair
  --status applied` + `migration list --linked` + linha no
  `ordem-de-aplicacao-producao.txt`. Último lote aplicado: **81**. Próximo: **82**.
- **Autorização nominal do Owner (18/09/2026, conversa com a coordenadora)**
  cobre o lote 82 **somente** para: (a) Medicação sino v2 (responsável como
  destinatário, E7 = b) e correção de `recipients-bug`; (b) normalização E.164 do
  Celular na Conta; (c) massa sintética `QA R15` para r12-08; (d) candidato de
  fechar/reabrir de Avaliações (r12-49). Qualquer outro SQL em produção é
  bloqueio com causa no handoff; não inventar contrato. Um comando PowerShell
  combinado negado pelo classificador → separar os passos, nunca contornar.

## Fato corrigido em 18/09 (leia antes de tudo)

As migrations `20260916180000_attendance_call_history_v1`,
`20260916183000_attendance_routine_snapshot_v1` e
`20260916190000_medication_in_app_notifications_v1` **já estão em produção**
(lote 74, 16/09 17:40, ledger 307–309). As linhas de owner.r12-04, r12-06 e
r12-33 em `R16-pendencias.md` que dizem "NÃO aplicada" estão desatualizadas:
corrija o texto delas na primeira passagem e registre no handoff. **D2 é prova na
rota real, não lote novo.**

## Fatia, nesta ordem

### Bloco 1 — D2: provar Histórico, snapshot e sino (sem SQL novo)

1. `owner.r12-04`: `/attendance/history` com `qa-r06-operacoes` na rota real
   (3014): lista, filtros, cursor, abrir detalhe, reload; negativa cross-tenant
   por PostgREST. Decisão pendente do Owner sobre "Publicar lançamento"
   (spec 052 §3): **não decidir**; registrar no handoff.
2. `owner.r12-06`: concluir uma chamada real → detalhe mostra snapshot;
   reabrir/concluir preserva; legado mostra "rotina atual (não registrada na
   época)"; versão defasada → 409 `PT409`.
3. `owner.r12-33`: primeiro corrigir `recipients-bug` (destinatários de cuidado
   contam membership `guardian` como equipe) e incluir o responsável (E7 = b) em
   `medication_in_app_notifications_v2` + pgTAP no espelho → lote 82 (item a).
   Depois: editar plano e registrar dose reais; observar o sino com admin da
   unidade, educador da turma e `qa-r15-responsavel` (por PostgREST se a conta
   só-responsável não abrir tela, OQ-048).
4. Ao fim de cada item: linha do Owner item → `done` com evidência; delta do
   inventário só se algum `action_id` mudar (não deve).

### Bloco 2 — D4: massa sintética para r12-08

5. Fixture `QA R15` (prefixo obrigatório) que dê a uma turma do escopo de
   `qa-r06-operacoes` ≥2 alunos ativos e rotina vinculada, forward-only,
   idempotente, sem tocar em dados reais → lote 82 (item c). Se
   `20260917113000_qa_r15_guardian_membership_v1` for necessário para a leitura,
   registrar; não aplicá-lo sem essa necessidade provada.
6. Provar `attendance.mark/correct/finish` com ≥2 alunos e múltiplas turmas na
   rota real; `owner.r12-08` → `done`. `participants-vazio` não é defeito (Mesa
   R16); se a prova de r12-05 couber no mesmo ambiente, executar a negativa do
   contexto Atividade (instituição alheia / atividade inelegível) e fechar
   `owner.r12-05`.

### Bloco 3 — D5: Celular em E.164 com máscara

7. Cliente (Conta › Celular): máscara brasileira na digitação, exibição
   formatada, envio em E.164 (`+55DDDNNNNNNNN`), validação com mensagem clara;
   testes de widget; `coelo-ui` para o componente.
8. Servidor: `account_profile_save_v3` (ou equivalente vigente) normaliza e
   valida E.164 e rejeita formato inválido com código de família (não 40001);
   pgTAP; lote 82 (item b). Registrar formato na spec/ADR pertinente via
   coordenadora (não criar ADR).
9. Prova na rota real: gravar, reler, reload; inválido bloqueado; `celular-mascara`
   e a parte de Celular de `owner.r12-46` → concluídos (r12-46 continua
   `deferred` pelo layout A+, Etapa 3).

### Bloco 4 — D6: `can_remove` no Agora

10. Padrão adotado, salvo instrução contrária do Owner no início da sessão:
    **o feed segue a RPC** — a projeção `can_remove` passa a refletir quem a RPC
    de remoção aceita (autor e administradores do escopo). É projeção de leitura
    (lote 79 criou `can_remove`); se exigir migration, entra no lote 82 como
    ajuste de projeção; se o Owner escolher a outra opção (RPC restringe ao
    autor), é mudança de contrato → bloqueio até confirmação. Prova: como
    administrador, o botão aparece e remove; como não-autor sem capacidade, não
    aparece e a RPC nega.

### Bloco 5 — D7: 21 testes funcionais vermelhos (goldens ficam na Etapa 3)

11. Em `apps/superadmin`: `model_save_completion_routes_test` (3),
    `principal_real_route_test` (1), `principal_profile_for_you_production_routes_test`
    (1), `activity_routes_test` (1), routers `principal-context-selector`,
    `invite_responsive_test` (toggle removido na R14) e os demais do censo de
    17/09 (`R15-checkpoint-20260917.md`). Corrigir o **teste** quando a
    referência ficou velha; corrigir o **código** quando é regressão real, e
    registrar qual foi qual. Não regravar goldens. Ao fim: censo completo
    `flutter test` com contagem antes/depois no handoff.

### Lote 82 (rito) — ao final dos blocos 1–4

12. Reunir os candidatos (a) sino v2, (b) Celular E.164, (c) fixture r12-08,
    (d) close/reopen de Avaliações (localizar o candidato "após gate SQL" de
    `owner.r12-49`; se não existir arquivo, escrever a migration a partir do
    contrato local-green), pgTAP de cada um no espelho, dump prévio, aplicar um a
    um, reparar ledger, listar, anotar o lote no `ordem-de-aplicacao-producao.txt`
    com a autorização nominal referenciada a este arquivo. Depois provar
    `assessments.close/reopen` na rota real (diário `d2c945d8`, sem duplicar
    participante/diário) e fechar `owner.r12-49`.

## Parada e entrega

- Parar e registrar bloqueio se: rito exigir SQL fora dos itens (a)–(d); Owner
  precisar decidir (Publicar lançamento, opção de D6 diferente do padrão); produção
  responder 504 ou `40001`.
- Ao fim: handoff com o que fechou e o que não fechou (com causa), evidências,
  `validate-trackers.cjs` PASS, branch publicada, mensagem para a coordenadora
  com a lista de commits para cherry-pick. Não alterar `current-state.md` nem
  `backlog.md` (a coordenadora faz).
