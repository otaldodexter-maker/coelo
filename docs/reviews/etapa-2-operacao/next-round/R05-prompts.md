---
title: "Rodada 5 — contrato comum e prompts por conversa (tarde de 11/09/2026)"
source: "R04-prompts.md; coordenacao.json rev 35; ADR 0034 (Decisões 1–15); os três md de pendências em docs/reviews (bloco Estado vigente R04 e atualizações de 10:30, 11:05, 11:35 e 11:50); R04-perguntas-ao-owner-20260911.md (duas levas de respostas); ordem do Owner de 11/09/2026 à tarde"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 5 — contrato comum

Ponto de entrada de toda conversa da Rodada 5. Cada prompt manda ler este
arquivo e o `R04-prompts.md` (as regras de lá continuam valendo; aqui está só
o que mudou). Nada aqui inicia execução; a conversa começa quando o Owner
cola o prompt.

## Identificação e horários

- Rodada: `E2-R05-20260911`. Base: `origin/dev` no HEAD que contém este
  arquivo, conferido na abertura com `git fetch`. Raiz
  `C:/Users/adrie/Documents/Coelo`; recorte `apps/superadmin` e o que ele usa,
  inclusive o menu Coelo (Principal).
- **Frentes trabalham sem parar e entregam tudo ao coordenador até 15:45 de
  11/09/2026** (abertura por volta de 11:50): commits publicados, worktree
  limpa ou WIP nomeado, o que fechou, o que ficou pendente, deltas por
  action_id, pacotes SQL e dúvidas ao Owner.
