---
title: "Rodada 4 — contrato comum e prompts por conversa (noite de 10→11/09/2026)"
source: "R03-prompts.md; coordenacao.json rev 18 (fechamento da R03); ADR 0034 (Decisões 1–12); os três md de pendências em docs/reviews; goldens-claro-decisoes, goldens-acontece-cardapios-decisoes e goldens-decisoes-complementares de 10/09; ordem do Owner de 10/09/2026 à noite"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Rodada 4 — contrato comum

Ponto de entrada de toda conversa da Rodada 4. Cada prompt manda ler este
arquivo integralmente. Nada aqui inicia execução; a conversa começa quando o
Owner cola o prompt.

## Identificação e horários

- Rodada: `E2-R04-20260911`. Base: `origin/dev` no HEAD que contém este
  arquivo (`a4af2b198` ou posterior), conferido na abertura com `git fetch`.
  Raiz: `C:/Users/adrie/Documents/Coelo`. Recorte: `apps/superadmin` e os
  packages/backends que ele usa, inclusive o menu Coelo (Principal).
- **Frentes trabalham até 04:20 de 11/09/2026.** Quem terminar antes grava
  `finalizado` no próprio JSON e faz a mini-revisão de 10 minutos (abaixo).
  Depois de 04:20 ninguém retoma por conta própria.
- **Coordenador consolida de 04:30 a 05:20** e entrega ao Owner os percentuais
  no formato fixo.
- Todo checkpoint identifica `Etapa 2 → apps/superadmin → menu → tela →
  subtela/estado → action_id`.

## Ordem que vale para todas as conversas

**Não parar de trabalhar de forma alguma até finalizar o recorte, até 04:20,
ou até ordem do Owner ou do coordenador.** Terminou um item, vai ao próximo
executável. Bloqueio retém só o dependente. Sem trabalho independente: avisar
o coordenador uma vez no JSON e seguir no que não depende.

As conversas do Claude param com frequência. Por isso, na abertura, cada
conversa Claude agenda o próprio despertar: `/loop 15m Retome o recorte da
Rodada 4 sem parar: próximo item executável, atualize o seu JSON, não
encerre o turno antes de 04:20.` O coordenador agenda `/loop 30m` para ler os
JSONs.

**Foco em avançar.** Não fazer code review profundo nesta rodada: o que ficar
de fora (prova exaustiva, refatoração, dúvida de segurança não bloqueante)
vira pendência registrada no JSON, com action_id, e é tratado nos code reviews
que o Owner pedir. CRUD real, RLS e segurança básica continuam obrigatórios.

## Mini-revisão de 10 minutos (obrigatória ao finalizar ou às 04:20)

Quando a frente termina, ou quando o coordenador pede, ela gasta no máximo 10
minutos para deixar tudo com o coordenador, no próprio JSON e no handoff:

1. SHA final da branch, publicado (`git push`), status limpo ou WIP nomeado;
2. o que fechou, por action_id, com a prova (teste, pgTAP, rota real com
   sessão);
3. o que ficou aberto com o primeiro gate;
4. proposta de delta FE/BE/E2E por action_id;
5. pacotes SQL prontos (caminho em `candidatos/<grupo>/`, pgTAP verde no
   projeto descartável) e chaves de composição a ligar;
6. dúvidas ao Owner, com imagens lado a lado quando for visual.

## Régua e autorizações vigentes (ADR 0034, Decisões 1–12)

- Ação verificada no MVP: rota normal abre sem fixture nem fail-closed; CRUD
  persiste no Supabase de produção; RLS nega outro tenant (pgTAP); reload
  mantém estado. Provas exaustivas ficam registradas para depois do MVP.
- Todo remoto é produção e não há clientes reais. Pacote SQL verde em pgTAP
  local vai para produção pelo coordenador, na ordem da fila, com dump lógico
  por lote (PITR foi dispensado pelo Owner, Decisão 8). Não pedir autorização
  por pacote. Executores entregam migration + pgTAP + chave de composição.
- **Layout de pacotes (Decisão 8/P12):** `packages/coelo_database/migrations/`
  contém a baseline de produção (`20260910000000_baseline_producao.sql`) e o
  que já foi aplicado; pacote novo nasce em
  `packages/coelo_database/candidatos/<grupo>/` com carimbo na faixa do grupo
  (acessos 17, estrutura 18, principal-chat 19, publicacoes 20, operacoes 21,
  formularios 22, coordenador 23, realm-interno 24: `2026091018xxxx` etc.) e
  o coordenador move para `migrations/` ao aplicar. Prova local: projeto
  Supabase descartável com `db reset` + `supabase/seed.sql` + todas as
  `migrations/` + o candidato + pgTAP (ver `packages/coelo_database/README.md`
  e a skill `coelo-backend`). Aplicabilidade decide-se pela presença do objeto
  em produção (`pg_proc`/`pg_class`), não pelo ledger. Produção é a forma
  canônica (`units.unit_type_id`, não `institution_type_id`).
