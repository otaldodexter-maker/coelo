---
title: "R15 — prompts de execução (coordenadora + Blocos A, B e C)"
source: "decisions/0042-r14-closure-r15-opening-20260916.md (E1–E7); R15-pendencias.md; R14-checkpoint-20260916.md; R14-handoff-sessao-5..10.md; Owner em 16/09 (quatro prompts; meta 100% E2E a partir de 17/09)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R15 — prompts de execução

Quatro prompts, conforme E5 da ADR 0042: um para a coordenadora (pasta
principal, `dev`) e um por bloco (worktree própria). Cada bloco é uma sessão
executora; a coordenadora integra por cherry-pick. Copie o prompt inteiro para
a sessão correspondente. Meta do Owner: **E2E 186/186** (hoje 162) — as ações
que dependem de decisão estão nomeadas no prompt da coordenadora.

Regras comuns (valem para os quatro): AGENTS.md → `docs/agent/current-state.md`
→ `source-of-truth.md` → ADR 0041 e ADR 0042 → `R15-pendencias.md` →
`review-scope.md` (seções de rota real e sessão QA). Skills:
`coelo-flutter-supabase-review` por fatia; `coelo-supabase`/`coelo-flutter-review`
como folhas; `coelo-ui` para tela; `coelo-knowledge` se nascer regra durável.
Estados só por `apply-tracker-delta.cjs` com evidência em produção
(`certificacao{evidence,revision,environment:"producao",recordedAt}`); Owner
items só na linha própria + `sync-r12-owner-records.cjs`; `validate-trackers.cjs`
PASS antes de cada commit; nunca `git add -A`/`stash`; credenciais QA nunca em
log/evidência/commit; PT409 (nunca 40001) para versão defasada; produção é o
único remoto; toda escrita em produção pelo rito (espelho + pgTAP + dump prévio
+ `supabase db query --linked -f` + `migration repair` + ledger + lote na
`ordem-de-aplicacao-producao.txt`). Massa nova leva prefixo `QA R15`.

---

## Prompt 0 — Coordenadora (pasta principal `C:\Users\adrie\Documents\Coelo`, branch `dev`)

Você é a COORDENADORA da R15 do Coelo (checkout principal, branch `dev`, HEAD ≥ `ea62932dd`). A R15 é a vigente (ADR 0042); não abra R16. Meta do Owner: **E2E 186/186** até o fim do dia, com prova na rota real em produção, aplicando as decisões já tomadas (ADR 0041 A–D, ADR 0042 E1–E7). Nada é pedido de novo ao Owner exceto o que está listado em "Decisões ainda necessárias".

Entrada obrigatória: AGENTS.md; `docs/agent/current-state.md`; `docs/agent/source-of-truth.md`; `decisions/0041-*` e `decisions/0042-*` inteiras; `docs/reviews/etapa-2-operacao/next-round/R15-pendencias.md` (todas as seções); `R14-checkpoint-20260916.md`; `R14-execucao-paralela.md` (histórico — reaproveitar o modelo); handoffs `R14-handoff-sessao-5..10.md` (roteiros de retomada); `.agents/skills/coelo-flutter-supabase-review/references/review-scope.md`.

