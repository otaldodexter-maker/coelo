---
title: "R14 — fila única consolidada da Etapa 2"
source: "Owner em 2026-09-14 (consolidar R12/R13 numa única fila); Owner em 2026-09-15 (ADR 0039 e ADR 0040); R12-pendencias.md (tabela Owner, 53 IDs); R13-pendencias.md (H02–H28, itens da ADR 0038); inventario-etapa-2.json (estados certificados por action_id); R14-catalogo.md"
status: "historical"
lifecycle: "historical"
generated_at: "2026-09-14"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — fila única consolidada (congelada em 16/09/2026)

> **Histórico.** R14 foi encerrada em 16/09/2026 (ADR 0042) e toda a fila não terminal foi consolidada em `R15-pendencias.md`, que passa a ser o único arquivo vivo. Não editar este arquivo.

> **(Texto original da R14.)** `R12-pendencias.md` e
> `R13-pendencias.md` estão congelados como histórico. A tabela de Owner items abaixo
> é a fonte lida por `sync-r12-owner-records.cjs` (53 linhas, IDs preservados);
> `docs/reviews/inventario-etapa-2.json` continua a fonte dos estados por `action_id`.
> Regra: item `done` fica registrado aqui apenas para contagem e não volta à execução;
> item `open`/`partial`/bloqueado é a fila. Não criar cópias em outros arquivos.

Contadores certificados pelo inventário e `validate-trackers.cjs` em
16/09/2026, após a integração da segunda onda (Sessões 5–8, coordenação):
FE 189/232 (81,47%), BE 171/219 (78,08%), E2E 162/186 (87,10%), Owner 21/53
(39,62%). Delta desta onda: `access-profiles.create` (Sessão 5) e
`agora.create`/`agora.view` (Sessão 7) → `verified-e2e`; `agora.publish`/
`agora.expire` com BE `done`. Corte anterior (Mesa do Owner, ADR 0041): FE
186/232, BE 168/219, E2E 159/186. O denominador integrado ativo continua 186
(`institutions.files` pós-MVP; seis páginas de erro `flutter-only`).

## Ordem de execução (decisão do Owner de 14/09, ajustada: fechar primeiro o mais fácil e rápido)

**Bloco A — concluído (10/10 na rota real; FE/BE/E2E certificados conforme aplicável):**
1. Circulares › Anexos (`circulars.attach`) → Circulares 11/11.
2. Agenda › Solicitar (`agenda.request`) → Agenda 7/7.
3. Assiduidade › Nova chamada (`attendance.create`) → Assiduidade 5/5.
4. Rotina › Aplicar (`daily-routine.apply`) → Rotina 5/5.
5. Acontece › Criar (`acontece.create`) → Acontece 4/4.
6. Shell › Troca de contexto (`shell.switch-context`, flutter-only) → Shell 5/5.
7. Atividades › Diretório + Publicar (`activities.list/publish`) → Atividades 7/7.
8. Convites › Lista + Reenviar (`invites.list/resend`) → Convites 5/5.
9. Chat › Criar grupo (`chat.create-group`).
10. Unidades › Erro + Acesso negado (`units.error/access-denied`) → Unidades 10/10.

**Bloco B — reclassificação autorizada pelo Owner em 15/09 (alvo: E2E ativo 199 → 192; a formalização posterior de `agora.remove` leva a base a 193):**
O delta controlado já foi aplicado ao inventário certificado; o denominador
ativo agora é 193, sendo 192 após o Bloco B e mais uma ação formalizada pela
ADR 0040. As sete ações foram marcadas `deferred-post-mvp` no escopo
autorizado e não bloqueiam a execução do MVP.
11. `plans.assign`, `institutions.status`, `institutions.locations-map`, `auth/account/internal-users.mfa`
    → `deferred-post-mvp`/`gate-formal-mvp`; Catálogo de UI (`catalog.*`) → V1/Etapa 3.
    Fecha Planos 4/4 e Usuários internos 4/4.

**Bloco C — uma tela com SQL pequeno + rota real:**
12. Cardápios (`meal-plans.create/edit/model-create/model-edit/publish`) → FE/BE/E2E provados pela Sessão 2; `owner.r12-34/35/36/37` aguardam aceite central, sem repetir a prova.
13. Avaliações › Fechar/Reabrir (`assessments.close/reopen`) — certificado pela
    delta oficial da Sessão C, com rota real, sessão autenticada, reload e
    negativa publicados; não repetir.
14. Perfis de acesso (`access-profiles.create/edit/assign`) + `owner.r12-19` a `27`.
15. Segurança infantil (`child-safety.child/edit/suspend`, BE done) — sem r12-18.
16. Arquivos de Formulários › Upload + Resolver já têm prova publicada e não
    devem ser repetidos; Expirar/Excluir permanecem como fatia separada (BE + FE)
    e foram liberados para R15 sem aceite E2E remoto.

**Bloco D — integrado seletivamente no `dev`; aceite técnico preservado:**
17. OQ-031 catálogos de tipo, reader self da Conta e `owner.r12-29/30` foram
    provados pela Sessão D em produção, no branch `r14/bloco-cd`, SHA
    `b135c8f20`: pgTAP remoto 11/11, 6/6 e 6/6, respectivamente. As coleções
    aceitam registros independentes e rejeitam o 101º por entidade/coleção.
    Os artefatos foram integrados seletivamente ao `dev`; a evidência continua
    registrada sem novo delta de contador. H08/H13/H23 foram transferidos para
    R15 por decisão do Owner, sem inventar contrato ausente. Reader de Planos
    comerciais e recuperação/reset de Auth não entram na R14.

**Bloco E — mais caros (contrato novo ou reconstrução):**
18. Conta: A+ do layout "Meu acesso" + foto R2 (`account.profile`). O pacote
    técnico da Sessão E foi integrado; o residual produtivo de `owner.r12-46`
    permanece sem captura adicional de cabeçalho/avatar em nova sessão. Recuperação/
    redefinição (`auth.recover/reset`) ficam reservadas para a Etapa 3.
