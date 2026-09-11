---
title: "Rodada 5 — fechamento (tarde de 11/09/2026)"
source: "coordenacao.json revs 38-48; JSONs das sete frentes (revisões finais das 15:50); inventario-etapa-2.json validado; packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt (lotes 28 a 48)"
status: "closed"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 5 — fechamento

Janela: abertura 12:03, entregas das frentes até 15:45, revisão final de 10
minutos às 15:50 (sete respostas recebidas até 15:52), consolidação 16:00 a
16:30. Coordenação: Claude Opus (`coelo-b5` até ~14:10, depois `coelo-25`,
porque as sessões da máquina foram reiniciadas; a máquina não reiniciou).

## Estado por camada (inventário validado; denominadores homogêneos)

| Camada | R04 (11:50) | R05 (fechamento) |
| --- | --- | --- |
| Front-end `verified` | 66/231 (28,57%) | 138/231 (59,74%) |
| Front-end `local-green` (das ações ainda não `verified`) | 32/165 (19,39%) | 23/93 (24,73%) |
| Front-end aprovação visual do Owner | 52/231 (22,51%) | 53/231 (22,94%) |
| Back-end `local-green` (das ações ainda não `done`) | 90/155 (58,06%) | 46/92 (50,00%) |
| Back-end SQL aplicado em produção | 133/224 (59,38%) | 178/224 (79,46%) |
| Back-end `done` | 69/224 (30,80%) | 132/224 (58,93%) |
| E2E `verified-e2e` | 43/199 (21,61%) | 105/199 (52,76%) |

`local-green` é estado intermediário e cai quando a ação sobe para
`verified`/`done`. SQL em produção = `done` + `local-green` com pacote
aplicado (na R05, todos). Aprovação visual não vira `verified`; nada se soma
entre camadas. Os números finais deste arquivo são os do último
`validate-trackers.cjs` PASS antes do push de fechamento.

## Produção (Supabase `coelo`, `evvbomzejfijozbtgvpt`)

21 lotes (28 a 48), 34 pacotes, cada um com dump prévio em
`C:/Users/adrie/Documents/Coelo-backups/schema-producao-20260911-loteNN.sql`,
preflight no espelho `coelo_baseline` (reconstruído às 13:05 na ordem real, 115
migrations) e ledger `supabase_migrations.schema_migrations`. Dois pacotes
foram devolvidos por asserção vermelha no espelho e corrigidos antes de entrar
(P32 e ponte das Circulares). Nenhum candidato restante em `candidatos/`.

Edge Functions: `chat-media` (nova, 13:25); `form-operations` (13:33),
`form-media` (13:33 e 14:22, reconciliada), `form-export-download` (14:58) e
`moments-media` (15:22) reimplantadas a partir de `dev` — as quatro estavam
com versões de agosto em produção e por isso XLSX, download e publicação com
mídia falhavam.

Chaves de composição ligadas: `segmentFilterAvailable` (Pessoas), rota de
Planos, Segurança infantil, `structureHandleAvailability` (Unidades e
Atividades), gancho de QA para `circulars.attach`.

## O que cada frente fechou (E2E = rota real + CRUD em produção + RLS + reload)

| Frente | Sessão | Rev final | E2E novos e entregas |
| --- | --- | --- | --- |
| G1 Estrutura | coelo-65 | 53 | institutions.edit/list/filter/detail/reload, units.edit/status/filter/reload/locations-map/copy-institution-location, activities.create/detail/edit/location; activities.publish BE; @ de estrutura (pacote 180000) e disponibilidade enquanto digita em Unidades e Atividades; parsers tolerantes dos detail_v2 |
| G2 Acessos e Pessoas | coelo-5d | 137 | access-profiles.list/detail/create, access-models.list/filter/detail, people.list/links/reload, invites.list; P31 na tela; @ de pessoas (170100); hotfix do `safeupdate` (170200); modelo de sistema Admin (170300); filtro por segmento (170400); students.transfer BE |
| G3 Formulários, Cuidado e Rotina | coelo-de | 46 | forms.publish/overview/monitor/respond/responses/response-detail, forms.responses.export e forms.download (XLSX no R2), child-safety.create/edit/suspend, health-care.create/detail/edit, attendance.dashboard/create/mark/finish/correct, daily-routine.create/apply; contrato de Assiduidade (220100), rotina can_manage (220000), cron form-media (230000); form-media question-image |
| G4 Principal, Chat e Sistema | coelo-c2 | 29 | acontece.feed/create/publish/remove; agora.view e momentos.view FE+BE; principal.for-you/profile-view, errors.retry FE; ponte do Principal (130000), @ nos contextos + perfil Coelo (130100), feed do Acontece para owner (130200), Momentos baseline (130300) |
| G5 Realm interno | coelo-38 | 38 | 16 pacotes: contatos da instituição (210000), revoke de grants sem policy (210100), anexos do chat (210200), arquivos de Formulários no R2 (210300, 210800), P36 (210400), P32 políticas + sino (210500), handles no detail (210600), crons de mídia (210700, 210900), @ no payload (211100), segurança da Agenda (211200), claims do worker (211300), @ de unidade (211400), reconciliação de plans (211000/211500); chat-media e form-media (respostas) |
| G6 Publicações e Agenda | coelo-da | 43 | agenda.request/permissions, notices.schedule/publish, circulars.edit/schedule; agenda.location, circulars.attach/respond BE; P33/P34 aplicados e aprovados; ponte das Circulares (190000), rótulos das Aprovações (190100), R2 de Circulares reaplicado (190200), mídia no v2 (190300); seletor de contexto no wizard de evento |
| G7 Operações | coelo-0c | 38 | audit.list/filter/detail, plans.list/create/edit, account.logout, support com responsável; composto de tabela G-SUP (aprovado), Importações no composto (aprovado); escopo de Planos (200000, achado de segurança), responsáveis do Suporte (200100) |