Papel: (1) escrever `R15-execucao-paralela.md` (sessões A/B/C, worktrees `Coelo.worktrees\r15-bloco-a|b|c` em branches `r15/bloco-a|b|c` criadas de `dev`, `.env.local` copiado, portas 3014/3015/3016 e CDP 9414/9415/9416, espelhos 621xx/622xx/623xx, handoffs `R15-handoff-bloco-a|b|c.md`); (2) lançar as três sessões com os Prompts A, B e C deste arquivo; (3) integrar cada entrega em `dev` por cherry-pick (conflito em inventário/rastreadores: manter `dev`, reaplicar o delta JSON, `validate-trackers`; conflito em `R15-pendencias.md`: manter as duas linhas); (4) a cada integração: atualizar cabeçalho/contadores/projeção de `R15-pendencias.md` (projeção de ações não terminais gerada do inventário por `frontendStatus/backendStatus/integratedStatus`), `current-state.md`, `ETAPA-2-estado-atual.md`, `entrega-atual.json` (worktrees protegidas, branches residuais `patch-equivalent` com `successor`, formalActions para ações mudadas fora de Owner items), `node docs/reviews/validate-trackers.cjs`, `powershell -File .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1 -Root <raiz>`, `git diff --check`, commit + `git push origin dev`, `python docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json` (PASS); (5) escritas em produção que uma sessão não conseguir por permissão são feitas por você pelo rito (regra local já liberada); (6) no fim: checkpoint `R15-checkpoint-<data>.md`, contadores antes→depois, action_ids certificados, bloqueios por causa (sessão/massa/RPC/ambiente/decisão), gate PASS, stash vazio, worktrees listadas. Não execute telas você mesma; não edite dentro das worktrees.

Decisões ainda necessárias para 186/186 (levar ao Owner só se as sessões chegarem lá): `auth.recover`/`auth.reset` (ADR 0039 → Etapa 3; Owner sinalizou provar com a própria caixa — registrar como E8 se confirmar) e `auth.mfa`/`account.mfa`/`internal-users.mfa` (`gate-formal-mvp`: provar TOTP real na rota ou reclassificar). Sem essas 5, o teto é 181/186.

Ordem de integração: aceite o que chegar; se duas sessões tocarem o mesmo arquivo Dart, resolva mantendo os dois comportamentos e rode `flutter analyze` + as suítes das famílias tocadas antes do commit. Goldens: só regravar quando o `isolatedDiff` for cabeçalho (E4) ou mudança decidida (B2); registrar cada regravação.

---

## Prompt A — Bloco A: rota real já pronta (worktree `Coelo.worktrees\r15-bloco-a`, branch `r15/bloco-a`, porta 3014, CDP 9414, perfil `%TEMP%\coelo-r15-a-chrome`, handoff `R15-handoff-bloco-a.md`, evidências `docs/reviews/evidence/etapa-2/r15-bloco-a/`)

Você é a SESSÃO A da R15 do Coelo. Leia: AGENTS.md; `docs/agent/current-state.md`; `source-of-truth.md`; ADR 0041 e 0042; `R15-pendencias.md` (Mesa R15, Ordem de execução, Owner items, Ações não terminais); `review-scope.md` (rota real 14/09 e 15/09; sessão QA); modelos de evidência `r14-sessao-1/units-error-access-denied-20260915.md` + `deltas-*.json`, `r14-sessao-1/circulars-attach-20260915.md` (upload real via CDP); roteiros de retomada em `R14-handoff-sessao-5.md`, `R14-handoff-sessao-6.md`, `R14-handoff-sessao-7.md` (Momentos) e `r14-sessao-7/momentos-bloqueado-20260916.md`. Ferramentas: `serve.py`, `cdp_sem.dart`, `cdp_filechooser.dart`, `cdp_block.dart`, `r13-rpc-proof.mjs`, `test_driver/qa_login.dart`; build `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`. Credenciais QA em `C:\Users\adrie\Documents\Coelo-backups\qa-r06-<area>.env` (carregar no processo; nunca imprimir). Produção está saudável; CORS liberado para 3014–3024 (403 de origem agora é defeito, não ambiente). Você não escreve SQL em produção; tudo aqui é tela + PostgREST com identidade QA.