19. Circular `H04` (host + goldens); Formulários `H10` (+ `H11` só se >60% pronto); Principal `H27/P54/H02`.
20. Chat › Anexar (`chat.attach`: asset_id + Edge Function); Agora e Momentos (mídia R2/Stream real); Agora › Remover (`agora.remove`: remoção imediata);
    `owner.r12-33` medicação; `owner.r12-18` pessoa sem conta; páginas de erro (BE/E2E).
21. Gates de medição: `H03`, `H07`, `H09`, `H12`, `H14`, `H16`, `H18`–`H20`, `H22`, `H24`–`H26`, `H28`.

`agora.remove` foi formalizado pela ADR 0040 como ação MVP separada: remoção
explícita imediata, revogação no catálogo/gateway e purge idempotente do objeto
R2 e da cópia Stream, preservando catálogo/recibo/auditoria. O pacote e a prova
produtiva positiva foram integrados; o contrato local da negativa foi reforçado
em `2707086cf`, mas a negativa produtiva cross-tenant segue bloqueada pelo
helper/fixture ausente no schema remoto. O action_id permanece
`pending-verification`.

## Lote de coordenação — 16/09/2026 (Mesa do Owner, ADR 0041)

- Aceites: `owner.r12-34/35/36/37` (Cardápios), `owner.r12-09` e
  `owner.r12-11` → `done`; OQ-031 e reader self da Conta → concluídos na
  ADR 0038. `owner.r12-29/30` **não** aceitos: contrato redesenhado (§5 da
  ADR) vai para R15.