- **15:50**: o coordenador pede a cada frente a revisão de 10 minutos ("você
  entregou tudo mesmo? o que ficou em aberto?"); as frentes respondem no
  JSON até 16:00. **Até 16:30**: o coordenador finaliza tudo (integração,
  worktrees, commits, md, spec, ADR, skills, arquivo da R05) e entrega ao
  Owner o percentual de progresso no formato fixo.
- Horário de relógio da máquina (America/Sao_Paulo). Em dúvida, a frente
  pergunta ao coordenador no JSON e continua trabalhando.

## Usuário e instituição sintéticos (valem para Claude e Codex)

- Usuário interno de teste `qa-r03@coelo.me`: credencial em
  `C:/Users/adrie/Documents/Coelo-backups/qa-r03.env` (ler do arquivo; nunca
  imprimir, colar em chat, commit, log ou JSON). O Owner decidiu (P37) que o
  **Codex também usa esse usuário** para verificar; toda conversa Codex recebe
  esta informação pelo prompt.
- A pessoa de serviço desse usuário (ponte de ator 220400) é owner ativa nas
  instituições sintéticas `qa-r04-chat`, `qa-r04-cuidado-sintetico` e
  `qa-r04-escola` (lote 27). Elas podem ser usadas para teste e validação
  (P25); ao final da Etapa 2 o coordenador pergunta ao Owner se as apaga.

## O que mudou desde a R04 (ler antes de começar)

- **Produção:** lotes 8 a 27 aplicados (71 pacotes) e 180150 (local ao criar atividade) pela frente estrutura. Novidades de 11/09:
  modelos de sistema de perfis (P31), decisão de Segurança infantil pelo
  Superadmin (P32), cron do worker de Avisos com `notice-publication-worker`
  implantada (P30), `qa-r03` owner nas três instituições sintéticas (P35 A).
- **Decisões do Owner (ADR 0034 Decisão 15 e tabela de respostas em
  `R04-perguntas-ao-owner-20260911.md`)** são para **executar dentro do ciclo
  das frentes**, cada uma no seu recorte; o coordenador não as executa fora
  dele. Lista por frente nos prompts abaixo.
- **Referência visual da Agenda:** calendário do iPhone, PNG mensal e diário
  em `docs/reviews/evidence/etapa-2/referencias/`; descrição na skill
  `coelo-ui` (baselines aprovadas). Vale sobre o golden guardado.
- **Segredos sem custo:** o agente cria e grava no secret store sem
  perguntar (Vault, secrets de Edge Function, tokens de escopo mínimo);
  valor nunca em chat, commit, log, JSON ou artefato; roteiro de geração e
  pendência de rotação na skill `coelo-backend`.
- **Memória da máquina:** no máximo dois Chrome/`flutter run` por conversa,
  um `flutter test` por vez, fechar Chrome e `dart` ao terminar cada prova
  (a máquina reiniciou às 00:27 de 11/09 por esgotamento).
- **Subagentes:** usar o máximo possível para provas paralelas (rota real,
  pgTAP, goldens), respeitando o limite de memória acima.

## Estado de partida (11:50 de 11/09, inventário validado)

| Camada | Estado |
| --- | --- |
| Front-end `verified` | 66/231 (28,57%) |
| Front-end `local-green` | 32/231 (13,85%) |
| Front-end aprovação visual do Owner | 52/231 (22,51%) |
| Back-end `local-green` | 90/224 (40,18%) |
| Back-end SQL aplicado em produção | 133/224 (59,38%) |
| Back-end `done` | 69/224 (30,80%) |
| E2E `verified-e2e` | 43/199 (21,61%) |

## Skills obrigatórias

`rtk` (prefixar comandos), `ponytail` (menor solução correta), `coelo-frontend`,
`coelo-backend`, `coelo-frontend-backend`, `coelo-ui`, `coelo-knowledge`,
`flutter-dart-code-review`, `supabase`; `cloudflare`/`wrangler` só no pacote
autorizado. O resto do contrato (comunicação por JSON, worktree por conversa,
mini-revisão, régua do MVP, autorizações) está em `R04-prompts.md`.

---

# Prompts por conversa

Colar cada bloco em uma conversa nova, com o nome e o modelo indicados. Ordem
de abertura: C0 primeiro, depois G1 a G7. Decisão do Owner de 11/09 à tarde: **toda a R05 roda no Claude com Opus em
esforço médio** (coordenação inclusive). Se ele quiser usar a cota do Codex,
G7 (Operações) é a frente mais simples e pode ir para ele com o mesmo prompt.

## C0 — «R05 · Coordenação da tarde» — Claude, Opus (esforço médio)

**Resumo:** única escritora de `dev`, do inventário e dos três rastreadores;
garante que nada se perca; aplica em produção os pacotes verdes; lê os JSONs a
cada 30 minutos e acorda conversa parada; às 15:50 pede a revisão de 10
minutos; a partir de 16:00 encerra, integra, limpa worktrees e commits, atualiza md,
spec, ADR, skills e R05, e até 16:30 entrega o percentual no formato fixo.

```text
Você é a conversa «R05 · Coordenação da tarde» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/coordenacao.json (revisão 35), os três md de pendências em docs/reviews (coelo-flutter-pendencias.md, coelo-supabase-pendencias.md, coelo-flutter-integrado-supabase-pendencias.md; bloco "Estado vigente — Rodada 4" com as atualizações de 10:30, 11:05, 11:35 e 11:50), decisions/0034-mvp-remote-application-and-acceptance-bar.md (Decisões 1–15), next-round/R04-perguntas-ao-owner-20260911.md (respostas do Owner, duas levas), AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend, coelo-frontend-backend, coelo-ui e coelo-knowledge. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-coordenacao -b work/etapa2-r05-coordenacao origin/dev. Nunca edite o checkout principal. Registre posse em coordenacao.json (revisão 36, round E2-R05-20260911, relógio da máquina) e agende /loop 30m Leia os JSONs das frentes, emita ACK, aplique pacotes verdes, integre e atualize rastreadores; liste ao Owner em uma linha as conversas sem revisão nova há mais de 30 minutos e mande-as retomar.

Responsabilidades: (1) única escritora de dev, de docs/reviews/inventario-etapa-2.json e dos três rastreadores; integrar as branches work/etapa2-r05-* por merge na sua worktree, rodar flutter analyze e os testes das famílias tocadas, aplicar deltas com node docs/reviews/apply-tracker-delta.cjs <deltas.json> (formato: action_id, camada frontend|backend|integrated, estado_proposto, delta, evidencia, certificacao{evidence com caminho docs/..., revision, environment, recordedAt}; verified-e2e exige FE verified e BE done), validar com node docs/reviews/validate-trackers.cjs, commits pequenos em português, push em dev; (2) aplicar em produção (projeto coelo, ref evvbomzejfijozbtgvpt) cada pacote verde de candidatos/<grupo>/ na ordem da fila: preflight no espelho supabase_db_coelo_baseline (docker; rebuild = db reset só com a baseline + psql de cada migration na ordem de packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt), dump por lote com supabase db dump --linked --workdir packages/coelo_database -f C:/Users/adrie/Documents/Coelo-backups/schema-producao-20260911-loteNN.sql (nunca --dry-run), aplicar com supabase db query --linked --workdir packages/coelo_database -f <caminho relativo ao workdir> (ALTER TYPE ADD VALUE em chamada separada), inserir no ledger supabase_migrations.schema_migrations, mover para migrations/, anotar o lote na ordem-de-aplicacao-producao.txt, ligar a chave de composição; (3) a frente estrutura da R04 foi pausada (rev 39 integrada) e sua worktree removida; o commit WIP 44574dfda (activities.edit no cliente, não verificado) está só na branch work/etapa2-r04-estrutura e é base do item de Atividades da frente G1; não o integre em dev sem a frente verificar; os dados sintéticos dela (groups 368a5cea, institutions 190dd028, units f5284f2f, activity_locations 82e92854) só saem de produção quando o Owner responder P42; (4) ler comunicacao/<grupo>.json das sete frentes (estrutura, acessos-pessoas, formularios-cuidado-rotina, principal-chat-sistema, realm-interno, publicacoes-agenda, operacoes), emitir ACK e recibo por revisão, responder bloqueios com o que já existe, acordar conversa parada avisando o Owner em uma linha; (5) segredos nunca em chat, commit, log ou JSON; credencial de qa-r03@coelo.me em Coelo-backups/qa-r03.env, e o usuário sintético vale também para o Codex (P37): garanta que toda conversa Codex saiba disso; segredos sem custo você cria e grava no secret store, com roteiro na skill coelo-backend; (6) máximo dois Chrome/flutter run por conversa e um flutter test por vez; (7) às 15:50 pedir em coordenacao.json a revisão de 10 minutos a cada frente (SHA publicado, o que fechou por action_id com prova, o que ficou aberto com o primeiro gate, deltas, pacotes, dúvidas ao Owner com imagens lado a lado); a partir de 16:00 encerrar: integrar tudo, status limpo, worktrees das frentes removidas depois de integradas (branches preservadas, WIP nomeado), rastreadores e inventário regenerados e validados, bloco "Estado vigente — Rodada 5" nos três md (o da R04 vira "Estado anterior"), skills coelo-backend/coelo-frontend/coelo-frontend-backend e coelo-ui com regra nova ou decisão do Owner, ADR 0034 com decisão nova, spec de métricas respeitada, portão de conhecimento (coelo-knowledge), next-round/R05-fechamento.md e perguntas ao Owner em next-round/R05-perguntas-ao-owner-20260911.md (em lote, com imagens lado a lado R/A quando visual); até 16:30 o fechamento ao Owner no formato fixo: tabela por camada com percentuais de duas casas e denominadores homogêneos (FE verified /231, FE local-green /231, FE aprovação visual /231, BE local-green /224, BE SQL em produção /224, BE done /224, E2E /199), sem percentual composto, sem plano no lugar de estado; aprovação visual nunca vira verified, done ou E2E; (8) ao final perguntar ao Owner se apaga as instituições sintéticas (P25) e listar as chaves criadas nesta rodada para rotação futura.

Estados distintos: recebido, integrado, aplicado em produção, verificado E2E. Não declarar E2E por teste local. Enquanto aguarda entregas, aplique a fila SQL, integre e feche dependências compartilhadas; não pare até 16:30 ou ordem do Owner. Foco em avançar: code review profundo fica registrado como pendência.
```

## G1 — «R05 · Estrutura» — Claude, Opus (esforço médio)

**Resumo:** fecha Instituições (edit, status, files, reload, mapa), Unidades
(filter, edit, status, reload, cópia de local), Turmas (membros, local),
Atividades e Avaliações na rota real; destrava `institutions.edit` com o
pacote de contatos/documento/pessoas em conjunto com G5.

```text
Você é a conversa «R05 · Estrutura» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/estrutura.json (revisão 39, sua história na R04 e as duas pausas) e a seção "Continuação depois do fechamento" de docs/reviews/evidence/etapa-2/r04-estrutura/handoff.md, os três md de pendências em docs/reviews no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-estrutura -b work/etapa2-r05-estrutura origin/dev. Grave a primeira revisão da R05 em comunicacao/estrutura.json (round E2-R05-20260911) e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize estrutura.json, não encerre o turno antes das 15:45.

Recorte (famílias institutions, units, groups, activities, assessments, locations; 49 ações; em E2E hoje: institutions.create, units.create, groups.create, groups.edit, locations.create-edit, locations.schedule). Ordem: (0) Atividades primeiro: activities.create já tem o cliente ligado (fetchFormOptions, 180150, build de qa_main refeito) e a prova na rota real ficou incompleta; prove criar e recarregar com qa-r03; para activities.edit faça cherry-pick do commit wip 44574dfda de work/etapa2-r04-estrutura (fetchById -> superadmin_activity_detail_v2, guarda de update com expected_version >= 1), deixe test/features/activities verde, rebuild e prove; antes de citar as suítes pgTAP de Locais dos lotes 46-49 como prova, rode-as de novo (a de autorização só passou após correção da fixture); (1) institutions.edit está blocked-decision porque o assistente exige CNPJ, representantes e administradores que a criação v2 não persiste: escrever em candidatos/estrutura (faixa 2026091118xxxx) o pacote institution_contacts_v1 (documento, contato, representantes/administradores como pessoas do realm interno), pgTAP verde, alinhar com realm-interno pelo JSON e fechar o edit na rota real; (2) institutions.list/filter/detail/status/files/error/access-denied/reload/locations-map e units.filter/edit/status/error/access-denied/reload/locations-map/copy-institution-location na rota normal com a sessão qa-r03 (credencial em Coelo-backups/qa-r03.env; build web -t test_driver/qa_main.dart --dart-define-from-file=.env.local, servidor estático com fallback SPA, Chrome com --remote-debugging-port e --use-angle=swiftshader; máximo dois Chrome por conversa, fechar ao terminar); (3) groups.members e groups.location; (4) activities.create/detail/edit/publish/assessment/location e assessments.entry/gradebook/close/reopen/detail (assessments.entry precisa de vínculo profissional do qa-r03: pacote em candidatos/estrutura) com as chaves assessmentMutationsEnabled/structureMutationsEnabled já ligadas; (5) locations.detail-links e locations.schedule. Perguntas P40 (ícone @ no Identificador) e P41 (Identificador vira @?) aguardam o Owner: aplicar a resposta quando chegar pelo coordenador; até lá manter o comportamento atual. Decisões do Owner a aplicar no recorte: P36 (não existe unidade sem instituição, turma sem unidade, atividade fora de turma: validar no servidor e no formulário), estado vazio mantém busca, filtros, toggle, Arquivos, abas e card Criar, cancelar à esquerda e salvar à direita no rodapé. Propor verified só quando CRUD persistir em produção, o RLS negar outro tenant em pgTAP e o reload manter. Escreva só em comunicacao/estrutura.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id e SHA. Foco em avançar; code review profundo vira pendência registrada.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final de 10 minutos (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/estrutura e o coordenador aplica; nenhum segredo em Git, chat ou JSON; commits pequenos em português; um flutter test por vez.
```

## G2 — «R05 · Acessos e Pessoas» — Claude, Opus (esforço médio)

**Resumo:** Pessoas, Perfis de acesso (com os modelos de sistema do P31 na
tela), Modelos de acesso, Convites, Usuários internos e Alunos na rota real.

```text
Você é a conversa «R05 · Acessos e Pessoas» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/acessos-pessoas.json (revisão 118), docs/reviews/evidence/etapa-2/r04-acessos-pessoas/, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-acessos-pessoas -b work/etapa2-r05-acessos-pessoas origin/dev. Grave a primeira revisão da R05 em comunicacao/acessos-pessoas.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize acessos-pessoas.json, não encerre o turno antes das 15:45.

Recorte (famílias people, access_profiles, access_models, invites, internal_users, students; 32 ações; em E2E hoje: access-models.create). O que você recebe: lote 25 em produção com os modelos de sistema de perfis (20260910171600, P31) e a ponte de ator (220400): o Superadmin interno tem pessoa de serviço e membership owner nas instituições sintéticas. Ordem: (1) access-profiles.list/create/detail/edit/assign/delete na rota real: os modelos de sistema aparecem, não são editáveis pela unidade, e criar oferece "do zero" ou "a partir do modelo" (P31); (2) people.list/create/edit/links/reload (people.create está fail-closed: abrir com a ponte de ator); (3) access-models.list/filter/detail/edit/duplicate; (4) invites.list/create/detail/resend/revoke (create está blocked-decision: registrar o gate real e, se for só contrato, escrever o pacote em candidatos/acessos-pessoas na faixa 2026091117xxxx); (5) internal-users.list/create/edit/suspend (create fail-closed) e students.list/link/transfer/edit/revoke respeitando P36 (aluno sempre em turma de unidade de instituição). Professores atrelados a turmas e atividades, com papéis distintos por unidade (P31): não bloquear, registrar como pendência de modelo se faltar contrato. Régua: rota normal, CRUD em produção, RLS nega outro tenant, reload mantém. Escreva só em comunicacao/acessos-pessoas.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id e SHA.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/acessos-pessoas e o coordenador aplica; nenhum segredo em Git, chat ou JSON; credencial de qa-r03 em Coelo-backups/qa-r03.env; commits pequenos em português; máximo dois Chrome por conversa e um flutter test por vez.
```

## G3 — «R05 · Formulários, Cuidado e Rotina» — Claude, Opus (esforço médio)

**Resumo:** respostas e arquivos de Formulários, publicar/visão geral, Segurança
infantil (P32), Cuidado, Medicação, Assiduidade e Rotina na rota real; confere
o dispatch de Formulários que respondeu 404.

```text
Você é a conversa «R05 · Formulários, Cuidado e Rotina» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/formularios-cuidado-rotina.json (revisão 33), docs/reviews/evidence/etapa-2/r04-formularios-cuidado-rotina/, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-formularios-cuidado-rotina -b work/etapa2-r05-formularios-cuidado-rotina origin/dev. Grave a primeira revisão da R05 em comunicacao/formularios-cuidado-rotina.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize formularios-cuidado-rotina.json, não encerre o turno antes das 15:45.

Recorte (famílias forms_authoring, forms_responses, forms_files, child_safety, health_care, medication, attendance, daily_routine; 43 ações; em E2E hoje: forms.list/create/edit, medication.list). O que você recebe: lote 25 com a decisão de Segurança infantil pelo Superadmin (20260910171800, P32 B), lote 23 com o diretório de contexto de criança e o snapshot de local; goldens do editor regravados com aprovação. Ordem: (1) forms.publish e forms.overview na rota real; (2) forms.monitor/respond/responses/response-detail/responses.export (XLSX no R2 privado com reautorização, sem CSV/ZIP/PDF) e forms.location-answer; (3) forms.upload/resolve-file/download/expire-file/delete-file com form-media em R2 (backend está blocked: registrar o gate real e escrever o pacote em candidatos/formularios-cuidado-rotina na faixa 2026091122xxxx se for contrato); (4) child-safety.list/child/create/edit/suspend com a decisão do Superadmin auditada; a regra alvo do Owner (notificar no sino unidade, hierarquia da criança e demais responsáveis; tela de políticas macro da unidade: aceite para liberar, só inclusão, só exclusão; mesmo conceito para Medicação, com opção de não acompanhar) entra como spec curta em docs/superpowers/specs e como pacote de notificações se couber; (5) health-care.create/detail/edit e medication.create/detail/edit/evidence (fail-closed/blocked: abrir com a ponte de ator e a instituição sintética); (6) attendance.create/mark/correct/finish/dashboard e daily-routine.create/edit/apply/publish (create bloqueava as demais). Achado a conferir primeiro, 10 minutos: o cron coelo-forms-worker-dispatch recebe 404 "Requested function was not found"; comparar o nome em forms_worker_url do Vault (só o nome da função, nunca o valor completo em chat) com a função implantada form-operations e corrigir via vault.update_secret em pacote sem segredo. Escreva só em comunicacao/formularios-cuidado-rotina.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id e SHA.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; credencial de qa-r03 em Coelo-backups/qa-r03.env; commits pequenos em português; máximo dois Chrome por conversa e um flutter test por vez; estado vazio mantém filtros, toggle, Arquivos, abas e card Criar; sem chat em criar/editar/publicar.
```

## G4 — «R05 · Principal, Chat e Sistema» — Claude, Opus (esforço médio)

**Resumo:** Acontece, Agora, Momentos, Perfil e Para Você (P28 e P35 B, perfil
Coelo), Cardápios, chat.attach e páginas de erro na rota real.

```text
Você é a conversa «R05 · Principal, Chat e Sistema» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/principal-chat-sistema.json (revisão 20), docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/, os três md de pendências no recorte das suas famílias, a resposta integral do Owner a P28, P35 e P26 em next-round/R04-perguntas-ao-owner-20260911.md, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-principal-chat-sistema -b work/etapa2-r05-principal-chat-sistema origin/dev. Grave a primeira revisão da R05 em comunicacao/principal-chat-sistema.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize principal-chat-sistema.json, não encerre o turno antes das 15:45.

Recorte (famílias acontece, agora, momentos, principal_profile, chat, meal_plans, error_pages; 35 ações; em E2E hoje: chat 6 ações; 409 aprovado). O que você recebe: lote 27 deu ao qa-r03 membership owner nas três instituições sintéticas, então o Principal deixa de estar bloqueado por P35; happens-media e now-media em R2 implantadas. Ordem: (1) acontece.feed/create/publish/remove, agora.view/create/publish/expire (Stream só 24 h), momentos.view/create/publish/remove na rota real com qa-r03; (2) principal.profile-view/profile-edit/for-you aplicando P28 (avatar não cortado pelo nome; cabeçalho igual ao mobile, com a nossa logo e espaçamento; @ do perfil visível; botão "+ Agora" só para quem pode publicar e leva ao Acontece; filtros por criança/perfil no menu do perfil com até 5 itens e "ver todos" em popup; usuários híbridos escolhem ver como Responsável, Funcionário ou ambos e confirmam o perfil antes de publicar; avatares de vínculos sobrepostos com contorno) e P35 B (Superadmin vê tudo no Principal como regra de produto; criar o perfil/usuário Coelo, com a logo laranja/coelho branco e capa da marca, que segue e é seguido por todos, arrobas coelo e coelo.me reservados: pacote em candidatos/principal-chat-sistema na faixa 2026091113xxxx); (3) meal-plans.create/edit/model-create/model-edit/publish (Duplicar: ícone no card e item no menu, P27); (4) chat.attach (FE e BE blocked: registrar o gate real e propor o pacote) e chat.create-group FE verified para E2E; (5) errors.409 na rota real e errors.retry; (6) falhas pré-existentes em composition_root_sanitization_test e superadmin_auth_scope_test apontadas pela frente estrutura: conferir se são do seu recorte (composição/shell) e corrigir ou registrar com o gate real. Sem chat em criar/editar/publicar nem no Agora e Momentos abertos (Decisão 7). Escreva só em comunicacao/principal-chat-sistema.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id e SHA; dúvidas visuais em página lado a lado (R referência, A render atual).

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; credencial de qa-r03 em Coelo-backups/qa-r03.env; commits pequenos em português; máximo dois Chrome por conversa e um flutter test por vez.
```

## G5 — «R05 · Realm interno e Chat backend» — Claude, Opus (esforço médio)

**Resumo:** backend transversal: persistência de documento, contato e pessoas
da instituição (destrava `institutions.edit`), varredura de grants de
`authenticated` sem policy, anexos do chat e arquivos de formulários no R2,
hierarquia P36 no servidor, notificações de Segurança infantil.

```text
Você é a conversa «R05 · Realm interno e Chat backend» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/realm-interno.json (revisão 15), docs/reviews/evidence/etapa-2/r04-realm-interno/ (inclusive a varredura de grants de authenticated), docs/reviews/coelo-supabase-pendencias.md integralmente e os outros dois md no que cruzar, decisions/0034 (Decisões 13 e 15), AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend-backend, coelo-knowledge, supabase e supabase-postgres-best-practices. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-realm-interno -b work/etapa2-r05-realm-interno origin/dev. Grave a primeira revisão da R05 em comunicacao/realm-interno.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize realm-interno.json, não encerre o turno antes das 15:45.

Recorte (backend transversal, faixa de carimbo 2026091121xxxx em candidatos/realm-interno; pgTAP verde no seu projeto descartável antes de entregar; o coordenador aplica). Ordem: (1) institution_contacts_v1 em conjunto com estrutura: documento (CNPJ), contatos, representantes e administradores da instituição como pessoas do realm interno, com RLS por instituição e auditoria; (2) varredura de grants CRUD de authenticated sem policy (pendência da R04): pacote que revoga ou cobre com policy, tabela por tabela, pgTAP negativo cross-tenant; (3) chat.attach: contrato de anexo no chat sobre private_media_catalog e R2 (coelo-media-prod), sem Stream; (4) forms_files: contrato de upload/resolve/download/expire/delete de arquivos de formulários no R2, reautorização server-side, expiração e auditoria (a frente formularios consome); (5) P36 no servidor: constraints e checks que impedem unidade sem instituição, turma sem unidade, atividade sem turma; (6) P32 regra alvo: notificações no sino para unidade, hierarquia da criança e demais responsáveis, e tabela de políticas macro da unidade (segurança infantil e medicação) com defaults; (7) pendências de code review da R04 (180060 create or replace; sobrecarga de 14 args de audit_append_superadmin_internal) só se sobrar tempo. Segredos sem custo você cria e grava no Vault/secrets sem perguntar; valor nunca em chat, commit, log ou JSON; roteiro de geração na skill coelo-backend. Escreva só em comunicacao/realm-interno.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id, pacote e SHA.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores e aplica em produção; commits pequenos em português; um projeto Supabase descartável por conversa, parado ao terminar.
```

## G6 — «R05 · Publicações e Agenda» — Claude, Opus (esforço médio)

**Resumo:** Agenda com a referência do iPhone (P33 e P34), pedidos, permissões
e local da Agenda, Avisos agendar na rota real, Circulares editar, agendar,
responder e anexar.

```text
Você é a conversa «R05 · Publicações e Agenda» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/publicacoes-agenda.json (revisão 30), docs/reviews/evidence/etapa-2/r04-publicacoes-agenda/, a resposta integral do Owner a P33 e P34 em next-round/R04-perguntas-ao-owner-20260911.md, a seção "Referência do Owner de 2026-09-11 para o calendário da Agenda" em .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md e os PNG em docs/reviews/evidence/etapa-2/referencias/, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-publicacoes-agenda -b work/etapa2-r05-publicacoes-agenda origin/dev. Grave a primeira revisão da R05 em comunicacao/publicacoes-agenda.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize publicacoes-agenda.json, não encerre o turno antes das 15:45.

Recorte (famílias agenda, notices, circulars; 24 ações; em E2E hoje: agenda 4, notices 5, circulars 7). O que você recebe: lote 26 com o cron do worker de Avisos e notice-publication-worker implantada (o agendamento agora materializa sozinho). Ordem: (1) P33 (R) no calendário da Agenda: grade fora de contêiner, cantos menos redondos, número do dia menor no canto superior esquerdo com respiro, toggle calendário/lista dividindo 50% centralizado, eventos como pastilhas empilhadas, hoje em círculo cheio, cancelado hachurado com prefixo CANCELADO, botão Hoje no rodapé, conforme a referência do iPhone; o calendário mostra tudo que a hierarquia permite (eventos, aniversários, provas) e o filtro por criança/perfil fica no menu do perfil; (2) P34 (A+): rodapé/indicador de status igual ao de criar/editar Instituição, sem fundo cinza, cancelar à esquerda e salvar à direita; regravar goldens agenda_calendar_* só depois das correções, no SDK 3.44.2, e mandar ao coordenador a página lado a lado (R referência iOS, A render atual) para o Owner aprovar; (3) agenda.request/permissions/location na rota real; (4) notices.schedule FE local-green para verified com o agendamento materializado pelo worker real; (5) circulars.edit/schedule/respond/attach (attach com circular-media em R2). Escreva só em comunicacao/publicacoes-agenda.json e nos seus commits/handoffs; repasse tudo ao coordenador com action_id e SHA.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/publicacoes-agenda (faixa 2026091119xxxx) e o coordenador aplica; nenhum segredo em Git, chat ou JSON; credencial de qa-r03 em Coelo-backups/qa-r03.env; commits pequenos em português; máximo dois Chrome por conversa e um flutter test por vez.
```

## G7 — «R05 · Operações» — Claude, Opus (esforço médio) (ou Codex, se o Owner preferir)

**Resumo:** Auditoria, Conta (sessões e sair), Catálogo, Planos, alinhamento
das tabelas de Suporte e Implantação (G-SUP), Importações e Arquivos de
perfil com indisponibilidade honesta.

```text
Você é a conversa «R05 · Operações» da Rodada 5 (E2-R05-20260911) da Etapa 2 do Coelo (Claude, Opus, esforço médio; ou Codex com este mesmo prompt). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R05-prompts.md e R04-prompts.md, depois comunicacao/operacoes.json (revisão 20), docs/reviews/evidence/etapa-2/r04-operacoes/, a resposta do Owner a G-SUP em next-round/R04-perguntas-ao-owner-20260911.md, os três md de pendências no recorte das suas famílias, AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r05-operacoes -b work/etapa2-r05-operacoes origin/dev. Grave a primeira revisão da R05 em comunicacao/operacoes.json e agende /loop 15m Retome o recorte da Rodada 5 sem parar: próximo item executável, atualize operacoes.json, não encerre o turno antes das 15:45.

Recorte (famílias support, audit, account, catalog, plans, imports, profile_files; 38 ações; em E2E hoje: support 6, account.profile). Ordem: (1) G-SUP (A+): alinhamento das colunas das tabelas de Suporte e Implantação igual à tabela de Instituições (origem e demais colunas alinhadas à esquerda no mesmo eixo), goldens regravados após a correção e página lado a lado para o Owner; (2) audit.list/filter/detail na rota real (o candidato SQL de auditoria retido na R01: revisar, provar em pgTAP e entregar em candidatos/operacoes na faixa 2026091120xxxx); (3) account.sessions e account.logout; (4) catalog.validate/sync/publish e plans.list/create/edit/activate/assign (backend pending: escrever o contrato mínimo com RLS ou registrar o gate real); (5) imports.* e profile_files.*: botões visíveis com indisponibilidade honesta, sem picker, parser, job ou persistência (ADR 0034), goldens conforme as listas de decisão do Owner. Estado vazio mantém busca, filtros, toggle, Arquivos, abas e card Criar. Usuário sintético de teste: qa-r03@coelo.me, credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r03.env (ler do arquivo, nunca imprimir); o Owner decidiu que o Codex também usa esse usuário e as instituições sintéticas qa-r04-* para verificar. Escreva só em comunicacao/operacoes.json e nos seus commits/handoffs; repasse tudo ao coordenador Claude com action_id e SHA pelo JSON e pelos commits da sua branch; nenhuma pendência pode se perder.

Horário: trabalhe sem parar até 15:45; ao terminar, grave finalizado no JSON e faça a mini-revisão de 10 minutos; às 15:50 o coordenador pedirá a revisão final (responder no JSON até 16:00). Depois de 16:00 não retome por conta própria. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; commits pequenos em português; máximo dois Chrome por conversa e um flutter test por vez.
```
