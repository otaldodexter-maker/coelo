---
title: "Rodada 6 — fechamento (noite de 11/09/2026)"
source: "coordenacao.json revs 52-60; JSONs das sete frentes (revisões finais até 21:46); inventario-etapa-2.json validado; packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt (lotes 49 a 55)"
status: "closed"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 6 — fechamento

Janela: T0 19:36 (prompt C0), usuários `qa-r06-*` prontos às 19:56 (T0+20),
frentes até 21:36, revisão final de 10 minutos até 21:46, consolidação a
partir de 21:46 com pausa segura a pedido do Owner (22:53) e fechamento às
23:10. Coordenação: Claude Opus 5, esforço médio. Cota do Owner: 9% da
semana; ordem de 19:40: corte rígido, cobrança a cada 30 minutos, integração
contínua, nada perdido.

## Estado por camada (inventário validado; denominadores homogêneos)

| Camada | R05 (16:00) | R06 (fechamento) |
| --- | --- | --- |
| Front-end `verified` | 138/231 (59,74%) | 164/231 (71,00%) |
| Front-end `local-green` (das ações ainda não `verified`) | 23/93 (24,73%) | 17/67 (25,37%) |
| Front-end aprovação visual do Owner | 53/231 (22,94%) | 53/231 (22,94%) |
| Back-end `local-green` (das ações ainda não `done`) | 46/92 (50,00%) | 31/75 (41,33%) |
| Back-end SQL aplicado em produção | 178/224 (79,46%) | 180/224 (80,36%) |
| Back-end `done` | 132/224 (58,93%) | 149/224 (66,52%) |
| E2E `verified-e2e` | 105/199 (52,76%) | 134/199 (67,34%) |

Sem percentual composto; aprovação visual nunca vira `verified`, `done` ou
E2E; `local-green` cai quando a ação sobe. Números do último
`validate-trackers.cjs` PASS antes do push de fechamento.

## Produção (Supabase `coelo`, `evvbomzejfijozbtgvpt`)

7 lotes (49 a 55), 14 pacotes, cada um com dump prévio em
`C:/Users/adrie/Documents/Coelo-backups/schema-producao-20260911-loteNN.sql`,
preflight no espelho `coelo_baseline` (com a ordem real) e ledger.

| Lote | Hora | Pacotes |
| --- | --- | --- |
| 49 | 19:49 | `20260911230100_qa_r06_group_users_seed_v1` (coordenador) |
| 50 | 20:12 | `20260912210000_internal_actor_scope_root_v1` (realm-interno, segurança), `170500` P46 e `170600` P45 (acessos-pessoas), `200200` sessões da Conta P43 (operações) |
| 51 | 20:15 | `20260912180000_structure_handles_client_v1` (estrutura) |
| 52 | 20:35 | `20260912210100_internal_actor_scope_root_v1_hotfix` (realm-interno; reativou 7 memberships de `qa-r04-escola`) |
| 53 | 20:55 | `200300_account_profile_service_person_email_v1` (operações) |
| 54 | 21:22 | `180100` configuration_read e `180200` detail_v2 com @ (estrutura), `170700` resolvedor de identidade (acessos), `20260912220000` form_save_draft 42702 (formulários) |
| 55 | 21:40 | `130400` P48 reescrito sobre o escopo e `130500` scopeRules objeto (principal-chat-sistema), `170800` criação de usuário interno (acessos) |

Um pacote foi retido e devolvido (130400 da G4 derrubava a suíte de escopo
do lote 50; reescrito e aplicado no lote 55). `candidatos/` está vazio.
Edge Function `internal-user-create`: código na branch (deno check verde),
**sem deploy** (bloqueado na sessão do coordenador). CORS dos três buckets
R2 alinhado às portas locais das frentes (21:35).

## O que cada frente fechou