- Reclassificações aplicadas por `deltas-mesa-owner-20260916.json`:
  `institutions.files` → `deferred-post-mvp` (flyout fica e avisa "em
  desenvolvimento"); `errors.*` (6) → `flutter-only`. `institutions.error` e
  `institutions.access-denied` ficam no MVP e precisam de prova.
- Contratos decididos (B1–B9) entram nos gates das linhas de Owner abaixo;
  H11 (autosave) sai do MVP para V1 (B10).
- Autorizações de produção concedidas: leitura OQ-046 (D1), renomear carimbo do
  Chat (D2), migration de escopo de `attendance_context_options` (D3),
  diagnóstico + correção do 504 de Segurança infantil (D4), fixture cross-tenant
  do Agora (D5). Negada: massa fictícia de alunos (D6).
- Ambiente: credenciais QA existem em `Coelo-backups/qa-r06-*.env` e
  `supabase/usuario/` (local, ignorado pelo Git); Docker ficará ligado (D8).
- Goldens: falhas de Segurança da criança/Perfis/Rotina são deriva do cabeçalho
  global; regravar referências só após estabilizar o cabeçalho (C1).
- 16/09, coordenação: OQ-046 **resolvida** (D1/D2 executadas; lote 72 em
  `ordem-de-aplicacao-producao.txt`; evidência em
  `r14-coordenacao/oq-046-ledger-reconciliacao-20260916.md`). Segunda onda
  aberta com quatro sessões filhas (5–8) em worktrees próprias; ver
  `R14-execucao-paralela.md`.
- 16/09, integração da segunda onda (cherry-pick em `dev`): Sessão 5
  (`access-profiles.create` verified-e2e; FE de Perfis traduz módulo › tela ›
  ação e desdobra ações repetidas; flyout Arquivos de Instituições avisa "em
  desenvolvimento" — A4), Sessão 6 (lote 73: `20260915203000` aplicada em
  produção pelo rito; nenhum action_id), Sessão 7 (`agora.create`/`agora.view`
  verified-e2e; `agora.publish`/`expire` BE done; rota de remoção no FE
  local-green), Sessão 8 (causa do 504 de `child_safety_change_lifecycle`
  observada: `raise serialization_failure` 40001 reexecutado sem limite pelo
  PostgREST 14.5; migrations D3/D4 prontas com pgTAP verde no espelho,
  **não aplicadas** — `db query --linked` negado pelo executor; OQ-047).
- **Incidente de produção (16/09, ~12:28 BRT em diante)**: PostgREST devolve
  `504 PGRST003` (pool esgotado) para todas as RPCs; `pg_stat_activity` (leitura
  D1) mostra as conexões ocupadas por laços de retentativa de
  `child_safety_change_lifecycle`, remoção/purge do Agora e Momentos. Bloqueou
  as provas de rota real das Sessões 5, 6 e 7 (causa: ambiente). Mitigação
  depende do Owner: aplicar `20260916152000` (encerra o laço de child_safety)
  e/ou reiniciar o PostgREST; correção sistêmica em OQ-047.

## Lote de coordenação — 15/09/2026

- `assessments.close` e `assessments.reopen`: delta oficial aplicado pela
  Sessão C; inventário agora registra `verified-e2e` e a dupla não deve ser
  repetida.
- `access-profiles.create/edit/assign`, `child-safety.create/edit/suspend` e
  `owner.r12-13/15/16/19–27`: testes/diagnósticos das Sessões C e C contínua
  não obtiveram rota produtiva certificável; 504, sessão/CORS/CDP, drift de
  massa e ausência de autorização continuam bloqueios. Permanecem fora dos
  contadores e são liberados para a próxima rodada conforme R15/R16 abaixo.
- `forms.expire-file`/`forms.delete-file`: commits `0481384f5` e `ca4bf4cd3`
  corrigem/auditam a lógica e passam as suítes direcionadas (Deno 56/56 e
  Flutter 89/89), mas não houve sessão autenticada, persistência remota,
  reload e negativa produtiva. Liberados para R15; não promover.
- `owner.r12-05` no contexto Atividade: `14f6facab` registrou o bloqueio
  isolado da RPC/massa; o contexto Turma já certificado não foi repetido. R15
  precisa alinhar a massa QA ou corrigir a RPC com contrato antes da prova.
- Sessão E: `agora.remove` teve o contrato local reforçado em `2707086cf`, sem
  substituir a prova produtiva negativa. Stream genérico continua sem contrato
  próprio. Nenhum desses pontos altera o inventário sem delta oficial.

## Aprovação visual do Owner — 14/09/2026 (artefato 5218230f, SHA a952f3ff9) — 6/6 decididas: 5 A, 1 A+

| Tela | action_ids | Decisão | Observação / gate |
|---|---|---|---|
| Estrutura › Turmas › Diretório | groups.list | **A** | — |
| Atividades › Lançar avaliações | assessments.entry/gradebook/detail | **A** | — |
| Saúde e Cuidado › Planos de medicação | medication.list/create/detail/edit | **A** | — |
| Cabeçalho › Meu perfil | account.profile | **A+** | Owner: "o contêiner do Meu Acesso pode ficar na mesma linha que Dados pessoais e ter a rolagem para ir descendo" → correção de layout obrigatória (coelo-ui), entra em `owner.r12-46`. |
| Atividades › Configuração avaliativa | activities.assessment | **A** | — |
| Saúde e Cuidado › Perfis de cuidado | health-care.create/detail/edit | **A** | — |

## Owner items — abertos/parciais e atualizações da execução (32)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | partial / FE local-green (S9 16/09): cards sobre `CoeloAdminCardGrid` (grade de altura uniforme extraída do composto para coelo_ui_admin), linha "Efetivo: —" sempre presente e Arquivar em todos os cards (Restaurar no arquivado, B1); teste de widget 4/4 nos três pontos, pasta 119/119, golden regravado após o cabeçalho (C1). / Sem SQL/RPC novo nesta fatia; o efeito de Arquivar/Restaurar depende da fatia B1 (owner.r12-02). / Pendente: rota real (captura 1440 + reload). | docs/reviews/evidence/etapa-2/r14-sessao-9/daily-routine-cards-r12-01-20260916.md; docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md | Capturar na rota real quando o PostgREST voltar; B1 (r12-02) dá efeito a Arquivar/Restaurar. |
| owner.r12-02 | activities.list, daily-routine.list | partial / FE local-green (S9 16/09): Atividades › Modelos com aba Arquivados, Arquivar/Restaurar com confirmação e recarga (leitor v1); Rotina › Modelos com filtro Arquivados e comandos v1 no router; testes 6/6 + 6/6 + 3 + 1. / BE local-green (espelho): spec 054 + migration `20260916193000_archive_models_v1` (RPCs `superadmin_activity_template_archive_v1/_restore_v1/_directory_v1`, `superadmin_routine_model_archive_v1/_restore_v1`, diretório de Rotina exclui arquivados por padrão; PT409, recibo, auditoria, RLS deny-by-default) + pgTAP 63/63; **não aplicada em produção**. / Pendente: aplicação em produção pelo rito e rota real dos dois diretórios (Arquivar, Restaurar, filtro, reload, negativa). | docs/reviews/evidence/etapa-2/r14-sessao-9/archive-models-b1-20260916.md; specs/054-archive-activity-routine-models.md | Coordenadora: aplicar `20260916183000` pelo rito (espelho verde, dump prévio, dry-run, ledger, lote) e provar na rota real; depois delta FE/BE/E2E. Restaurar de rotinas aplicadas fica para a spec de ciclo de vida (R15). |
| owner.r12-04 | daily-routine.list, attendance.dashboard | partial / FE local-green (Sessão 10, 16/09): tela Acompanhamento › Assiduidade › Histórico em `/attendance/history` (tabela data/turma-atividade/quem lançou/presentes/ausentes/rotina/situação, filtros instituição/unidade/turma/atividade/situação/período, cursor, abre o detalhe; sem edição); aba Lançamentos retirada do diretório de Rotina (Lançar hoje → Histórico › Lançamentos de rotina); 280 testes verdes, 10 goldens pré-existentes (C1). / BE local-green: `20260916180000_attendance_call_history_v1` (leitor por cursor com escopo do painel, só agregados) + pgTAP 44/44 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, rota real autenticada, reload e negativa cross-tenant (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-history-20260916.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916180000` pelo rito (espelho verde) após o fim do incidente; provar `/attendance/history` com `qa-r06-operacoes`, reload e negativa; decidir se Publicar lançamento fica no Histórico ou volta a Rotinas (spec 052 §3). |
| owner.r12-05 | attendance.create | partial / FE verified (rota real 15/09): cascata Instituição/Unidade/Turma/Contexto com contexto real, data, chamada criada e relida. / BE done; `superadmin_attendance_context_options` devolve a única atividade elegível (95b98978) com escopo 190dd028/f5284f2f/4214106c ausente das listas institutions/units/groups — inconsistência de escopo na RPC ou de massa. / verified-e2e de attendance.create com contexto Turma; contexto Atividade não exercitável. Bloqueio isolado confirmado em `14f6facab`. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md; docs/reviews/evidence/etapa-2/r14-coordenacao/attendance-activity-blocked-20260915.md | ADR 0041 D3: autorizada migration forward-only alinhando escopo de activities ao de groups em superadmin_attendance_context_options (espelho + pgTAP antes); depois provar seleção, criação, reload e negativa do contexto Atividade. |
| owner.r12-06 | attendance.create, daily-routine.apply | partial / FE local-green (Sessão 10, 16/09): detalhe da chamada e Histórico mostram a rotina (snapshot "registrada na conclusão"; aberta = vigente; legado concluído sem snapshot = "rotina atual (não registrada na época)"); repositório mapeia PT409; FE verified anterior (wizard sem etapa de rotina) preservado. / BE local-green: `20260916183000_attendance_routine_snapshot_v1` (colunas de snapshot, `attendance_effective_routine`, complete_call grava só na primeira conclusão, call_detail expõe routine_snapshot/routine_current/routine_source, histórico projeta a rotina, 40001 → PT409 na família) + pgTAP 43/43 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, concluir/reabrir chamada real, reload do detalhe e negativa 409 PT409 (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-routine-snapshot-20260916.md; docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916183000` pelo rito após `20260916180000` e o fim do incidente; provar na rota real: concluir grava snapshot, reabrir/concluir preserva, legado mostra a indicação; negativa de versão defasada responde 409 PT409. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | partial / FE verified em mark/finish na rota real 15/09 (chamada cd60f2d8: presente salvo, reload, concluída). / Contratos preservados; set_participant v2 e complete_call v3 em produção. / Pendente só a massa: as turmas do escopo têm no máximo 1 aluno; múltiplos alunos/turmas e rotina vinculada não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md | ADR 0041 D6: Owner não autoriza massa fictícia agora; prova com ≥2 alunos fica para depois. Bloqueado por decisão, não por ambiente. |
| owner.r12-10 | child-safety.list | partial / FE local-green (S9 16/09): causa da deriva observada no shell (`3945394f3` trocou a identidade estática por `headerProfile` da sessão; sem host o golden renderizava o placeholder `–`/`Conta`); cabeçalho estabilizado por `SuperadminHeaderProfileScope` + `SuperadminHeaderProfile.preview()` e golden `child_safety_directory_light_1440` regravado (C1), suíte 30/30 verde. / Contrato preservado; nenhum SQL/RPC novo. / Pendente: rota real da tabela e revisão contra a Table canônica. | docs/reviews/evidence/etapa-2/r14-sessao-9/goldens-cabecalho-global-20260916.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-table-golden-diagnostic-r12.md | Revisar a tabela do diretório contra a Table canônica e capturar na rota real quando o PostgREST voltar; golden não certifica aceite. |
| owner.r12-13 | child-safety.create, child-safety.edit | open / Wizard já usa FormFrame, painel único por etapa, grupos e rodapé canônicos; testes funcionais do wizard passam. / Contrato preservado; nenhum SQL/RPC novo. / Visual/E2E pendente para referência, rota normal, escopo e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-composition-r12.md | ADR 0041 D4: autorizados diagnóstico e correção forward-only do 504 de child_safety_change_lifecycle; depois provar create/edit pela rota normal. |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | partial / FE verified no estado suspenso (rota real 15/09): diálogo com identidade, contexto, relação, capacidades, motivo, decisão, situação, validade e só Concluir. / BE: child_safety_change_lifecycle responde 504 (timeout) em produção — bloqueio para Sessão 2 (SQL/espelho). / child verified-e2e; suspend blocked-backend; estados pendente e aprovado-ativo não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-manage-context-r12.md | ADR 0041 D4: autorizados diagnóstico e correção forward-only do 504; depois criar autorização, aprovar e suspender pela tela para fechar r12-15/13/16. |
| owner.r12-16 | child-safety.create | open / FE local-green: stepper bloqueia salto para etapa futura e permite retorno às concluídas; testes do wizard cobrem o fluxo. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification de rota normal e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 D4: depende do 504; depois provar teclado/rota normal sem salto e sem perda de dados. |
| owner.r12-17 | child-safety.create, child-safety.edit | open / Diagnóstico: campo atual ainda aceita identificador/UUID técnico; não existe contrato de busca autorizada por nome, CPF, e-mail ou celular. / Sem alteração backend; não criar busca fake. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 B5: leitor de busca único (nome/@/e-mail ≥3, celular ≥4, CPF ≥6 dígitos, com ou sem máscara), escopo do ator, auditoria, limite de taxa, resultado minimizado sem CPF; responsável lista crianças vinculadas do escopo. Contrato aprovado; implementar BE + FE. |
| owner.r12-18 | child-safety.create | open / Diagnóstico: pessoa global sem conta e campos mínimos/deduplicação não têm contrato definido. / Nenhuma tabela/RPC criada. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 B6: pessoa sem conta com CPF obrigatório, documento + imagem (R2 privado) no MVP, celular/e-mail; autorizada só no contexto pedido; pode virar conta depois. Cadastro só após a busca B5 não encontrar. |
| owner.r12-19 | gate/mapeamento pendente | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/archive/rounds/R12/R12-perfis-permissoes-owner.md | ADR 0041 B7: perfil transversal/funcionário no Principal vira spec própria na R15 (OQ-044). Na R14, provar somente o diretório atual (r12-20/21) sem tocar no conflito. |
| owner.r12-20 | access-profiles.list | partial / FE verified na rota real (S5 16/09): 8 cards após reload com Status, Escopo máximo, Vínculos e Tipo (ADR 0041 C2). / BE inalterado. / E2E pending-verification: negativa de escopo só por id inexistente/capability inválida (perfis Superadmin não têm tenant). | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Conferir rolagem da terceira linha de cards em viewport baixo (não rolou por CDP) e registrar a negativa aceita; Owner decide se "Vínculos 0" (platform_memberships) é a métrica certa para usuários internos. |
| owner.r12-21 | access-profiles.detail | partial / FE corrigido (89be705fa/63ec6e973): módulo › tela › ação traduzidos a partir do catálogo real (module_label/screen_label/action_label + tradução local), telas com ações repetidas desdobradas; visto na rota real de criação (S5 16/09). / BE inalterado; catálogo devolve rótulos em inglês e `CardÃ¡pios` (resíduo). / E2E pending-verification (detalhe bloqueado por PGRST003). | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Abrir /profiles/platform/281699f2… no build 63ec6e973, capturar detalhe traduzido e reload. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | partial / FE verified: criação pela rota real sem campo Código; identificador gerado pelo servidor (`r14-s5-perfil-qa-46749519`). / BE done (create). / E2E verified-e2e para create (S5 16/09); edição bloqueada por PGRST003. | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Provar edição pela rota normal (renomear/alterar permissão), persistência/reload. |
| owner.r12-23 | access-profiles.create | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/archive/rounds/R12/R12-perfis-permissoes-owner.md | ADR 0041 B7: transferido para spec própria na R15 (OQ-044). Não executar na R14. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | partial / FE: tooltip de sensibilidade visto na rota real por hover (crítica: "Ação sensível…"); em 63ec6e973 aparece também por foco de teclado e explica risco elevado (teste de widget). / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Capturar tooltip por foco no build 63ec6e973 na rota real de edição. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | partial / FE: matriz alinhada (colunas por ação) e empilhada quando não cabe, agora sem esconder permissões com a mesma ação (desdobra por alvo) e sem estouro do cabeçalho em tela estreita (teste 1440/600). Visto na rota real em 1440 (S5 16/09). / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Capturar ~600 px (Emulation.setDeviceMetricsOverride) na rota real e persistência/reload. |
| owner.r12-26 | access-profiles.edit | partial / FE local-green: Continuar habilitado é FilledButton preenchido também na edição. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-form-r12-22-26.md | ADR 0041 C4: Owner aceitou a prova de FE em teste; captura na rota real entra junto do lote de Perfis (sessão QA D7). |
| owner.r12-27 | access-profiles.create, access-profiles.edit | partial / FE: revisão mostra módulo › tela › nome do catálogo ("Acessos › Modelos de perfil › Consultar modelos Admin."), motivo de indisponibilidade e texto configuração × acesso efetivo; visto na rota real de criação (S5 16/09; a seta → era tofu na fonte web, trocada por › em 63ec6e973). / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r14-sessao-5/access-profiles-20260916.md | Salvar/reload na edição sem perder permissões; capturar revisão com › no build 63ec6e973. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de alergias, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/archive/rounds/R14/R14-handoff-sessao-2.md | ADR 0041 A2/§5: não aceito ainda — Owner quer prova com mais registros e redesenhou o contrato (wizard Alimentos × Restrições, nome de lista categorizada, reordenar, "O que fazer se consumido?"). Spec para R15; coleção + limite 100 já em produção são a base. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de orientações, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/archive/rounds/R14/R14-handoff-sessao-2.md | ADR 0041 A2/§5: idem r12-29 para orientações de cuidado (lista pré-definida, reordenar). Spec para R15. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | partial / FE local-green (Sessão 10, 16/09): sino já lia `context_notification_*`; rótulos para plano criado/atualizado/status e dose registrada (resumo por desfecho). / BE local-green: `20260916190000_medication_in_app_notifications_v1` (destinatários = admins da unidade + educadores da turma, sem responsáveis; editar plano → `medication.plan.updated`; cada dose → `medication.dose.recorded`; `not_tracked` silencia) + pgTAP 29/29 no espelho; criar plano já notificava em produção (trigger existente, audiência mantida); NÃO aplicada em produção. / Pendente: aplicar a migration, editar plano e registrar dose reais e observar o sino com identidade da unidade/educador (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/medication-notifications-20260916.md; specs/053-superadmin-medication-in-app-notifications.md | Aplicar `20260916190000` pelo rito após o incidente; provar o sino na rota real com duas identidades (admin da unidade e educador da turma); sem e-mail/push. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | open / FE mantém envio desabilitado. / Adapter composto ainda usa Supabase Storage em upload/leitura, incompatível com R2 privado. / E2E não executado. | docs/reviews/archive/rounds/R12/R12-cardapios-owner.md | C0 migrar SupabaseMealPlanImageRepository e contratos de vínculo para Media Gateway R2; depois habilitar composição e provar upload/reload/escopo. Não é apenas flag. |
| owner.r12-39 | forms.edit, forms.create | partial / FE local-green: arraste/movimentação e alternativas por botões preservadas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar save/reload e posição final pela rota normal. |
| owner.r12-40 | forms.edit, forms.create | partial / FE local-green: seção pode ser renomeada por diálogo e o draft é atualizado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar persistência/reload e nome na prévia pela rota normal. |
| owner.r12-46 | account.profile | partial / FE verified (rota real 14/09): sigla QE→QR salva e relida após reload, celular e cor exibidos. / BE remote-green (lote 63): sigla/cor/celular em produção; foto R2 ausente. / E2E aberto até a foto privada (R2) existir no BE. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. A confirmação deve atualizar também o avatar global do cabeçalho; rascunho local não pode aparentar sucesso quando o servidor não confirmou. O Celular permanece obrigatório e precisa de máscara/formato de entrada, normalização e prova de valor inválido/válido. Aprovação visual 14/09: A+ — colocar o card "Meu acesso" na mesma linha de "Dados pessoais" com rolagem interna (coelo-ui), depois foto R2. |
| owner.r12-47 | auth.recover, auth.reset | open / Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Transferido para Etapa 3 pela ADR 0039; não executar na R14. Quando aberto, obter acesso/configuração de caixa/SMTP/redirect e provar link real, nova senha/sessão, expiração e uso único; preservar credencial QA privada. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | partial / FE verified em entry/gradebook/detail (rota real 14/09): participante listada, nota 8.5 salva e relida. / BE done em entry/gradebook/detail (lote 63 + save pela tela); close/reopen local-green. / verified-e2e em entry/gradebook/detail; close/reopen pendentes na rota real. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-52 | chat.attach | partial / FE local-green: mosaico por mensagem para múltiplas mídias visuais, contador de adicionais, tile único e anexos não visuais preservados. / Sem mudança backend; R2 privado, ownership e autorização existentes preservados. / Pending-verification: faltam rota normal, mídia R2/MP4 real, reload e negativa cross-tenant. | docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Abrir rota normal QA, provar mídia privada real, reload e negativa cross-tenant; não promover por fixture. |
| owner.r12-53 | gate/mapeamento pendente | open / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Não promover `institutions.status` ou `institutions.locations-map` na R14: estão fora do MVP/escopo ativo. OQ-034 (Locais com mapa por imagem) fica preparado para a R15, sem abrir outro macrotema. |

## Owner items — concluídos (21; não voltam à execução)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2; imagem R2 segue em owner.r12-38. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-09 | child-safety.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-directory-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou o card atual sem campo alerta/restrição (ADR 0041 B4). |
| owner.r12-11 | gate/mapeamento pendente | done / Cards já têm situação + Escopo máximo/Vínculos/Tipo em composição compacta; pages 15/15 PASS. / Contrato preservado; nenhum SQL/RPC novo. / Visual golden pendente de reconciliação; sem action_id novo. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-cards-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou a composição atual dos cards (ADR 0041 C2); golden regrava com o cabeçalho (C1). |
| owner.r12-03 | activities.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/activities-list-publish-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md | Concluído 15/09 (rota real, Sessão 1): abas "Modelos de atividade"/"Atividades", busca, filtros, cards/tabela, status, paginação e reload com dados reais; negativa por id inexistente e escopo pgTAP. |
| owner.r12-07 | attendance.mark, attendance.correct, attendance.finish | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-12 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-authorization-status-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela distingue "Aprovado · Suspensa" e mantém validade com dados reais; reload e negativa P0002. Golden 1440 permanece em r12-10. |
| owner.r12-14 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-relationship-r12.md | Concluído 15/09 (rota real, Sessão 1): mother/father reais exibidos como Mãe/Pai na tabela e no diálogo, em pt-BR, com dados de produção. |
| owner.r12-28 | health-care.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): edição com o nome real da criança (correção 165d3df8c), sinal salvo (version 1→2) e relido após reload. |
| owner.r12-31 | medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): criação Paracetamol R13 (10 ml, oral, vigência, 08:00, Seg/Qua) e edição da dose 5→7 ml da Dipirona R06, persistidas e relidas. Responsável depende de owner.r12-33 (R14). |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): diretório lista os planos reais por criança com contexto explícito; detalhe/criação/edição provados e relidos. |
| owner.r12-41 | forms.list | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-42 | agenda.request | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/agenda-request-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/agenda-approvals-r12-42.md | Concluído 15/09 (rota real, Sessão 1): tabela canônica, decisão aprovar/recusar com justificativa, histórico em diálogo, reload e negativa; defeito de rótulos pós-decisão corrigido (teste vermelho→verde). Golden de calendário loading dark 375 fica fora deste action_id. |
| owner.r12-43 | chat.open | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-44 | invites.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela-only, busca/filtros/paginação/Novo convite/ações por linha, reload; convite real expirado e renovado na mesma tabela. |
| owner.r12-45 | invites.resend | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md | Concluído 15/09 (rota real, Sessão 1): convite expirado real (emitido com 1 h por RPC autorizada), reenviado uma vez pela tela, link de uso único (mascarado), reload e negativas SAI_INVALID_ARGUMENT/SAI_CONCURRENT_CHANGE; sem SMTP. |
| owner.r12-48 | activities.assessment, activities.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): rascunho b04c879e carregado e salvo pela tela (version 2→3), reload relê, negativa por id inexistente; activities.publish já era done. Capturas em r13-coordenacao/capturas. |
| owner.r12-50 | groups.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): /groups com Alunos 1 e Atividades 3 na turma 4214106c, busca "R05" (hotfix lote 64), reload mantém, negativa por instituição alheia. Capturas em r13-coordenacao/capturas. |
| owner.r12-51 | gate/mapeamento pendente | done / Não aplicável. / Done (lote 63, 14/09): quatro candidatos aplicados em produção com dump SHA-256, espelho e pgTAP verdes, ledger 283→287. / Não aplicável. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/archive/rounds/R12/R12-pendencias-herdadas-R11.md | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |

## Sobra preparada para a R15 (R15 ainda não aberta)

Esta seção é uma transferência preparada, não uma nova fila executável. Os itens
continuam visíveis para não serem confundidos com referências vigentes nem
reexecutados sem nova abertura do Owner:

- `owner.r12-05`: corrigir a inconsistência de escopo em
  `superadmin_attendance_context_options` e provar o contexto Atividade;
- `owner.r12-06`: definir o contrato de leitura da rotina efetiva, versão e
  snapshot em `superadmin_attendance_call_detail`;
- `owner.r12-08`: ampliar a massa para pelo menos dois alunos e repetir o fluxo;
- `owner.r12-15`, `r12-13` e `r12-16`: diagnosticar o 504 de
  `child_safety_change_lifecycle`, depois provar create/edit/suspend;
- `owner.r12-19` a `r12-27`: executar Perfis de acesso após a reivindicação da
  Sessão C, preservando as rotas reais `/profiles` e
  `/internal-users/:id/edit`;
- Formulários: `forms.upload` e `forms.resolve-file` têm prova publicada e não
  devem ser repetidos. `forms.expire-file` e `forms.delete-file` estão
  explicitamente liberados para R15 após os commits `0481384f5`/`ca4bf4cd3`,
  sem promoção E2E;
- Principal: corrigir a indicação de contexto ativo após “Ver como”;
- `owner.r12-38` e `owner.r12-46`: migrar/provar imagem privada R2 de Cardápios
  e Conta, incluindo o layout A+ do “Meu acesso”;