- **Sessão de teste em produção (Decisão 10/P17):** usuário sintético
  `qa-r03@coelo.me`, Owner de plataforma no realm interno v2; credencial só em
  `C:/Users/adrie/Documents/Coelo-backups/qa-r03.env` (fora do Git, nunca em
  chat, commit, log ou JSON). App local em `http://localhost:3000` (origem
  liberada no CORS do R2). Dados criados nos testes são sintéticos e removidos
  ao fim. Regra da skill `coelo-backend`, seção "Sessão de teste em produção".
- **MFA fora do MVP (Decisão 12/P10-P11):** nenhuma tela exige segundo fator;
  `account.mfa` e gates AAL2 saem do caminho. O coordenador aplica a migration
  única que zera `requires_mfa` e alinha as funções que negam AAL2; até lá, as
  escritas de Pessoas/Perfis/Modelos continuam presas.
- **Permissões por perfil (Decisão 12/P7):** todos podem mexer mediante perfis
  e permissões; `has_platform_permission` passa a considerar membership por
  instituição. Pacote do grupo acessos-pessoas.
- Cloudflare: pacote da Decisão 5 concluído pelo coordenador (CORS, lifecycle,
  token R2 nos secrets, `circular-media` v5 e `moments-media` v1 em R2).
  Faltam `happens-media` e `now-media` (dependem das migrations de
  `storage_provider → r2` do grupo principal-chat-sistema) e o deploy é do
  coordenador. Zona `coelo.me` criada, NS ainda na HostGator; DNS, Pages e
  migração do site esperam respostas do Owner. Stream: só o Agora, até 24 h,
  preparado (P19). Nenhum outro recurso Cloudflare sem decisão nominal.
- Import/export continuam adiados com botão honesto, exceto
  `forms.responses.export` (XLSX no R2). Nenhum segredo em Git, bundle, log,
  URL, chat ou frontend.

## Visual

- `coelo-ui` é a autoridade. Antes de tocar qualquer tela, ler as três listas
  de decisão do Owner: [goldens-claro-decisoes-2026-09-10.md](../../evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md),
  [goldens-acontece-cardapios-decisoes-2026-09-10.md](../../evidence/etapa-2/goldens-acontece-cardapios-decisoes-2026-09-10.md)
  e [goldens-decisoes-complementares-2026-09-10.md](../../evidence/etapa-2/goldens-decisoes-complementares-2026-09-10.md)
  (esta prevalece). **R** mantém a referência guardada; **A** regrava depois
  de aplicar a observação. A decisão por ação está no inventário em
  `ownerVisualApproval` (52 ações). Aprovação visual não é `verified`.
- Regras transversais reafirmadas: Pesquisar no menu e botão de Bug no
  cabeçalho em todas as telas (MENU-M no mobile); rodapé ancorado no fim da
  viewport em todos os formulários, com respiro no fim do conteúdo (P15);
  sem balão de chat em criar/editar/publicar, Agora aberto e Momentos aberto
  (Decisão 7); card Criar primeiro no grid, inclusive vazio e sem resultados.
- Conceito de família vive uma vez no composto `CoeloAdminDirectory` de
  `coelo_ui_admin` (Fase 0). Feature não declara Table, Toolbar, Pagination,
  Header ou Directory próprios; o teste de arquitetura falha se declarar.
- Goldens escuros seguem o claro de mesmo nome. Regravar só depois de aplicar
  a observação e no SDK registrado (Flutter 3.44.2 stable, `.fvmrc`).
- Dúvida visual nova: página com imagens lado a lado (referência, atual,
  diferença) para o Owner, via coordenador. Ele decide mais rápido.

## Skills obrigatórias

Carregar uma vez e reutilizar: `rtk` (prefixar comandos), `ponytail` (menor
solução correta), `coelo-frontend` (`.agents/skills/coelo-flutter-review`),
`coelo-backend` (`.agents/skills/coelo-supabase`), `coelo-frontend-backend`
(`.agents/skills/coelo-flutter-supabase-review`), `coelo-ui`,
`coelo-knowledge` (fonte canônica primeiro, gate ao final),
`flutter-dart-code-review` para Dart, skill oficial `supabase` e boas práticas
Postgres para SQL/RLS, `cloudflare` e `wrangler` quando o provedor entrar.

## Comunicação e entrega

- Raiz: `docs/reviews/etapa-2-operacao/comunicacao/`. `coordenacao.json` é
  escrito só pelo coordenador; `<grupo>.json` só pelo executor do grupo (o
  mesmo arquivo da R03, campo `round = E2-R04-20260911`, revisão continua a
  contagem). Executores não editam rastreadores, inventário nem arquivos de
  outro grupo. O grupo novo `realm-interno-chat-backend` escreve em
  `realm-interno.json`.
- Abertura: executor grava a primeira revisão da R04 (identificação,
  ferramenta/modelo, worktree, branch, HEAD, recorte, primeiro gate) e lê o
  histórico da R03 no próprio JSON e no handoff do grupo, para não repetir
  nem perder nada. Trabalho independente não espera ACK.
