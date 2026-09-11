---
title: "Handoff — grupo formularios-cuidado-rotina, Rodada 4 (com validação de entrega)"
source: "Execução do grupo em 2026-09-10/11; comunicacao/formularios-cuidado-rotina.json revisões 23 a 33; deltas-r04-fcr.json; ledger de produção conferido em 11/09 08:4x"
status: "entregue; três candidatos SQL na fila do coordenador"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff — formularios-cuidado-rotina (Rodada 4)

Recorte: 43 ações das famílias `forms_authoring`, `forms_responses`,
`forms_files`, `health_care`, `medication`, `students`, `attendance` e
`daily_routine`. O handoff da Rodada 3 está no histórico do Git deste
arquivo (commit `1c188091f`).

## SHA final

Branch `work/etapa2-r04-formularios-cuidado-rotina`, publicada, árvore
limpa. Último commit de código: `b17eb0319` (candidatos 220600/220700/220800
em `candidatos/`), seguido do commit desta revisão (golden
`medication_form_mobile_light` regravado após o P15 e JSON rev 33). Base
`origin/dev 0376a0446` mesclada em `bbb4576f1`.

Tudo até `e5d35ad37` (rev 32) já está em `dev`. **Não estão em `dev`:** os
três candidatos SQL e a regravação do golden desta revisão.

## O que fechou, por action_id, com prova

Rota real com a sessão `qa-r03` em produção (capturas em
`docs/reviews/evidence/etapa-2/r04-formularios-cuidado-rotina/rota-real/`,
deltas em `deltas-r04-fcr.json`, 29 entradas):

| action_id | Estado proposto | Prova |
| --- | --- | --- |
| `forms.list` | verified-e2e | `/forms` abre com cabeçalho e composto; `superadmin_forms_directory` 200; reload |
| `forms.create` | verified-e2e | formulário criado na instituição sintética; `form_save_draft` 200 após dois ajustes do DTO; linha em `public.forms`; reload |
| `forms.edit` | verified-e2e | título alterado, `form_save_draft` 200 com `expected_version`; reload |
| `forms.test` | verified (FE) | `/forms/:id/test` abre a pré-visualização inerte por capacidade (D6) |
| `medication.list` | verified-e2e | `superadmin_medication_plan_directory` 200 (vazio); composto completo; reload |
| `health-care.list` | verified (FE) | diretório no composto com o ator produtivo; servidor 200 |

Backend em produção nesta rodada (aplicado pelo coordenador):

| Pacote | O que faz | pgTAP |
| --- | --- | --- |
| `20260910220400` ponte de ator | pessoa de serviço + membership espelhada por trigger; `current_person_id()` com fallback; catálogo `attendance.*`/`people.assign_children`; concessões ao Owner | 17/17 |
| `20260910220500` P16 | tipo `location` em Formulários com opções congeladas do catálogo; resposta exige local ativo | 55/55 |

Cliente integrado em `dev`: composição de produção de Perfis de cuidado e
Medicação; cabeçalho compartilhado em todas as rotas de Formulários; guarda
de mutação por localização; P16 no domínio, DTOs, editor e resposta; DTO de
formulário corrigido (id nulo e chaves desconhecidas); goldens de
Formulários, Rotina e Assiduidade regravados (Bug + realce do menu);
`medication_form_mobile_light` regravado após o P15.

## O que ficou aberto, com o primeiro gate

| Item | Primeiro gate |
| --- | --- |
| `health-care.create/detail/edit`, `medication.create/detail/edit`, `students.list` | coordenador aplica **220600** (`superadmin_child_context_directory_v2` nunca chegou à baseline; cliente recebe PGRST202) |
| `attendance.dashboard/create/mark/correct/finish` | coordenador aplica **220700** (`attendance_dashboard_access` e `superadmin_attendance_context_options` ausentes em produção); FE: compor `onCreate` no painel e migrá-lo ao composto |
| `forms.location-question/answer` | coordenador aplica **220800** (snapshot de Locais também na rota v1 `form_save_draft`) |
| `students.revoke` | decisão BE transversal: leitura diz `can_manage=true` (plataforma) e comando nega por `has_context_permission` (F-R04-FCR-008) |
| `daily-routine.create/edit/apply/publish` | FE: `canManage` derivado do diretório vazio e router sem `onCreateEntry/onEdit`; BE: `can_manage` no envelope (F-R04-FCR-009) |
| `students.link/transfer/edit`, `medication.evidence` | FE: sem UI (comandos e repositórios prontos) |
| `forms.respond` por ocorrência, card Criar de `/forms` em produção | FE: F-R04-FCR-010 a/b |
| `forms.overview/publish/monitor/responses/response-detail/responses.export` e `forms_files` (5) | sem rota real nesta rodada |
| Painel de Assiduidade e Alunos fora do composto (estado vazio) | FE do grupo |
| `forms_editor_*_1440` divergem já na base (9–11%) | decisão do Owner |

Os três candidatos estão em
`packages/coelo_database/candidatos/formularios-cuidado-rotina/`, provados
em 11/09 08:4x no espelho `coelo_baseline_p16`: 45/45, 22/22 e 8/8.

## Dados sintéticos em produção (P37)

Prefixo `d0c40000-` (instituição "QA R04 Cuidado (sintetico)", unidade,
criança, vínculo), formulário `4555ba07-e4a4-4971-8ba7-d81a775169cd`, local
`fc446535-100c-4f35-8e30-e43d63176e3f`. Os quatro primeiros foram criados por
`insert` direto antes da regra "nunca por insert direto" existir. Limpeza por
script único provado no espelho, depois do "P37 aprovado".

## Achados que valem para as skills

Registrados em `formularios-cuidado-rotina.json` →
`propostaDeAtualizacaoDasSkills`, separados por skill e sem repetir o que o
coordenador já gravou em `dev` (14b96e446, 5d5ed3796, 0376a0446). Os cinco
principais: conferir as RPCs que o cliente chama contra `pg_proc` antes de
declarar SQL em produção; leitura e comando com a mesma função de capacidade;
`can_manage` no envelope, nunca inferido das linhas; validação nova em todas
as rotas que o cliente composto chama (v1 e v2); toda rota de produção compõe
o mesmo shell do golden.

## Worktrees

As quatro worktrees dos subagentes (`e2-r04-fcr-*`) estavam limpas e sem
commit próprio; foram removidas com suas branches. Resta só a worktree do
grupo, limpa e publicada; o coordenador integra e remove.