- ADR 0041 (16/09): spec própria de perfil transversal/funcionário no Principal
  (`owner.r12-19/23`, OQ-044) e spec redesenhada de Perfis de cuidado
  (`owner.r12-29/30`, §5 da ADR) — ambas R15, sem execução na R14;
- demais H, `chat.attach`, `owner.r12-33` e os gates de medição seguem
  na ordem da R14. Não abrir Planos comerciais, reader de Planos ou Auth
  recovery/reset; estes continuam fora da R14 conforme ADR 0039.

## R16 preparado — não aberto

Registro de bloqueios e itens sem certificação após a Sessão E. R16 não está
aberta, não cria `action_id` e não autoriza novas provas.

- `agora.remove`: a negativa cross-tenant foi tentada e bloqueada porque o
  helper remoto de fixture não existe no schema vinculado e a preparação SQL
  falhou antes da publicação; identidades temporárias foram removidas. O
  contrato local foi reforçado no commit `2707086cf` e o pgTAP comportamental
  local de não-mutação foi adicionado em `5ae79bef1`, mas nenhum dos dois é
  prova produtiva. Evidência em `agora-remove-cross-tenant-blocked-20260915.md`,
  commit `8ac946b3a`, e em `agora-remove-cross-tenant-local-behavior-20260915.md`.
  Stream genérico permanece sem contrato, Edge, segredo, fixture e critério de
  aceite; o pacote atual comprova R2 privado e `stream_status=not_applicable`.