- Atualizar ao fechar correção, publicar lote, mudar bloqueio, antes de comando
  longo e pelo menos a cada 30 minutos ativo. Campos: revisão/hora (relógio da
  máquina); grupo; worktree/branch/HEAD; tela/subtela/action_ids; o que
  mudou; critérios fechados; testes P/F/B/S/U; bloqueio e próximo passo;
  proposta de delta FE/BE/E2E por ID. Campo desconhecido não vira zero.
- Worktree por conversa, criada pela própria conversa a partir de
  `origin/dev`:
  `git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-<grupo> -b work/etapa2-r04-<grupo> origin/dev`.
  Nunca trabalhar no checkout principal `C:/Users/adrie/Documents/Coelo`.
  Commits pequenos em português; push da branch do grupo; só o coordenador
  escreve em `dev`. Quem toca o `pubspec` ou o composto avisa o coordenador.
- Handoff de meia página ao encerrar cada tela/subtela e a mini-revisão de 10
  minutos ao finalizar.

## Estado de partida (fechamento da R03, 10/09 20:30)

| Camada | Estado |
| --- | --- |
| Front-end `verified` | 11/230 (4,78%) |
| Front-end `local-green` | 23/230 (10,00%) |
| Front-end aprovação visual do Owner | 52/230 (22,61%) |
| Back-end `local-green` | 61/223 (27,35%) |
| Back-end SQL aplicado em produção | 31/223 (13,90%) |
| Back-end `done` | 0/223 (0,00%) |
| E2E `verified` | 0/198 (0,00%) |

Produção tem 42 migrations de 10/09 em sete lotes (formulários, Unidades,
Cardápios, acessos, cuidado/rotina/alunos, Locais parcial, Suporte/Conta). O
que cada frente recebe está no prompt dela e em
`coordenacao.json.reativacaoDasFrentes`.

---

# Prompts por conversa

Colar cada bloco em uma conversa nova do Claude, com o modelo e o nome
indicados (decisão do Owner de 10/09 à noite: toda a R04 roda no Claude). Ordem de abertura: C0 (coordenação) primeiro, depois as frentes.

## C0 — «R04 · Coordenação noturna» — Claude, Fable

**Resumo:** única escritora de `dev`, do inventário e dos três rastreadores;
aplica em produção a migration de MFA fora do MVP e os pacotes verdes das
frentes; faz o deploy de `happens-media`/`now-media` quando as migrations
chegarem; lê os JSONs a cada 30 minutos e avisa o Owner de conversa parada;
às 04:20 pede a mini-revisão de 10 minutos; de 04:30 a 05:20 consolida tudo,
deixa worktrees e commits limpos, atualiza rastreadores, skills e ADR, e
entrega os percentuais no formato fixo.