| Frente | Rev final | Entregas |
| --- | --- | --- |
| G1 Estrutura | 63 | @ em Unidades/Turmas/Atividades na rota real com `qa-r06-estrutura` (Alterar @, trava de 30 dias, disponibilidade); `units.list`, `groups.list/create/edit`, `activities.create` E2E; pacotes 180000/180100/180200; goldens de Atividades analisados (decisão do launcher pendente) |
| G2 Acessos e Pessoas | 146 | Convites create/detail/revoke, Alunos list/link/transfer/edit/revoke, `internal-users.list` E2E; pacotes 170500 (P46), 170600 (P45), 170700 (people.create), 170800 (internal-users.create) + Edge Function escrita; V-11 aplicado |
| G3 Formulários, Cuidado e Rotina | 55 | golden de tabs de Cuidado corrigido; Medicação create/detail/edit/evidence e `health-care.list` E2E; Rotina V-15 (Criar em toda aba, ações na tabela, Lançar hoje); pacote 20260912220000; itens 4 a 7 não alcançados |
| G4 Principal, Chat e Sistema | 39 | `principal_real_route_test` 4/4; Cardápios P47 (model-create/model-edit E2E; 130500 destrava create/edit/publish); publicadores Acontece/Agora/Momentos na família Publicação (goldens novos); V-2 aplicado, V-1/V-3 parciais; `errors.404`; 130400 (P48) |
| G5 Realm interno | 48 | raiz da ponte de ator com escopo (lotes 50 e 52), regressão comparada de 201 suítes, 180060 fechado sem decisão de produto, handoff e skills-deltas |
| G6 Publicações e Agenda | 51 | Circular e Evento reconstruídos na família Publicação; toggle web da lista da Agenda (V-8); `agenda.location` e `circulars.respond` E2E; `circulars.attach` local-green; sino do shell mapeado |
| G7 Operações | 51 | Importações no composto (teste); Sessões da Conta (P43) tela + pacote; Suporte com abas (P49); Planos activate/assign; Catálogo (P44); "Disponível depois do MVP" (IMP-R05-2); V-16 |

## Perguntas ao Owner

Em `R06-perguntas-ao-owner-20260911.md`: P51 (SMTP próprio), P52 (deploy de
`internal-user-create` pelo Owner ou pela R07), P53 (launcher Mensagens nos
goldens de Atividades), lista de arrobas reservados (fim do MVP). Sem
página visual nova: as telas da família Publicação seguem as referências
aprovadas às 17:19 e a prova visual fica para a R07.

## Dados sintéticos em produção (P25/P42: limpeza só no fim da Etapa 2)

Além dos da R05: auth users e identidades internas `qa-r06-*` (7, com
pessoas de serviço "Operador interno <id>", perfis "QA R06 <Grupo>" com CPF
sintético `000000600nn`, memberships owner nas três `qa-r04-*`); turma "Turma
R06 Arroba" (@arroba.r06.centro) e trocas de @ (`centro.r04estrutura`,
`estrutura-r06`); plano de medicação `12f816e8` (v2) com evidência
`42e77772`; modelo de cardápio `d132698c` (v2); rascunho de Momentos
`b173843d`; papel `institution_reader` (regra de produto P48, não é dado de
teste); sessões e chamados sintéticos das provas de Conta e Suporte.

## Chaves e segredos criados nesta rodada

| Nome | Onde | Como | Rotação |
| --- | --- | --- | --- |
| senhas de `qa-r06-<grupo>@coelo.me` (7) | `Coelo-backups/qa-r06-<grupo>.env` | 24 bytes aleatórios em script local, nunca impressas | `PUT /auth/v1/admin/users/{id}` com senha nova e regravar o `.env` |

Nenhum segredo de Edge Function ou Vault novo. Nenhum valor passou por chat,
commit, log ou JSON.

## Git e worktrees

- `dev` publicado com as sete branches `work/etapa2-r06-*` integradas por
  merge até as revisões finais; validador PASS; analyze com 1 warning em
  `test_driver/qa_login.dart` (strict_raw_type) a corrigir na R07.
- Worktrees `e2-r06-*` das frentes removidas após conferir status limpo e 0
  commits fora de `dev`; branches preservadas; `e2-r05-coordenacao` e
  `e2-r06-coordenacao` ficam até o próximo ciclo. Sem WIP retido.
- Checkout principal continua em `9bf60463b` (o coordenador não o edita):
  `git pull` pelo Owner.

## Recomendações para a R07 (Codex, Luna médio)

1. Trabalho mais simples possível por conversa, em famílias parecidas:
   provas pela tela do que já tem backend `done`; nada de refatoração.
2. Cada frente usa o seu `qa-r06-<grupo>.env`; Chrome com `--user-data-dir`
   próprio; um `flutter test` por vez.
3. Primeiro dia: deploy de `internal-user-create` (coordenador), mídia nos
   publicadores do Principal, Lançar chamada na família Publicação,
   Avaliações, Convites resend, `chat.create-group`/`chat.attach`.