- `owner.r12-46`: pacote técnico e prova local existem, mas falta captura
  produtiva explícita do cabeçalho/avatar em nova sessão, com reload e save
  confirmado.
- H10/H11: regras de audiência preservadas, porém sem aceite remoto; autosave
  não tem prova remota acima de 60% e permanece V1 se esse limiar não for
  demonstrado.
- Circular, Principal, páginas de erro e H03, H04, H07, H09, H12, H14, H16,
  H18–H20, H22, H24–H26 e H28 continuam sem combinação executável de
  `action_id`, contrato e evidência. H08, H13 e H23 continuam transferidos sem
  contrato produtivo do item relacionado e sem `action_id` próprio.
- Resíduos da Sessão C ainda não certificados para redistribuição:
  `access-profiles.create/edit/assign`, `child-safety.create/edit/suspend` e
  `owner.r12-13/15/16/19–27`. Evidências bloqueadas foram integradas em
  `82d1efbad` (Segurança infantil) e `d65840efe` (Perfis). O 504 de
  `child_safety_change_lifecycle`, sessão QA/CORS/CDP indisponíveis, drift de
  massa e ausência de autorização permanecem bloqueios. Forms
  `expire-file/delete-file` foi liberado para R15 após `ca4bf4cd3`; não é
  resíduo aberto de R16.