```text
Você é a conversa «R04 · Coordenação noturna» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Fable). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/coordenacao.json (revisão 18, fechamento da R03), os três md de pendências em docs/reviews (coelo-flutter-pendencias.md, coelo-supabase-pendencias.md, coelo-flutter-integrado-supabase-pendencias.md), decisions/0034-mvp-remote-application-and-acceptance-bar.md, AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend, coelo-frontend-backend, coelo-ui e coelo-knowledge. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-coordenacao -b work/etapa2-r04-coordenacao origin/dev. Nunca edite o checkout principal. Registre posse em coordenacao.json (revisão 19, round E2-R04-20260911, relógio da máquina) e agende /loop 30m Leia os JSONs das frentes, emita ACK, aplique pacotes verdes, integre e atualize rastreadores; liste ao Owner em uma linha as conversas sem revisão nova há mais de 30 minutos.

Responsabilidades: (1) única escritora de dev, de docs/reviews/inventario-etapa-2.json e dos três rastreadores; integrar as branches work/etapa2-r04-* por merge na base conjunta (sua worktree), verificar flutter analyze e os testes das famílias tocadas, aplicar os deltas propostos por action_id com node docs/reviews/apply-tracker-delta.cjs <deltas.json>, validar com node docs/reviews/validate-trackers.cjs, commits pequenos em português, push em dev; (2) primeiro pacote SQL, antes de qualquer outro: a migration única "MFA fora do MVP" (ADR 0034 Decisão 12) em candidatos/coordenador (faixa 2026091023xxxx): requires_mfa = false em todo o catálogo de permissões e alinhamento das funções que negam AAL2 (app_private e require_superadmin_internal_context), provada no projeto descartável (db reset + seed + migrations/ + candidato + pgTAP, scratchpad/preflight.sh ou equivalente), dump lógico do lote em C:/Users/adrie/Documents/Coelo-backups antes de aplicar com supabase db query --linked e inserção manual no ledger supabase_migrations.schema_migrations; em seguida aplicar candidatos/acessos-pessoas/20260910170900_people_read_aal1_for_mvp.sql e candidatos/formularios-cuidado-rotina/20260910220300_student_links_read_v1.sql, e os candidatos de estrutura (1800xx) assim que o grupo corrigir a assinatura de audit_append_superadmin_internal; (3) aplicar em produção cada pacote verde que as frentes entregarem em candidatos/<grupo>/, na ordem da fila, movendo para migrations/ ao aplicar, ligando a chave de composição correspondente e registrando o que ficou aberto; (4) quando principal-chat-sistema entregar as migrations de storage_provider → r2 de happens e now, aplicar e fazer o deploy de happens-media e now-media com --project-ref evvbomzejfijozbtgvpt, no padrão de moments-media (COELO_R2_* dos secrets, verify_jwt conforme config.toml); nenhum outro recurso Cloudflare; DNS/Pages/site esperam as respostas do Owner sobre a HostGator; (5) ler comunicacao/<grupo>.json das sete frentes (estrutura, acessos-pessoas, formularios-cuidado-rotina, principal-chat-sistema, realm-interno, publicacoes-agenda e operacoes, todas em Claude), emitir ACK e recibo por revisão em coordenacao.json, responder bloqueios com o que já existe (produção medida, baseline, decisões do Owner); (6) segredos nunca em chat, commit, log ou JSON; a credencial de qa-r03@coelo.me fica em Coelo-backups/qa-r03.env; (7) às 04:20 pedir em coordenacao.json a mini-revisão de 10 minutos a cada frente (o Owner repassa a ordem às conversas paradas); de 04:30 a 05:20: integrar tudo que chegou, deixar o status limpo, worktrees das frentes removidas depois de integradas (branches preservadas, WIP retido nomeado no JSON), rastreadores e inventário regenerados e validados, skills coelo-backend/coelo-frontend/coelo-frontend-backend com regra nova ou decisão do Owner, ADR 0034 com decisão nova, portão de conhecimento, e o fechamento ao Owner no formato fixo: estado por camada com percentuais de duas casas e denominadores homogêneos (FE verified, FE local-green, FE aprovação visual, BE local-green, BE SQL em produção, BE done, E2E), sem percentual composto, sem plano no lugar de estado; aprovação visual nunca vira verified, done ou E2E; (8) o que o Owner precisa decidir vai em lote, com imagens lado a lado quando for visual, e as perguntas abertas ficam em next-round/R04-perguntas-ao-owner-20260911.md.

Estados distintos: recebido, integrado, aplicado em produção, verificado E2E. Não declarar E2E por teste local. Enquanto aguarda entregas, aplique a fila SQL, integre e feche dependências compartilhadas; a ordem de parar vem só do Owner ou do horário (05:20). Foco em avançar: code review profundo fica registrado como pendência para os reviews que o Owner pedir.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id (rota normal, CRUD em produção, RLS nega outro tenant, reload mantém); todo remoto é produção, sem clientes reais; pacote verde vai para produção sem pedir autorização, com dump por lote; layout baseline + candidatos/<grupo> com faixas de carimbo por grupo; presença do objeto decide aplicabilidade; produção é a forma canônica; MFA fora do MVP; permissões por perfil com membership por instituição; Cloudflare só o pacote autorizado, Stream só no Agora; import/export adiados com botão honesto (exceto XLSX de formulários); coelo-ui é a autoridade e as três listas de decisão de goldens do Owner valem por arquivo (R referência, A regravar após a observação; ownerVisualApproval no inventário); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; commits pequenos em português; nenhuma pendência se perde e nenhum avanço fica sem registro.
```

## G1 — «R04 · Estrutura» — Claude, Opus

**Resumo:** Instituições, Unidades, Turmas, Atividades, Avaliações e Locais
ponta a ponta na rota real com sessão. Destrava Locais (reservas e vínculos
sobre a baseline), aplica P5, P6 e P15 (respiro do rodapé no frame
compartilhado) e prova a régua do MVP por action_id.

```text
Você é a conversa «R04 · Estrutura» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/estrutura.json (revisão 22, sua história na R03) e docs/reviews/evidence/etapa-2/r03-estrutura/handoff.md, os três md de pendências em docs/reviews no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-estrutura -b work/etapa2-r04-estrutura origin/dev. Grave a primeira revisão da R04 em comunicacao/estrutura.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize estrutura.json, não encerre o turno antes de 04:20.

Recorte: famílias institutions, units, groups, activities, assessments, locations do inventário (49 ações), ponta a ponta. O que você recebe: as 13 RPCs de Unidades, o catálogo v2 de Locais (status, cópia, agenda) e as capacidades locations.* (20260910230012) estão em produção; as chaves structureMutationsEnabled/adapters reais são o gate do cliente. Ordem: (1) Locais: corrigir em candidatos/estrutura os pacotes 20260910180000 (consumer bindings), 180100 (activity_location_create), 180200 (group_location_create) e 180300 (unit_detail_v2) para a assinatura real de audit_append_superadmin_internal em produção e para a forma canônica de produção (unit_type_id), provar no projeto descartável com pgTAP e entregar ao coordenador; a fixture de activity_save_v2 (activity_v2_denied_envelope) idem; (2) rota normal com sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env, app em localhost:3000) de Instituições → Unidades → Turmas → Atividades → Locais → Avaliações: criar, editar, recarregar, e propor verified só quando CRUD persistir em produção, o RLS negar outro tenant em pgTAP e o reload manter; (3) P5: Turmas abre com o filtro por unidade degradando de forma honesta; P6: o diálogo de importar de Unidades vira a indisponibilidade honesta de Instituições; (4) P15 no SuperadminFormFrame (frame compartilhado que você criou): rodapé ancorado no fim da tela com respiro no fim do conteúdo para a última informação nunca ficar escondida; avisar no JSON para formularios-cuidado-rotina regravar medication_form_mobile_light depois; (5) goldens do recorte conforme as três listas de decisão do Owner (activity_form_create_light_375 RODAPÉ, activity_detail_*, group_form_*), regravados só após a observação e no SDK 3.44.2; espaçamento de Turmas conforme r03-estrutura/decisao-espacamento-turmas.md. Entregue migration + pgTAP + chave por pacote; o coordenador aplica e liga. Escreva só em comunicacao/estrutura.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/estrutura na faixa 2026091018xxxx e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório (feature não cria Table, Toolbar, Pagination, Header ou Directory próprios); nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G2 — «R04 · Acessos e Pessoas» — Claude, Opus

**Resumo:** Pessoas, Perfis de acesso, Modelos, Convites, Usuários internos,
Segurança infantil e Arquivos de perfil na rota real com sessão. Recebe a
migration de MFA fora do MVP do coordenador e entrega o pacote P7 de
permissões por perfil com membership por instituição.

```text
Você é a conversa «R04 · Acessos e Pessoas» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/acessos-pessoas.json (revisão 94, sua história na R03) e docs/reviews/evidence/etapa-2/r03-acessos-pessoas/handoff.md, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-acessos-pessoas -b work/etapa2-r04-acessos-pessoas origin/dev. Grave a primeira revisão da R04 em comunicacao/acessos-pessoas.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize acessos-pessoas.json, não encerre o turno antes de 04:20.