Fatias, nesta ordem, cada uma com md + capturas sem PII + `deltas-<fatia>-<data>.json` + commit `r15(bloco-a): <tela> — <provado>` + `git push -u origin r15/bloco-a` (sem push em dev, sem rebase):
1. Perfis de acesso (`qa-r06-acessos`): `access-profiles.edit` e `access-profiles.assign` — editar o perfil `R14 S5 Perfil QA` (renomear, alterar permissão) com persistência/reload; atribuir a um usuário interno do escopo em `/internal-users/:id/edit` e restaurar; negativas por PostgREST (versão defasada → 409 PT409/SAI_CONCURRENT_CHANGE, instituição alheia → 403). Owner items: r12-21 (detalhe, catálogo real, reload), r12-24 (tooltip por foco/toque na rota), r12-25 (matriz em 1440 e ~600 px via `Emulation.setDeviceMetricsOverride`), r12-26 (Continuar laranja preenchido, tema claro, edição), r12-27 (revisão módulo › tela › ação; salvar/reload sem perder próprias/todas), r12-20 e r12-22 → done. NÃO tocar r12-19/23.
2. Instituições (`qa-r06-estrutura`): `institutions.error` e `institutions.access-denied` — deep link `/institutions/<uuid inexistente>` → painel de acesso negado sem dado + reload; RPC de detalhe bloqueada por `cdp_block.dart` → painel de erro + Recarregar recupera; negativa 403 por PostgREST. Conferir o aviso "Arquivos em desenvolvimento" no flyout (A4) e capturar.
3. Conta (`qa-r06-acessos`): `account.profile` / r12-46 — foto real PNG 64×64 via `cdp_filechooser.dart` pela Edge `account-media` (CORS ok), avatar do cabeçalho atualizado, reload, nova sessão (novo perfil de Chrome) vê a foto, remover foto, sigla/cor/celular relidos, celular inválido/válido; negativa authorize_read/remove de asset alheio → 403. Se o card "Meu acesso" não estiver na linha de "Dados pessoais" (A+ 14/09), implementar via coelo-ui com teste antes de capturar. r12-46 → done se todos os gates.
4. Formulários (`qa-r06-formularios`): `forms.expire-file` e `forms.delete-file` (lote 73 aplicado: worker/EF `form-media` reais — ler `r14-sessao-6/forms-expire-delete-file-20260916.md`), `forms.create`/`forms.edit` + r12-39 (posição final persistida após arrastar/mover) + r12-40 (seção renomeada, nome na prévia), `forms.location-answer` (resposta com localização, persistência, reload, valor inválido rejeitado, formulário alheio → 403).
5. Momentos (`qa-r06-publicacoes` publica, `qa-r06-principal` lê): `momentos.view`, `momentos.publish`, `momentos.remove` e `momentos.create` (bloqueio de CORS caiu — se o `blocked-environment` tiver outra causa, registre-a) com mídia R2 real, reload e negativas por PostgREST.
6. `errors.409` (flutter-only): provocar conflito real (avançar `management_version` por PostgREST e salvar pela tela) e capturar a página/estado 409; delta só `frontend` → verified.
7. Se sobrar: `agora.publish` E2E depende da massa E2 (Bloco B cria); combine pelo handoff do Bloco B antes de tentar.

Parada: ~5% de cota ou bloqueio sem rota → commit/push verdes, handoff com Reivindicações/Fatias entregues/Avisos/Bloqueios (causa)/Contadores, relatório ≤ 25 linhas. Encerrar Chrome/servidor.

---

## Prompt B — Bloco B: migrations aplicadas + massa + OQ-047 (worktree `Coelo.worktrees\r15-bloco-b`, branch `r15/bloco-b`, porta 3015, CDP 9415, perfil `%TEMP%\coelo-r15-b-chrome`, espelho `mirror-r15-b` portas 622xx, handoff `R15-handoff-bloco-b.md`, evidências `docs/reviews/evidence/etapa-2/r15-bloco-b/`)