## Aprovações e perguntas ao Owner

Aprovadas hoje: G-SUP (14:20), Agenda P33/P34 (14:52), Importações (14:58, uma
exceção corrigida no mesmo dia). Registradas em `ownerVisualApproval`.

Abertas, em lote, em `R05-perguntas-ao-owner-20260911.md`: P43 (sessões da
Conta), P44 (Catálogo), P45 (exclusão de modelo de sistema), P46 (@ de
usuários internos), P47 (fail-closed de tenant em Cardápios), P48
(sincronizador do P35 por papel), P49 (abas de estado no Suporte), P50
(responder circular no Superadmin), A+ dos goldens `agenda_create_*`,
IMP-R05-2, e a pendência dos arrobas reservados no encerramento do MVP.

Decisões do Owner na tarde (ADR 0034 Decisão 17): usuários sintéticos por
grupo na R06; listas de arrobas reservados no encerramento do MVP; dados
sintéticos ficam até o fim da Etapa 2.

## Pendências de revisão profunda (não bloqueiam o MVP)

- Raiz da ponte de ator: membership escopada espelhada como
  `platform_membership` sem escopo (220400/130000); corrigida na Agenda (lote
  44), 12 helpers a provar por família (Rotina, Cuidado, Assiduidade,
  Cardápios, Suporte).
- 180060 (`has_activity_capability` passou a exigir instructor; mudança de
  comportamento a confirmar com produto); sobrecarga de 14 args de
  `audit_append_superadmin_internal`.
- Suítes pré-existentes em `origin/dev` que continuam vermelhas na base
  integrada: `test/app` (18: dev_menu, import_development_routes,
  prototype_navigation_routes), `test/core/config` (4),
  `activity_golden_test` (9), `institution_directory_pagination_disabled_light_1440`
  (0,21%), `test/shared` (11: underline_tabs e form_action_footer_adoption). A
  suíte completa fechou 6692 aprovados / 53 falhos / 11 pulados na base
  integrada. Comparação com `origin/dev` `9bf60463b` (mesmas suítes numa
  worktree limpa): **4 falhas novas atribuídas à R05**, a corrigir na abertura
  da R06 — `fail_closed_screens_with_data_probe_test` "Importações lays out
  with data" 1440 e 375 (G7, Importações migradas ao composto),
  `principal_real_route_test` "real route opens the first context and offers
  the profile selector (P28)" (G4), `health_care_golden_test` "profile
  directory tabs hover and table evidence" (G3 ou composto de tabela). As
  demais 49 já falhavam em `origin/dev`.
- Balão de chat sobre o rodapé de Assiduidade (corrigido pela G3 sem prova na
  rota real); página genérica "503" para recurso adiado por decisão (texto
  honesto seria "Disponível depois do MVP").
- Cardápios: fail-closed de tenant no cliente (P47) mantém 5 ações em 503.
- `chat.attach` e arquivos de Formulários: SQL, funções e cron em produção;
  falta o cliente (anexo pelo chat; `COELO_FORMS_MEDIA_PROVIDER=r2` só quando o
  cliente de respostas usar upload_url/required_headers).
- Prova pela tela pendente em Agora e Momentos (publicação com mídia), Alunos,
  Convites (detalhe/reenviar/revogar), Usuários internos, Medicação
  (criar/editar), Avaliações, Turmas (membros/local).

## Dados sintéticos em produção (P25/P42: limpeza só no fim da Etapa 2)

- Usuário `qa-r03@coelo.me` (Owner de plataforma) e sua pessoa de serviço
  (ponte 220400); perfil interno "QA R04 Sintetico" (171200).