Recorte: famílias people, access_profiles, access_models, invites, internal_users, child_safety, profile_files (38 ações), ponta a ponta. O que você recebe: o lote 4 está em produção (person_detail, invites_v2, usuários internos, Segurança infantil, 18 RPCs); people_read_aal1 (170900) e as escritas de Pessoas/Perfis/Modelos entram assim que o coordenador aplicar a migration "MFA fora do MVP" (acompanhe coordenacao.json; até lá, trabalhe no que não depende). Ordem: (1) rota normal com sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env, app em localhost:3000) por action_id: Convites (listar, detalhe, criar, reenviar, revogar) → Usuários internos → Segurança infantil → Pessoas (vínculos, recarregar; depois listar/criar/editar quando a migração de MFA estiver aplicada) → Perfis e Modelos de acesso (leitura já funciona; escrita após MFA); propor verified só com CRUD em produção, RLS negando outro tenant em pgTAP e reload mantendo; (2) P7 (Decisão 12): pacote em candidatos/acessos-pessoas (faixa 2026091017xxxx) que faz has_platform_permission considerar membership por instituição, com pgTAP de negativa cross-tenant, sem afrouxar deny-by-default; (3) D1: vínculo de acompanhamento automático da hierarquia ao cadastrar criança (com principal-chat-sistema, que consome no Perfil); (4) Arquivos de perfil: import/export adiados e honestos, sem picker, parser, job, RPC ou persistência; (5) goldens do recorte conforme as três listas de decisão do Owner (child_safety_directory_light_1440 tem causa visual pré-existente: corrigir antes de regravar). Entregue migration + pgTAP + chave por pacote. Escreva só em comunicacao/acessos-pessoas.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/acessos-pessoas e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; permissões por perfil com membership por instituição; coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G3 — «R04 · Formulários, Cuidado e Rotina» — Claude, Opus

**Resumo:** Formulários (autoria, respostas, arquivos, XLSX), Perfis de
cuidado, Medicação, Alunos, Assiduidade e Rotina diária na rota real com
sessão. Chaves de Cuidado/Rotina e vínculo de aluno já ligadas; entra P16
(Local em Formulários) e a Assiduidade no composto.