- `owner.r12-05` no contexto Atividade foi isolado em `14f6facab` e liberado
  para R15; o caminho certificado de Turma permanece intacto.
- `auth.recover`, `auth.reset`, SMTP, provedor e allowlist de recuperação seguem
  fora da R14/R15/R16 até a abertura da Etapa 3.
- Gate de reconciliação do ledger (16/09, OQ-046): `ordem-de-aplicacao-producao.txt`
  recebeu o lote 71 (fixture QA Chat + `agora.remove`, ledger 297–301) e perdeu
  a linha não aplicada de `forms_question_media_expire_audit_v1`. Account
  `20260915120000` e Chat `20260915130000` (carimbo colidindo com o lote 70)
  seguem declarados pela Sessão E sem linha própria no ledger; e a função de
  fixture consta aplicada mas foi reportada ausente do schema remoto. Confirmar
  por metadados antes de qualquer espelho, R16 ou nova negativa do Agora.

## Resíduos H (herdados de R01–R07) — abertos (19)

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H02 | noturna/R01 | Atualização oficial a partir do Sobre | Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | Composição das quatro abas de Perfil | Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | Compositor produtivo de Circular e blocos intercalados | Unificar host e provar na rota normal. |
| H07 | noturna/R01 | Hash de edição/revogação sem `conversation_id` | Executar replay/contexto na revisão de segurança. |
| H09 | R04/R06 | Disparo agendado de expiração Agora | Medir trigger real; leitura não basta. |
| H10 | noturna/R01 | Múltiplas regras de audiência em Formulários | Decidido (ADR 0038): preservar todas as regras de audiência. Próximo gate: editor lista/edita regras sem perder as demais + teste. |
| H12 | noturna/R01 | Controles de mínimo/máximo de seleção | Localizar contrato e registrar aceite. |
| H14 | R06 | Sino sem `action_id`/subaceite | Mapear ao action_id-pai sem novo denominador. |
| H16 | R06 | Leitura people-based de cuidado | Provar escopo entre unidades. |
| H18 | R06 | Unicidade global concorrente de `@` | Revisar concorrência entre tabelas. |
| H19 | R06 | Responsável vazio em Medicação | Reproduzir com contexto e destinatário válidos. |
| H20 | R06 | Imagem da dose sem gateway | Localizar consumidor e obter prova específica. |
| H21 | R07 | Limite de texto/rodapé de Circular | Parcial em 14/09: **backend concluído (lote 68)** — `save_draft_v2` e constraint de `circular_revisions` em 4.000 somando blocos de texto; pgTAP 10/10; produção recusa 4.001 (`CIRCULAR_INVALID_INPUT`). Cliente `CircularLimits.bodyCharacters = 4000` (contador já somava blocos). Falta H04: host/rodapé em card/Opções conforme referência e regravação dos goldens web (18 goldens de circular já falhavam antes desta mudança). |
| H22 | noturna/R01 | Descritor privado de Circular | Alinhar à ADR 0032 e provar ausência de bucket público. |
| H24 | noturna/R01 | Rótulos do Sobre | Comparar com referência vigente. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | Medir teclado, semântica e toque. |
| H26 | noturna/R01 | Opcional, escala legada e opções vazias | Reconciliar contrato atual por caso. |
| H27 | noturna/R01 | Sinal de atualização de Momentos | Decidido (ADR 0038): saudação por hora do dia; ponto laranja na aba Momentos quando há momento não visto. Próximo gate: implementar no Principal + prova. |
| H28 | R01 | Filtros, avatar e buffers de Pessoas | Rever somente diferenças funcionais persistentes. |

## Resíduos H — transferidos (4: H08/H13/H23 → R15; H11 → V1)

| ID | Origem | Motivo da transferência |
|---|---|---|
| H11 | noturna/R01 | **V1** por decisão do Owner em 16/09 (ADR 0041 B10): autosave de autoria de Formulários sai do MVP sem medir o limiar de 60%; testes locais preservados, nenhum aceite remoto exigido. |
| H08 | R02 | Autorizado pelo Owner em 15/09; falta contrato produtivo do item a duplicar e `action_id`, portanto não inventar RPC, payload ou coluna na R14. |
| H13 | noturna/R01 | Autorizado pelo Owner em 15/09; falta referência produtiva de item relacionado e `action_id` para o CTA. |
| H23 | noturna/R01 | Autorizado pelo Owner em 15/09; implementação visual depende do contrato de Avisos que será definido junto com H08/H13 na R15. |

## Resíduos H — concluídos (4)

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | Decidido (ADR 0038): recibos contam participantes ativos atuais. Fechado sem mudança; aceite MVP mantido. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | **Concluído em 14/09 (lote 65)**: `superadmin_chat_revoke_message_v2` recusa `CHAT_READ_ONLY` no servidor; pgTAP 14/14 + suíte base 36/36 no espelho; guard presente em produção; negativa `CHAT_NOT_FOUND` por RPC. `chat.revoke` já era verified-e2e; sem delta de estado. |
| H17 | R06 | Papel fixo versus capacidade em cuidado | **Concluído em 14/09 (lote 66)**: capacidade `care_policies.manage` nos catálogos Superadmin (Owner) e Admin (Administrador da instituição); `superadmin_unit_care_policy_set_v1` exige só a capacidade; pgTAP 15/15 + base 20/20; get/set/reload em produção na unidade f5284f2f e negativa por unidade alheia. Sem action_id próprio no inventário (sem tela no cliente); sem delta de estado. |
| H15 | R06 | Atribuição de Plano | **Concluído por decisão de escopo:** `plans.assign` fica fora do MVP; botão e operação permanecem honestamente indisponíveis. |

## Itens da ADR 0038 sem ID H nem Owner item — abertos (2) e transferidos (2)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Identidade da mídia do Chat (`asset_id` no envelope) | Aberto | Pacote SQL aditivo em `authorize_read` + deploy da Edge Function `chat-media`; re-provar E2E do chat. |
| Reader de Planos comerciais no Principal (039) | Transferido para V1/V2 | Não executar na R14; preservar contrato e IDs como preparação futura. `units_with_override` só deve ser calculado quando o Owner abrir o escopo. |
| Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | Aberto | Verificar contrato atual de `form_publish`/resposta; pacote só se faltar. |
| Auth: localhost na allowlist de redirect (R12-47) | Transferido para Etapa 3 | Não executar na R14; pertence ao contrato futuro de recuperação/reset, com ambiente e prova próprios. |