- Instituições sintéticas `9f040000-…0010` (chat, archived),
  `d0c40000-…0001` (qa-r04-cuidado-sintetico) e `190dd028` (qa-r04-escola,
  com documento e representante "Rafaela Sintetica" desde 14:19); memberships
  do qa-r03 nelas (lote 27) e `institution_role_assignments` do sincronizador
  130000 (regra de produto, não é dado de teste).
- Estrutura: groups `368a5cea`; units `f5284f2f` (agora active) e `cce78909`
  ("Unidade QA R05 Transferencia"); activity_locations `82e92854` e
  `d5461295`; activity_definitions `95b98978` e `2e45c8bd` (draft).
- Acessos: convite `03e9c9d2` (revoked); people `ec2a15a2`; access_profile_templates
  `cc322488` e `60fb9586`; perfil Admin "Secretaria QA R05" `d6264c5d`
  (is_system); child_group_links `8d766ca8`; child_unit_links `5d00bc95`;
  trocas de @ `qa_r05_teste` e `qa_r05.profissional`.
- Formulários/Cuidado: form_applications `a0ee4530`, schedules `2860c35a`,
  occurrences `6b0bd1ef`, responses `1f365626`, file_jobs `09f86ec7` (XLSX no
  R2 `coelo-transient-prod`), authorized_person_authorizations `34d29829` e
  `7fcb6761`, perfil de cuidado e planos de medicação da prova, chamada
  `d3821901`, modelo de rotina `176882c5` e aplicação `3d9f0a32`.
- Principal: posts `2b05143d`, segundo post "Publicacao sintetica R05" e
  `aee8bc05` (retirado); moments_publications `ba75dde2` (rascunho); pessoa
  **Coelo** `c0e10000-…0001` e seus follow_links (regra de produto P35 B, não
  é dado de teste); conversa `355a3403` do chat (R04).
- Publicações: avisos, eventos, circulares e anexos `[R04-QA]`/`[R05-QA]`
  (inativos, cancelados, closed ou deleted_at; anexo de circular em
  `coelo-media-prod`).
- Operações: plano `5b0fc76b` "[R05-QA] Plano de teste editado"; chamado
  `48e02ab0` com responsável; eventos de auditoria append-only.

A limpeza é uma migration única com dump prévio, provada no espelho, que
arquiva o que `audit.audit_logs` referencia por FK e apaga o restante.

## Chaves e segredos criados nesta rodada (rotação futura)

| Nome | Onde | Como foi criado | Rotação |
| --- | --- | --- | --- |
| `coelo_person_identity_hmac_v1` | Vault | gerado no banco pela migration 210000 (`gen_random_bytes`), nunca impresso | criar `_v2` no Vault + migration que troca a versão; linhas v1 ficam só para máscara |
| `CHAT_MEDIA_WORKER_SECRET` + Vault `chat_media_worker_secret` | secrets das Edge Functions + Vault | `openssl rand -hex 32` em `Coelo-backups/chat-media-worker-secret.env`, nunca impresso | novo hex, `supabase secrets set` e `vault.update_secret` |
| `CHAT_MEDIA_ALLOWED_ORIGINS`, `*_MEDIA_ALLOWED_ORIGINS`, `COELO_ALLOWED_ORIGINS` | secrets | listas de origem (não são segredos) | reescrever a lista completa |
| `chat_media_worker_url`, `form_media_worker_url`, `forms_media_worker_url` | Vault | URLs públicas das funções | n/a |

Nenhum valor passou por chat, commit, log ou JSON.

## Git e worktrees

- `dev` publicado no fechamento com as sete branches `work/etapa2-r05-*`
  integradas por merge (≈100 merges na rodada), analyze limpo, validador PASS.
- Worktrees `e2-r05-*` das frentes e `e2-r04-coordenacao`, `e2-r04-estrutura`
  removidas depois de conferir status limpo e 0 commits fora de `dev`;
  branches preservadas. `e2-r05-coordenacao` fica até o próximo ciclo.
- Sem WIP retido em nenhuma frente.

## Recomendações para a R06

1. Usuário sintético por grupo (decisão do Owner): `qa-r06-<grupo>@coelo.me`
   com perfil interno, ponte de ator e membership nas instituições
   sintéticas, criados por migration idempotente + API de administração do
   Auth; um `--user-data-dir` de Chrome por frente e script de abertura que
   fecha Chromes de CDP órfãos.
2. Uma única frente dona de cada Edge Function e de cada família de RPC,
   nomeada no prompt.
3. Frentes de backend puro sem o MCP `dart` (um servidor de análise por
   conversa consome ~800 MB).
4. Primeiro dia: fechar Cardápios (P47), Agora/Momentos com mídia, Alunos,
   Convites, Medicação, Avaliações e o cliente de anexos.