```text
Você é a conversa «R04 · Formulários, Cuidado e Rotina» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/formularios-cuidado-rotina.json (revisão 22) e comunicacao/formularios-cuidado-rotina-handoff.md, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-formularios-cuidado-rotina -b work/etapa2-r04-formularios-cuidado-rotina origin/dev. Grave a primeira revisão da R04 em comunicacao/formularios-cuidado-rotina.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize formularios-cuidado-rotina.json, não encerre o turno antes de 04:20.

Recorte: famílias forms_authoring, forms_responses, forms_files, health_care, medication, students, attendance, daily_routine (43 ações), ponta a ponta. O que você recebe: lotes 1, 2, 3 e 5 em produção (formulários, fundação de Cuidado/Rotina/Assiduidade/Alunos, guardian read, student_link_commands, revoke drift), chaves COELO_ENABLE_CARE_AND_ROUTINE_BACKEND e COELO_ENABLE_STUDENT_LINK_COMMANDS ligadas por padrão; candidatos/formularios-cuidado-rotina/20260910220300_student_links_read_v1.sql será aplicado pelo coordenador no início da rodada. Ordem: (1) rota normal com sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env, app em localhost:3000) por action_id: Perfis de cuidado e Medicação → Alunos → Assiduidade (chave de idempotência gerada no banco, D11; diretório de Assiduidade migrado ao composto, pendência da Fase 0) → Formulários autoria/respostas (Testar por capacidade, D6) → Arquivos e XLSX (forms.responses.export no R2 privado via gateway) → Rotina (guarda de saída ligada, D8; Lançamentos com tela mínima, D7); propor verified só com CRUD em produção, RLS negando outro tenant em pgTAP e reload mantendo; (2) P16 (Decisão 12): pergunta de Local entra em Formulários como tipo location com opções fixas do catálogo, bloqueio e aviso quando o local revogado não tem alternativa; pacote em candidatos/formularios-cuidado-rotina (faixa 2026091022xxxx) + UI; (3) goldens do recorte conforme as três listas de decisão do Owner: medication_form_mobile_light só depois de o grupo estrutura entregar o respiro do rodapé (P15) no frame compartilhado; profile_form_* já regravados; (4) o que depender de estrutura ou do coordenador fica anotado com o primeiro gate e você segue no resto. Entregue migration + pgTAP + chave por pacote. Escreva só em comunicacao/formularios-cuidado-rotina.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/formularios-cuidado-rotina e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; import/export adiados exceto o XLSX de respostas; coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G4 — «R04 · Principal, Chat e Sistema» — Claude, Opus

**Resumo:** Acontece, Momentos, Agora, Perfil, Chat, Cardápios, Planos,
Importações, Catálogo, erros, Auth e Shell. Entrega as migrations de R2 de
Acontece e Agora (o coordenador aplica e faz o deploy), incorpora o WIP da
Fase 0 (ARQUIVO e launcher do chat), o véu do Destaque e os textos sem
"prévia"; Criar grupo no Chat (P8) com o backend do grupo realm-interno.

```text
Você é a conversa «R04 · Principal, Chat e Sistema» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/principal-chat-sistema.json (revisão 8), comunicacao/principal-chat-sistema-handoff.md e next-round/R03-fase0-handoff.md (WIP da Fase 0 que agora é seu), os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase, cloudflare. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-principal-chat-sistema -b work/etapa2-r04-principal-chat-sistema origin/dev. Grave a primeira revisão da R04 em comunicacao/principal-chat-sistema.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize principal-chat-sistema.json, não encerre o turno antes de 04:20.

Recorte: famílias acontece, agora, momentos, principal_profile, chat, meal_plans, plans (composto), imports, catalog, error_pages, auth, shell (55 ações), ponta a ponta. O que você recebe: Momentos e Circulares já usam R2 em produção (moments-media v1, circular-media v5); Cardápios com arquivar/excluir em produção; feed do Acontece paginado; Fixar/bandeira do chat persistidas; usuário qa-r03@coelo.me para a rota real. Ordem: (1) migrations de storage_provider → r2 de Acontece (happens) e Agora (now) no padrão de Circulares, em candidatos/principal-chat-sistema (faixa 2026091019xxxx), com a fundação do Agora e o teste corrigido, pgTAP verde no projeto descartável; o coordenador aplica e faz o deploy de happens-media e now-media; (2) merge de wip/fase0-arquivo-chat (91e011dc6: ARQUIVO nos cards de Cardápios/Planos e launcher do chat "Mensagens" com contagem e iniciais, círculo claro no mobile) na sua branch, com os testes do launcher e a regravação após observação dos goldens de shell, Cardápios e Planos; (3) aplicar docs/reviews/evidence/etapa-2/r03-fase0/veu-destaque-orange950.patch (chip Destaque do Para você com orange950 a 16%, decisão da Fase 0) e regravar os goldens do Para você; (4) D3, não existe prévia: substituir os textos "indisponível nesta prévia" e "estará disponível na experiência completa" (ainda presentes em meal_plan_wizard, principal_chat, principal_for_you, happens/moments/now publication e preview pages) pelo comportamento real ou por "ainda não está disponível" quando a ação ainda não liga; a branch work/etapa2-noturna-copia-previa (80f160599) tem a redação, não faça merge em bloco; (5) rota normal com sessão: Auth e Shell → Cardápios → Chat administrativo e Principal (Criar grupo, P8, com o backend que o grupo realm-interno entrega em candidatos/realm-interno; combine o contrato por JSON e não bloqueie no resto) → Acontece (todas as ações ligadas) → Momentos → Perfil (Acompanhar/Seguidores/Seguindo alimentado pelo vínculo D1 do grupo acessos-pessoas; leitura do Sobre para membros, D9) → Agora (R2 master; Stream HOT até 24 h só quando a publicação exigir, D2) → Importações e Catálogo honestos → erro 409 na família existente; propor verified só com CRUD em produção, RLS negando outro tenant em pgTAP e reload mantendo; (6) goldens conforme as três listas de decisão do Owner (Acontece, Momentos, Perfil, Chat, Cardápios, Planos); sem balão de chat em criar/editar/publicar, Agora aberto e Momentos aberto. Entregue migration + pgTAP + chave por pacote. Escreva só em comunicacao/principal-chat-sistema.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/principal-chat-sistema e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; Cloudflare só pelo coordenador, Stream só no Agora; Principal preserva suas composições aprovadas dentro do Superadmin; coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G5 — «R04 · Realm interno e Chat backend» — Claude, Fable