## Itens da ADR 0038 — concluídos (4)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Catálogos globais de tipo (OQ-031) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915131500` em produção e confirmou pgTAP remoto 11/11, quatro catálogos com oito entradas e "Outros"; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Reader self da Conta (039) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915133000` em produção e confirmou pgTAP remoto 6/6, sessão autenticada e ausência de sobrecarga por UUID; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Anexos por mensagem no Chat (10 por envio) | **Concluído em 14/09 (lote 67)** | `superadmin_chat_attachment_prepare_v1` recusa o 11º pendente com `CHAT_ATTACHMENT_LIMIT` (422); pgTAP 9/9 + base 28/28; produção: 10 aceitos e 11º recusado na conversa 355a3403 (sintéticos arquivados); cliente mapeia `chat_attachment_limit` (243 testes do chat verdes). |
| Status de Suporte (OQ-028) | **Concluído em 14/09 (lote 69)** | `set_status` grava open/pending/resolved conforme o mapeamento A; trigger mantém `ticket_status` coerente (expired/revoked → Concluído); `closure_reason` em get/list; pgTAP 13/13 + bases 23/23, 28/28, 17/17; produção: chamado 6c5eb791 waiting→pending, completed→resolved. Cliente mostra “Concluído · Expirado/Revogado”. |

## Ações não terminais por família (inventário: 27 ações; FE/BE/E2E)

Projeção regenerada em 16/09/2026 a partir de `inventario-etapa-2.json` após a
integração das Sessões 5–8: ações `mvp`/`gate-formal-mvp` cujo estado integrado
não é `verified-e2e` nem `flutter-only`. As 30 `deferred-post-mvp` ficam fora;
`errors.409` (flutter-only, FE local-green) ainda deve provar FE na rota real.

| Família | Qtd | action_ids |
|---|---:|---|
| access_profiles | 2 | `access-profiles.edit` (local-green/done/pending-verification), `access-profiles.assign` (pending-verification/done/pending-verification) |
| account | 2 | `account.profile` (verified/remote-green/pending-verification), `account.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| agora | 3 | `agora.publish` (verified/done/pending-verification), `agora.expire` (pending-verification/done/pending-verification), `agora.remove` (local-green/pending-verification/pending-verification) |
| auth | 3 | `auth.recover` (verified/pending-verification/pending-verification), `auth.reset` (verified/pending-verification/pending-verification), `auth.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| chat | 1 | `chat.attach` (local-green/local-green/pending-verification) |
| child_safety | 2 | `child-safety.edit` (local-green/done/pending-verification), `child-safety.suspend` (local-green/done/blocked-backend) |
| forms_authoring | 2 | `forms.create` (local-green/done/pending-verification), `forms.edit` (local-green/done/pending-verification) |
| forms_files | 2 | `forms.expire-file` (pending-verification/local-green/pending-verification), `forms.delete-file` (pending-verification/local-green/pending-verification) |
| forms_responses | 1 | `forms.location-answer` (local-green/pending-verification/pending-verification) |
| institutions | 2 | `institutions.error` (pending-verification/local-green/pending-verification), `institutions.access-denied` (pending-verification/local-green/pending-verification) |
| internal_users | 1 | `internal-users.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| momentos | 4 | `momentos.view` (verified/done/pending-verification), `momentos.create` (local-green/local-green/blocked-environment), `momentos.publish` (pending-verification/local-green/pending-verification), `momentos.remove` (pending-verification/local-green/pending-verification) |
| principal_profile | 2 | `principal.for-you` (verified/blocked-decision/pending-verification), `principal.profile-edit` (local-green/blocked-decision/pending-verification) |

## Decisões de escopo do Owner (14/09 e 15/09, ver `docs/agent/backlog.md`)

Fora do MVP: operações de Planos comerciais (listar/criar/editar/arquivar/restaurar/
atribuir/vincular/entitlements), `plans.assign`, Financeiro, `institutions.status`,
`institutions.locations-map`, MFA ×3.
V1/Etapa 3: Catálogo de UI. Formulários autosave (H11): V1 se for caro, salvo se >60% pronto.
Etapa 3: `auth.recover`/`auth.reset`; 3 instituições fictícias com hierarquia para o Owner verificar "Para você" (nome a rever).
Antes do fim do MVP: perfis oficiais do Coelo (OQ-032). R15: OQ-033 (decidido em 15/09: opção B + regra de pessoas) e OQ-034 Locais com mapa por imagem (confirmado em 15/09; substitui `institutions.locations-map`).

**15/09/2026 — abertura da execução (artefato 89AVWHKEnq5hrvYN6SFv6M):** temas explicados e sete decisões registradas em `R14-execucao-paralela.md` (papéis, worktrees, portas, handoffs, Bloco B autorizado com E2E ativo 199 → 192, ordem do Bloco C e ordem original do Bloco D). A formalização posterior de `agora.remove` levou a base ativa a 193. Duas sessões executaram em paralelo; a coordenadora (Codex) atualiza este arquivo. A decisão posterior da ADR 0039 transfere recuperação/reset de Auth e a allowlist desse fluxo para a Etapa 3.

**16/09/2026 — Mesa do Owner (artefato Jrsk1XBe97MCLpeUBGAeYz, ADR 0041):** 27 decisões registradas; `institutions.files` fora do MVP; páginas de erro `flutter-only`; H11 → V1; perfil transversal e Perfis de cuidado redesenhados → specs R15; contratos B1–B9 fixados; autorizações D1–D5 concedidas, D6 negada.

## Como atualizar

- Estado por `action_id`: só via `apply-tracker-delta.cjs` com evidência certificada (inventário → três rastreadores).
- Owner items: editar a linha aqui e rodar `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
- H e itens da ADR: editar a linha aqui. Nunca editar R12/R13 (históricos).
- Validar sempre com `node docs/reviews/validate-trackers.cjs`.
- Execução paralela (sessões, worktrees, handoffs): `R14-execucao-paralela.md`. Handoffs `R14-handoff-sessao-1.md`/`-2.md` são comunicação, não fila.
