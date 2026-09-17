---
title: "R16 — execução paralela: duas sessões executoras (FORMS, AGORA) e uma coordenadora"
source: "Owner em 2026-09-17 (ADR 0043, ADR 0044, Foco da R16; meta FE 199/199, BE 186/186, E2E 186/186); R16-prompts.md (Prompts 0, 1 e 2); R16-pendencias.md; R15-execucao-paralela.md (modelo histórico); review-scope.md (retomada entre worktrees, sessão QA D7, rota real 17/09)"
status: "historical"
lifecycle: "historical"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — execução paralela

> Histórico: a execução da R16 terminou em 17/09/2026 ~21:20 BRT com FE 199/199, BE 186/186,
> E2E 186/186 (`R16-checkpoint-20260917.md`). Worktrees e branches `r16/*` removidas (bundles em
> `Coelo-backups/r16-fechamento`). Use este arquivo só como modelo.

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

## Autorizações do Owner durante a execução (17/09, ~20:35 BRT)

1. **Lote 81 autorizado nominalmente antes do rito**: a migration
   `now_guardian_reader_v1` (leitor do Agora reconhece o responsável, spec 070) pode
   ser aplicada em produção pelo rito pela sessão AGORA ou pela coordenadora. Se
   o classificador negar o `supabase db query --linked` à sessão, ela registra o
   comando no handoff e a coordenadora aplica (dump prévio + SHA-256 registrados).
   Continua valendo: espelho + pgTAP verdes antes;
   `20260917113000_qa_r15_guardian_membership_v1` **não** se aplica.
2. **pgTAP da AGORA no mínimo que prova o contrato**: os 5 cenários novos da
   suíte `now_guardian_reader_v1_test` são obrigatórios; as três suítes existentes
   (`now_publication_removal_test`, `now_feed_removal_projection_v1_test`,
   `happens_post_withdrawal_test`) rodam uma vez, depois da migration, no
   espelho (sem antes/depois).
3. **FORMS — prova por RPC vale como rota principal se o Chrome travar**: se o
   login pelo driver travar (SwiftShader) mais de uma vez, a prova de
   `forms.location-answer` por PostgREST com a sessão QA
   (`form_get_occurrence_for_response`/`form_submit_response`, `r13-rpc-proof.mjs`)
   certifica o E2E; a tela vira complemento (capturas se possível). A publicação da
   v4 e a troca para "Uma vez" continuam pela tela do editor.

## Registro de integrações e leituras D1

| Hora (BRT) | Evento | Detalhe |
|---|---|---|
| 20:1x | Identificação das sessões | `coelo-2a` = FORMS (dona de `r16-forms`); `coelo-5a` = AGORA (dona de `r16-agora`); `coelo-02`/`coelo-38` fora da R16 |
| 20:2x | `.env.local` + `.temp` copiados para `r16-agora` pela coordenadora | FORMS copiou os seus |
| 20:3x | Owner autoriza lote 81 antecipado, pgTAP mínimo na AGORA e RPC como rota principal na FORMS | seção acima; repassado às duas sessões; Docker Desktop já ligado |
| 20:5x | Integração AGORA fatias 1–2: `c539fc40d` → `dev` `b9f7258b5` (cherry-pick) | spec 070, migration `20260917203000_now_guardian_reader_v1`, pgTAP 21/21 no espelho fiel (removal 18/18, projection 9/9, happens 33/33 sem regressão); dump prévio `schema-producao-20260917-r16-agora-before.sql` SHA-256 `0c6c6468…`; sessão iniciou o rito do lote 81 |
| 20:33 | **Lote 81 aplicado em produção pela sessão AGORA** (23:33:53–58 UTC, 0 erros; `migration repair` + `migration list` OK; `20260917113000` só local) | Pós-verificação D1: `now_reader_actor` sem execute a `anon`/`authenticated`; `list_visible_now_publications` usa `now_reader_actor`; `now_actor` intacto. Prova PostgREST 23:39Z: `qa-r15-responsavel` → 200 com `d9580375` (`can_remove false`), 2ª chamada idêntica; instituição inexistente → 403 42501; `qa-r06-principal` → `[]` |
| 20:41 | Leitura D1 para a FORMS (v4 publicada às 23:30Z pela tela; agendamento "Uma vez") | form `4555ba07` mv5, `published_version_id e0107c9d` (v2, itens short_text + location `90d33a71`); ocorrência nova `c42cf334` open (23:00Z–24/09 23:00Z, versão nova); cron `coelo-forms-occurrences` reconciliou às 23:40Z: 11 participações, pessoa `9f944691` elegível (participation `12aa895e`). Resíduo: as 24 ocorrências diárias 18/09–11/10 continuam `scheduled` (item `form-diario`, fora do foco). Nenhuma ocorrência de outro tenant existe em produção (negativa alheia = "sem massa") |
| 20:5x | Leitura D1 complementar para a FORMS: resposta `b1d52e77` gravada às 23:43:50Z na `c42cf334` (versão `e0107c9d`); todas as ocorrências futuras já reconciliadas (pessoa participante em todas) → negativa "sem participação" = sem massa; sugerida a `90272261` (scheduled) como negativa de janela fechada | FORMS dispensou ajuda adicional (fecha em ~20 min) |
| 21:0x | **Integração AGORA final: `daddde1a0` → `dev` `560a154aa`** (cherry-pick limpo) | Ledger lote 81, evidência `r16-agora/agora-publish-guardian-reader-20260917.md`, delta `agora.publish` BE done / integrated **verified-e2e** (certificação produção, revisão `c539fc40d`), handoff AGORA. `validate-trackers` PASS: FE 198/199, BE 185/186, **E2E 185/186**. Espelho parado; worktree limpa. AGORA ofereceu ajuda à FORMS a partir da própria worktree (remoção da worktree adiada até ela liberar) |
| 21:0x | AGORA encerrada; branch bundlada em `Coelo-backups/r16-fechamento/r16-agora-publish-20260917.bundle`, apagada (remota/local), worktree removida | `215f5904e` |
| 21:1x | **Integração FORMS: `0479cd56a` → `dev` `21f4485ad`** (conflito em inventário + 3 rastreadores: mantido `dev`, delta da FORMS reaplicado) | `validate-trackers` PASS: **FE 199/199, BE 186/186, E2E 186/186**. FORMS encerrada; branch bundlada (`r16-forms-location-answer-20260917.bundle`), apagada, worktree removida; pasta `Coelo.worktrees` vazia e removida |

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