**Resumo:** a frente que nunca foi entregue na R03. Confere o realm interno
v2 em produção contra o que o Chat exige e entrega, como pacotes sobre a
baseline, o contrato de produção do chat e o chat v2 (conversas, mensagens,
grupos com Criar grupo P8, fixar, sinalizadores), com pgTAP verde, para o
grupo principal-chat-sistema ligar a UI.

```text
Você é a conversa «R04 · Realm interno e Chat backend» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Fable). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/coordenacao.json (frenteNova e reativacaoDasFrentes.realm-interno), comunicacao/principal-chat-sistema.json e o handoff desse grupo (o que o Chat espera do backend), docs/reviews/coelo-supabase-pendencias.md (família chat e realm interno), packages/coelo_database/README.md (baseline, candidatos, histórico), AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend-backend, coelo-knowledge, supabase e supabase-postgres-best-practices. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-realm-interno -b work/etapa2-r04-realm-interno origin/dev (a worktree antiga e2-r03-realm-interno está quebrada e será removida pelo Owner; não a use). Grave a primeira revisão da R04 em comunicacao/realm-interno.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize realm-interno.json, não encerre o turno antes de 04:20.

Recorte (backend, faixa de carimbo 2026091024xxxx em candidatos/realm-interno): (1) medir em produção, por pg_proc/pg_class via supabase db query --linked (somente leitura), o que existe do realm interno v2 (o usuário qa-r03@coelo.me já está vinculado como Owner de plataforma) e o que a família chat consome no cliente (adapters e RPCs em apps/superadmin/lib/features/principal_chat e chat administrativo); listar a lacuna por objeto; (2) entregar como pacotes novos sobre a baseline, um por assunto e cada um com pgTAP verde no projeto descartável (db reset + seed + migrations/ + candidatos, na ordem): o contrato de produção do chat (chat_production_contract, hoje só no histórico em migrations-historico e no manifesto do replay), o chat v2 (conversas, mensagens com recibo e revisão, grupos com Criar grupo P8, fixar e sinalizadores já persistidos, edição/revogação com gateway), RLS deny-by-default, negativa cross-tenant e revokes explícitos de anon/authenticated nas tabelas e funções novas (o Supabase concede por padrão); (3) o que depender de notices/circulars v2 é do grupo publicacoes-agenda: combinar pelo JSON, não duplicar; (4) publicar o contrato (assinaturas, envelopes de erro, capacidades) em comunicacao/realm-interno.json para principal-chat-sistema ligar a UI, e responder às perguntas desse grupo pelo JSON; (5) o coordenador aplica em produção na ordem da fila; depois da aplicação, provar com a sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env) que os comandos persistem e o RLS nega outro tenant. Escreva só em comunicacao/realm-interno.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id (família chat) e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por objeto e action_id com prova, o que ficou aberto com o primeiro gate, deltas BE/E2E propostos, pacotes prontos na ordem de aplicação). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção, sem clientes reais; pacote verde vai para produção pelo coordenador sem pedir autorização, com dump por lote; presença do objeto decide aplicabilidade; produção é a forma canônica; MFA fora do MVP (nenhuma função nova exige AAL2); permissões por perfil com membership por instituição; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G6 — «R04 · Publicações e Agenda» — Claude, Opus

**Resumo:** Avisos, Circulares e Agenda. Conserta a cadeia de Avisos sobre a
baseline (labels NOT NULL, `p_notice`, `append_notice_audit`, `notice_events`
em analytics) e a de Circulares (labels), como pacotes que o coordenador
aplica; Comunicações e Agenda de eventos no composto; rota real com sessão.
Repassa tudo ao coordenador pelo JSON.

```text
Você é a conversa «R04 · Publicações e Agenda» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/publicacoes-agenda.json (revisão 12, sua história na R03), os três md de pendências em docs/reviews no recorte das famílias agenda, notices e circulars, packages/coelo_database/README.md, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-publicacoes-agenda -b work/etapa2-r04-publicacoes-agenda origin/dev. Grave a primeira revisão da R04 em comunicacao/publicacoes-agenda.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize publicacoes-agenda.json, não encerre o turno antes de 04:20.