Você é a SESSÃO B da R15 do Coelo (perfil backend + rota real). Leia o mesmo conjunto do Bloco A e, além disso: `R14-handoff-sessao-8.md`, `R14-handoff-sessao-9.md`, `R14-handoff-sessao-10.md`, `r14-sessao-8/child-safety-lifecycle-504-20260916.md`, `r14-sessao-8/attendance-context-activity-scope-20260916.md`, `r14-sessao-7/agora-remove-20260916.md`, `docs/open-questions.md` OQ-047, specs 052/053/054, migrations `20260916152000/154500/180000/183000/190000/193000` (já em produção, lote 74) e o dump `Coelo-backups/schema-producao-20260916-lote74-before.sql`. Você tem a permissão de produção do rito (`supabase db query --linked -f`, `migration repair`); use-a só pelo rito completo (espelho restaurado de dump novo + pgTAP + dump prévio + aplicação + ledger + lote). Sessões QA: `qa-r06-operacoes`, `qa-r06-acessos`, `qa-r06-publicacoes`, `qa-r06-principal`.

Fatias, nesta ordem:
1. **OQ-047 (E1)**: migration única `20260917HHMMSS_pt409_stale_version_v1.sql` trocando todos os `raise serialization_failure` restantes (~169, listar por `pg_proc.prosrc` no dump) por `raise exception using errcode='PT409', message=<mesma>, detail=<CODIGO_STALE_VERSION da família>`; só a linha do raise muda; pgTAP por família no espelho (versão defasada → PT409 sem mutação; caminho feliz intacto) — aproveite `child_safety_lifecycle_timeout_fix_v1_test.sql` como modelo; aplicar pelo rito; registrar lote. Depois disso, negativas de versão defasada por PostgREST são seguras em qualquer família.
2. **Massa E2** (`QA R15`, tenant QA R04 `d0c40000-…0001`): pela TELA do superadmin (Pessoas/Convites/Turmas/Usuários internos, ações já verified-e2e), criar 1 responsável sintético + 2 crianças sintéticas vinculadas à turma existente (`368a5cea`), e 2 usuários internos (admin de unidade, educador da turma); senhas só em `Coelo-backups/qa-r15-*.env`. Registrar IDs na evidência. Avisar Bloco A pelo handoff (desbloqueia `agora.publish`).
3. **Segurança da criança** (`qa-r06-acessos`): `child-safety.edit`, `child-safety.suspend` (+ `create` se pendente): criar/aprovar/suspender pela tela; persistência, reload; negativas (autorização alheia → 403; versão defasada → 409 PT409, sem 504). Owner r12-13/15/16 → done conforme gates; r12-10 golden verde após C1 (regravar só se o diff for cabeçalho).
4. **Assiduidade** (`qa-r06-operacoes`/`publicacoes`): contexto Atividade em `/attendance/new` (criar atividade `QA R15` vinculada à turma pela tela se não houver elegível) → r12-05 done; com a massa E2, r12-08 (≥2 alunos: marcar/corrigir/concluir, reload) → done; B2 Histórico `/attendance/history` (filtros, cursor, abre detalhe; Lançamentos fora de Rotina; E6) → r12-04; B3 snapshot (concluir chamada grava snapshot; reabrir preserva; legado mostra "rotina atual (não registrada na época)") → r12-06.
5. **Medicação B8 + E7**: migration v2 `medication_in_app_notifications_v2` incluindo o responsável em `plan.updated` e `dose.recorded` (pgTAP ajustado), rito; prova com admin/educador/responsável da massa E2 vendo o sino → r12-33.
6. **Arquivar B1**: Atividades › Modelos e Rotina › Modelos — Arquivar/Restaurar pela tela, aba/filtro Arquivados, reload, negativa PT409 e cross-tenant → r12-02; cards de Rotina (altura uniforme, "Efetivo: —", Arquivar em todos) na rota real → r12-01.
7. **Agora**: `agora.remove` pela tela — aplicar pelo rito o candidato de projeção `management_version`/`can_remove` em `list_visible_now_publications` (handoff 7 §5; atualizar o guard "minimum projection" no mesmo lote), provar remoção imediata + reload + recibo de purge; negativa D5 com a fixture `app_private.seed_qa_r14_chat_cross_tenant_user` executada como `postgres` via `db query`, 422 `publication_remove_denied` sem mutação, revogação ao fim; `agora.expire` E2E (observar `expires_at` e o worker `expire_due_now_publications` sobre a publicação `a4e65c73` de 16/09, que vence ~24 h depois de publicada — capturar o feed antes/depois).