Recorte: famílias agenda, notices e circulars (24 ações), ponta a ponta, do mais fácil ao mais difícil. O que você recebe: Circulares com R2 em produção (circular-media v5) e encerrar/excluir ligados no cliente; superadmin_circular_delete_v2 precisa entrar como pacote renumerado na faixa 2026091020xxxx; a cadeia de Avisos NÃO aplica sobre a baseline (labels NOT NULL, bug de p_notice, append_notice_audit ausente, notice_events em analytics), o que impede Avisos em produção. Ordem: (1) Avisos: pacotes em candidatos/publicacoes-agenda que corrigem a cadeia sobre a baseline (notices_v2), provados no projeto descartável (db reset + seed + migrations/ + candidato + pgTAP) e entregues ao coordenador com a ordem de aplicação; pg_cron e o worker notice-publication-worker são do coordenador; (2) Circulares: circulars_v2 (labels) e circular_delete como pacotes verdes; depois rota normal com sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env, app em localhost:3000): diretório, criar, agendar com campo inline, encerrar, excluir; (3) Agenda: contexto interno compatibilizado, readers/comandos produtivos, Agenda de eventos e Comunicações migradas ao composto CoeloAdminDirectory (pendência da Fase 0: _EventTable na allowlist do teste de arquitetura); rota normal listar/criar/editar/detalhe; (4) goldens conforme as três listas de decisão do Owner (agenda_*, communication_directory_*, notice_form_*, circular_directory_*), regravados só após a observação e no SDK 3.44.2. Propor verified só com CRUD em produção, RLS negando outro tenant em pgTAP e reload mantendo. Entregue migration + pgTAP + chave por pacote; o coordenador aplica e liga. Escreva só em comunicacao/publicacoes-agenda.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA: nenhuma pendência pode se perder e nenhum avanço pode ficar sem registro. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09 sem parar; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos na ordem de aplicação, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/publicacoes-agenda e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; Circulares com Agendar inline, Encerrar e Excluir (D4); coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```

## G7 — «R04 · Operações» — Claude, Opus

**Resumo:** Conta, Suporte, Planos e Auditoria. Suporte e Conta já têm SQL em
produção (lote 7): agora a rota real com sessão, o botão de Bug ligado ao
controlador no router de produção, e Planos e Auditoria sobre o composto.
Repassa tudo ao coordenador pelo JSON.

```text
Você é a conversa «R04 · Operações» da Rodada 4 (E2-R04-20260911) da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R04-prompts.md, depois comunicacao/operacoes.json (revisão 13, sua história na R03), os três md de pendências em docs/reviews no recorte das famílias support, account, plans e audit, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-operacoes -b work/etapa2-r04-operacoes origin/dev. Grave a primeira revisão da R04 em comunicacao/operacoes.json (round E2-R04-20260911) e agende /loop 15m Retome o recorte da Rodada 4 sem parar: próximo item executável, atualize operacoes.json, não encerre o turno antes de 04:20.

Recorte: famílias support, account, plans e audit (21 ações), ponta a ponta, do mais fácil ao mais difícil. O que você recebe: 20260910230019 (Suporte: 5 RPCs superadmin_support_*, RLS forçado em support_sessions) e 20260910230020 (Conta: 3 RPCs superadmin_account_*) estão em produção; o pgTAP de Suporte foi corrigido pelo coordenador (row_security_active não existe; a asserção usa pg_class). Ordem: (1) Conta: Perfil e Configurações na rota normal com sessão qa-r03@coelo.me (credencial em Coelo-backups/qa-r03.env, app em localhost:3000): editar, recarregar, provar; (2) Suporte: o router de produção não passa supportController (o botão de Bug abre e avisa que o envio não está conectado): ligar; tabela, kanban e detalhe na rota real com criar, responder, mudar status; toolbar de filtros e tabela no padrão do composto; (3) Planos sobre o composto (ARQUIVO nos cards chega pelo grupo principal-chat-sistema via wip/fase0-arquivo-chat: não duplicar); (4) Auditoria: candidato AUDIT-READ-V2 revisado sobre a baseline como pacote em candidatos/operacoes (faixa 2026091021xxxx), pgTAP verde no projeto descartável, entregue ao coordenador; diretório e filtros no padrão; (5) goldens conforme as três listas de decisão do Owner (support_kanban_*, support_table_*, support_detail_*, settings_*, profile_*, plan_cards_*, audit_directory_*), regravados só após a observação e no SDK 3.44.2. Propor verified só com CRUD em produção, RLS negando outro tenant em pgTAP e reload mantendo. Entregue migration + pgTAP + chave por pacote; o coordenador aplica e liga. Escreva só em comunicacao/operacoes.json e nos seus commits/handoffs; repasse TUDO ao coordenador por esse arquivo, com action_id e SHA: nenhuma pendência pode se perder e nenhum avanço pode ficar sem registro. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe até 04:20 de 11/09 sem parar; ao terminar antes, grave finalizado no JSON e faça a mini-revisão de 10 minutos (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas FE/BE/E2E propostos, pacotes prontos, dúvidas ao Owner). Depois de 04:20 não retome por conta própria.

Alinhamentos (ADR 0034, Decisões 1–12; detalhes no R04-prompts.md): régua do MVP por action_id; todo remoto é produção; pacote verde nasce em candidatos/operacoes e o coordenador aplica; presença do objeto decide aplicabilidade e produção é a forma canônica; MFA fora do MVP; import/export adiados com botão honesto; coelo-ui é a autoridade e as três listas de decisão de goldens valem por arquivo (R referência, A regravar após a observação); Pesquisar no menu, botão de Bug, rodapé ancorado com respiro, sem chat em criar/editar/publicar; composto único de diretório; nenhum segredo em Git, chat ou JSON; commits pequenos em português; só o coordenador escreve em dev, inventário e rastreadores; não parar até finalizar o recorte, até 04:20 ou até ordem do Owner ou do coordenador.
```