Parada e handoff como no Bloco A.

---

## Prompt C — Bloco C: contratos novos (worktree `Coelo.worktrees\r15-bloco-c`, branch `r15/bloco-c`, porta 3016, CDP 9416, perfil `%TEMP%\coelo-r15-c-chrome`, espelho `mirror-r15-c` portas 623xx, handoff `R15-handoff-bloco-c.md`, evidências `docs/reviews/evidence/etapa-2/r15-bloco-c/`)

Você é a SESSÃO C da R15 do Coelo (contrato → implementação → prova). Leia o conjunto comum e: ADR 0041 B5/B6/B9 e §5, ADR 0042 E3, `R14-handoff-sessao-6.md` (achado do Chat), `r12-coordenacao/child-safety-wizard-gates-r12.md`, `docs/open-questions.md` (OQ-032/033/034/044), `specs/018-profiles-permissions-superadmin.md`, `specs/030-superadmin-child-safety-production.md`, `specs/028-superadmin-conversations-production.md`, `decisions/0037-*` (Principal). Cada fatia: spec curta em `specs/` (número livre seguinte — confira `git fetch` e as branches `r15/*` para não colidir), migration canônica + pgTAP no espelho, FE com testes, aplicação pelo rito, prova na rota real, deltas. Permissão de produção pelo rito (igual ao Bloco B). Sessões QA conforme a área.

Fatias, nesta ordem:
1. **E3 — Chat com vários anexos por mensagem**: `superadmin_chat_attachment_prepare_v2` (N anexos numa mensagem, limite 10 por envio preservado — lote 67), `finalize`/thread v2 expondo a lista por mensagem, Edge `chat-media` ajustada, compositor envia em lote; provar `chat.attach` (tile único, mosaico 3–4 imagens + contador, anexo não visual, reload, negativa cross-tenant por PostgREST) → `chat.attach` verified-e2e, r12-52 done.
2. **B9 — "ver como"** (ADR 0041): só troca avatar/nome no cabeçalho do Principal hospedado, sem faixa fixa; `principal.for-you` e `principal.profile-edit` (BE `blocked-decision` → contrato definido): implementar leitor/escritor necessários, provar Para você e Editar perfil (Sobre salvo/relido, H02 atualização oficial a partir do Sobre) na rota real com `qa-r06-principal`.
3. **B5 — busca de pessoa autorizada** (r12-17): RPC `superadmin_person_search_v1` (prefixo nome/@/e-mail ≥3, celular ≥4, CPF ≥6 dígitos normalizados; escopo do ator; auditoria; limite de taxa; resultado minimizado sem CPF; responsável lista crianças vinculadas do escopo), pgTAP de escopo/negativas/limite, campo único no wizard de Segurança da criança; prova na rota real com a massa `QA R15` (Bloco B) — coordene pelo handoff.
4. **B6 — pessoa sem conta** (r12-18): CPF obrigatório (dedupe), documento + imagem R2 privada (Media Gateway), celular/e-mail, autorizada só no contexto pedido; cadastro só após B5 não encontrar; prova pela tela.
5. **Cardápios r12-38**: migrar `SupabaseMealPlanImageRepository` e vínculos para o Media Gateway R2; habilitar composição; provar upload/reload/escopo.
6. **Specs R15 já decididas (sem prova nesta rodada)**: perfil transversal/funcionário no Principal (OQ-044; r12-19/23), Perfis de cuidado §5 (r12-29/30), ciclo de vida OQ-033 (inclui `institutions.status`), Locais com mapa por imagem (OQ-034), perfis oficiais (OQ-032), Avisos H08/H13/H23 — escrever as specs com contrato, estados, RLS e telas; implementar só se sobrar cota.

Parada e handoff como no Bloco A.
