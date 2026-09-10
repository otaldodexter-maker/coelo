---
title: "Rodada 3 — contrato comum e prompts por conversa"
source: "R03-plano.md; decisões do Owner em 10/09/2026; ADR 0034 (Decisões 1–5); docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md; TRABALHO-ATUAL.md (protocolo de comunicação)"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Rodada 3 — contrato comum

Este arquivo é o ponto de entrada de toda conversa da Rodada 3. Cada prompt
manda ler este documento integralmente e o [plano](R03-plano.md). Nada aqui
inicia execução; a conversa começa quando o Owner cola o prompt.

## Identificação

- Rodada: `E2-R03-20260910`. Base: `dev` no HEAD que contém este arquivo,
  conferido na abertura. Raiz: `C:/Users/adrie/Documents/Coelo`.
- Recorte: `apps/superadmin` e os packages/backends que ele usa, inclusive o
  menu Coelo (Principal). Admin, Principal e Site ficam fora.
- Todo checkpoint identifica `Etapa 2 → apps/superadmin → menu → tela →
  subtela/estado → action_id`.

## Ordem que vale para todas as conversas

**Não parar de trabalhar de forma alguma até finalizar o recorte, ou até ordem
do Owner ou do coordenador.** Terminou um item, vai ao próximo executável.
Bloqueio retém só o dependente; o restante continua. Sem trabalho independente,
avisar o coordenador uma vez e pedir atribuição, sem ficar em espera.

Nenhuma pendência se perde e nenhum avanço fica sem registro. Cada correção,
regressão, bloqueio ou mudança de estimativa gera atualização no mesmo turno
do `comunicacao/<grupo>.json`; o coordenador reflete nos três rastreadores
(`docs/reviews/coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md`,
`coelo-flutter-integrado-supabase-pendencias.md`) e no inventário. Regra nova
ou decisão do Owner vai também para a skill correspondente e para a ADR.

## Régua e autorizações vigentes (ADR 0034)

- Ação verificada no MVP: rota normal abre sem fixture nem fail-closed; CRUD
  persiste no Supabase de produção; RLS nega outro tenant; reload mantém
  estado. Provas exaustivas ficam para a revisão profunda, registradas.
- Pacote SQL verde em pgTAP local vai para produção no mesmo turno, pelo
  coordenador, na ordem da fila, com backup por ponto no tempo ligado. Não pedir
  autorização por pacote. Executores entregam migration + pgTAP + candidato de
  chave de composição; o coordenador aplica e liga a chave.
- Pacote Cloudflare da Decisão 5 (CORS restrito, lifecycle do transitório,
  token R2 mínimo nos secrets das Edge Functions, migração de `happens-media`,
  `now-media`, `moments-media` para R2, spike com dados sintéticos) está
  autorizado e é executado só pelo coordenador. Qualquer outro recurso
  Cloudflare exige decisão nominal.
- Custo zero: piloto no nível gratuito do R2; Stream só no Agora por até 24 h
  e só quando a publicação exigir. Nada mais vai para o Stream.
- MFA fora do MVP (AAL1). Import/export continuam adiados, botões visíveis e
  honestos; exceção `forms.responses.export` (XLSX no R2).
- Nenhum segredo em Git, bundle, log, URL ou frontend. Token que aparecer em
  chat, anexo ou diff está comprometido.

## Visual

- `coelo-ui` é a autoridade. Ler a
  [lista de decisões dos goldens](../../evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md)
  antes de tocar qualquer tela: ela diz, por arquivo, se vale a referência
  guardada ou o render atual, e traz as regras transversais (MENU, MENU-M,
  CHAT, CRIAR, TABS, RODAPÉ, FUNDO, TABELA, FLYOUT, ARQUIVO, ARQUIVOS-CHAT,
  SHELL, MAIS, IMG, FOTO).
- Conceito de família vive uma vez no composto compartilhado (Fase 0). Feature
  não declara Table, Toolbar, Pagination, Header ou Directory próprios.
  Correção repetida em várias telas pertence ao composto: propor ao
  coordenador, não copiar para a tela.
- Goldens escuros seguem o claro de mesmo nome. Regravar só depois de aplicar
  a observação do item e no mesmo SDK da suíte (Flutter 3.44.2 stable, a
  registrar em `.fvmrc`/`.flutter-version` na Fase 0).
- Dúvida visual ou decisão nova: preparar página com imagens lado a lado para
  o Owner, via coordenador. Ele decide mais rápido do que o agente.

## Skills obrigatórias

Carregar uma vez e reutilizar: `rtk` (prefixar comandos), `ponytail` (menor
solução correta), `coelo-frontend` (`.agents/skills/coelo-flutter-review`),
`coelo-backend` (`.agents/skills/coelo-supabase`), `coelo-frontend-backend`
(`.agents/skills/coelo-flutter-supabase-review`), `coelo-ui`,
`coelo-knowledge`, `flutter-dart-code-review` para Dart, skill oficial
`supabase` e boas práticas Postgres para SQL/RLS, `cloudflare` e
`cloudflare-manager` quando o provedor entrar no recorte. Caminho ausente:
descobrir a instalação real, sem inventar carregamento.

## Comunicação e entrega

- Raiz: `docs/reviews/etapa-2-operacao/comunicacao/`. `coordenacao.json` é
  escrito só pelo coordenador; `<grupo>.json` só pelo executor do grupo,
  sobrescrito de forma atômica. Executores não editam rastreadores,
  inventário, assignments nem arquivos de outro grupo.
- Abertura: executor grava revisão 1 (identificação, ferramenta/modelo,
  worktree, branch, HEAD, recorte, primeiro gate). Coordenador responde ACK.
  Trabalho independente não espera ACK.
- Atualizar ao fechar correção, publicar lote, mudar bloqueio, antes de comando
  longo e pelo menos a cada 30 minutos ativo. Campos: revisão/hora; grupo;
  worktree/branch/HEAD; tela/subtela/action_ids; o que mudou; critérios
  fechados; testes P/F/B/S/U; arquivos reservados; bloqueio e próximo passo;
  proposta de delta FE/BE/E2E por ID. Nenhum campo desconhecido vira zero.
- Handoff de meia página ao encerrar cada tela/subtela: base (SHA), o que
  fechou, o que ficou aberto com o primeiro gate, próximo passo.
- Worktree por grupo: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-<grupo>`,
  branch `work/etapa2-r03-<grupo>`, criada a partir do HEAD registrado em
  `coordenacao.json` (após a Fase 0). Commits pequenos e frequentes; push da
  branch do grupo; só o coordenador escreve em `dev`.
- Antes da Fase 0 publicar a base: executores fazem leitura e trabalho de
  backend (migrations, pgTAP, repositórios, contratos) que não toca UI de
  diretório. Ao receber a base, rebase e seguir para telas.
- Entrega final: commits integráveis, status limpo ou WIP identificado,
  igualdade com o remoto, inventário de cleanup, handoff final.

## Decisões do Owner ainda abertas (defaults até resposta)

Quando o Owner responder, o coordenador propaga. Até lá vale o default:

| # | Decisão | Default recomendado |
| --- | --- | --- |
| D1 | Perfil Principal | **Respondida:** a referência aprovada com **Acompanhar**, Seguidores e Seguindo continua valendo. Regra de produto: ao cadastrar uma criança em unidade, turma e demais níveis, ela e seus responsáveis passam a acompanhar automaticamente toda a hierarquia acima, inclusive a instituição. Precisa de fonte de dados real por trás das seções (backend do grupo principal-chat-sistema com acessos-pessoas). |
| D2 | Stream no Agora | **Respondida:** manter o Stream com a estratégia de 24 horas do Agora (ADR 0032). Sem arquivo não há custo; o primeiro bloco de armazenamento do Stream só é cobrado quando o primeiro vídeo for promovido. Nada além do Agora vai ao Stream. |
| D3 | Mensagens "nesta prévia" em Acontece, Agora e Momentos | Aplicar o patch: ação some sem capacidade, como Perfil e Para Você já fazem |
| D4 | Circulares: Agendar, Encerrar e Excluir | **Respondida: sim**, os três, com campo inline. |
| D5 | Feed do Acontece: usar o cursor do servidor em vez do teto de 20 itens | Sim |
| D6 | Rota Testar de Formulários como leitura autorizada | Sim, leitura autorizada por capacidade |
| D7 | Lançamentos da Rotina | **Respondida: tela mínima** no MVP, sobre o comando `daily-routine.publish` já existente. |
| D8 | Guarda de saída do editor de Rotina pela barra lateral (move 6 goldens) | Ligar, igual a Instituições |
| D9 | Leitura do Sobre do Perfil | **Respondida: sim**, criar a capacidade de leitura para membros. |
| D10 | Página de erro 409 | **Respondida:** família das páginas de erro existentes. |
| D11 | Chave de idempotência da Assiduidade (OQ-040): gerada no servidor por RPC | Sim, servidor |

---

# Prompts por conversa

Colar cada bloco em uma conversa nova, na ferramenta indicada. O rótulo diz
qual ferramenta e modelo. Ordem de abertura: P0, depois P1, depois os demais.

## P0 — Fase 0: composto de diretório — Claude, Fable

**Resumo:** constrói o composto único de diretório administrativo em
`coelo_ui_admin`, migra os 13 diretórios, aplica as decisões dos goldens, cria
o teste de arquitetura e registra o SDK. Entrega a base sobre a qual todas as
frentes trabalham. Escritor único de `dev` até publicar a base.

```text
Você é a Fase 0 da Rodada 3 da Etapa 2 do Coelo (Claude, Fable). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias (rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase, cloudflare). Trabalhe no checkout principal C:/Users/adrie/Documents/Coelo, branch dev, como escritor único até publicar a base da Fase 0.

Recorte: (1) composto de diretório administrativo em packages/coelo_ui_admin com cabeçalho (Pesquisar no menu, botão de Bug, cabeçalho mobile MENU-M), toolbar de filtros, abas Todos/Ativos/Rascunhos/Inativos, toggle card/tabela, grid com card Criar primeiro inclusive vazio e falha, tabela no padrão, paginação, chat, larguras 375/768/1024/1440, com botão Arquivos configurável (escondido em Conversas); (2) migração dos 13 diretórios (institutions, units, groups, activities, forms, support, agenda, meal_plans, plans, audit, health_care, chat, circulars) e dos demais que tiverem diretório; (3) aplicação da lista docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md: R volta à referência, A regravado após a observação, escuro segue o claro; (4) teste de arquitetura em apps/superadmin/test que falha quando uma feature declara Table, Toolbar, Pagination, Header ou Directory próprios; (5) registrar o SDK em .fvmrc/.flutter-version e vendorizar a fonte de ícones se necessário para os goldens ficarem estáveis; (6) regressões apontadas: chat sem Criar grupo/Fixar/bandeiras, confirmação de saída de Instituições, chip Destaque (véu orange950 a 16%).

Ordem: composto e goldens do composto; Instituições e Atividades como instâncias; demais diretórios; teste de arquitetura; regravação. Commits pequenos em português, push em dev a cada lote verde. Ao terminar, grave em docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json o campo base.fase0Head com o SHA e um handoff de meia página em next-round/R03-fase0-handoff.md. Toda decisão visual nova vai ao Owner com imagens lado a lado, sem regravar antes. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner; não há coordenador acima de você nesta fase.
```

## P1 — Coordenação e Integração — Claude, Fable

**Resumo:** único integrador de `dev` e escritor dos rastreadores; aplica os
pacotes SQL em produção na ordem da fila; executa o pacote Cloudflare
autorizado; lê os JSON de Codex e Claude, emite ACK e recibos; mantém as
pendências e os avanços registrados; leva dúvidas ao Owner em lote.

```text
Você é a Coordenação e Integração da Rodada 3 da Etapa 2 do Coelo (Claude, Fable). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md, as três skills coelo-frontend/coelo-backend/coelo-frontend-backend, coelo-ui, coelo-knowledge, rtk, ponytail, supabase, cloudflare e cloudflare-manager. Trabalhe no checkout principal C:/Users/adrie/Documents/Coelo, branch dev. Registre sua posse em comunicacao/coordenacao.json (rodada E2-R03-20260910, revisão 1) depois de confirmar que a Fase 0 publicou base.fase0Head; se ainda não publicou, comece pelo pacote Cloudflare e pela fila SQL, que não dependem dela.

Responsabilidades: (1) único escritor de dev, do inventário e dos três rastreadores; integrar continuamente, seletivamente por hunks, verificando na base conjunta; (2) aplicar em produção, na ordem da fila e com backup por ponto no tempo ligado, cada pacote SQL verde em pgTAP local, ligar a chave de composição correspondente e registrar o que ficou aberto; (3) executar o pacote Cloudflare da Decisão 5 da ADR 0034: CORS restrito nos três buckets, lifecycle de expiração em coelo-transient-prod, token R2 de escopo mínimo guardado nos secrets das Edge Functions, migração de happens-media, now-media e moments-media para R2, conclusão do spike em docs/spikes/media-r2 com dados sintéticos; nada além disso no Cloudflare sem decisão nominal; (4) ler comunicacao/<grupo>.json de todos os grupos (dois Codex, quatro Claude), emitir ACK e recibo por revisão, transferir residual de Codex para Claude quando o Codex parar; (5) atualizar rastreadores e inventário no mesmo ciclo de integração; nenhuma pendência se perde, nenhum avanço fica sem registro; validar com node docs/reviews/validate-trackers.cjs e o portão de conhecimento; (6) juntar dúvidas de UI/UX, Supabase e Cloudflare em lote para o Owner, com imagens lado a lado quando for visual, usando os defaults da tabela de decisões abertas até resposta; (7) commit e push em dev em português, pequenos e frequentes.

Estados distintos: recebido, integrado, aplicado em produção, verificado E2E. Não declarar E2E por teste local. Não pare de trabalhar de forma alguma até o Owner encerrar a rodada; enquanto aguarda entregas, integre, aplique a fila SQL, execute Cloudflare e feche dependências compartilhadas.
```

## P2 — publicacoes-agenda — Codex, Luna médio

**Resumo:** Agenda, Avisos e Circulares ponta a ponta, do mais fácil ao mais
difícil: três cadastros parecidos com público, agendamento e publicação. Sem
mídia nova (Circulares já usa R2). Repassa tudo ao coordenador Claude por
arquivo.

```text
Você é o grupo publicacoes-agenda da Rodada 3 da Etapa 2 do Coelo (Codex). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias em .agents/skills: rtk, ponytail, coelo-flutter-review (coelo-frontend), coelo-supabase (coelo-backend), coelo-flutter-supabase-review (coelo-frontend-backend), coelo-ui, coelo-knowledge, flutter-dart-code-review, e a skill supabase; cloudflare só se uma ação exigir. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-publicacoes-agenda, branch work/etapa2-r03-publicacoes-agenda, criada a partir de base.fase0Head em comunicacao/coordenacao.json; se ainda não existir, comece pelo backend (migrations, pgTAP, repositórios) e rebase quando a base sair.

Recorte: famílias agenda, notices e circulars do inventário docs/reviews/inventario-etapa-2.json (24 ações). Ordem: comece pelo que fecha E2E mais fácil: Agenda listar/criar/editar; Avisos criar/agendar/publicar (o pg_cron e o worker vêm da fila do coordenador; entregue a migration e o teste); Circulares diretório, criar, agendar com campo inline, encerrar, excluir (defaults D4). Para cada action_id prove a régua do MVP: rota normal abre, CRUD persiste no Supabase de produção pelo repositório produtivo, RLS nega outro tenant (pgTAP), reload mantém estado. Telas seguem o composto da Fase 0 e a lista de decisões dos goldens; não crie Table, Toolbar, Pagination ou Header próprios; observação que se repete vai ao coordenador como proposta para o composto.

Comunicação: escreva somente em docs/reviews/etapa-2-operacao/comunicacao/publicacoes-agenda.json (revisão 1 na abertura; atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e nos seus commits/handoffs. Repasse TUDO ao coordenador Claude por esse arquivo: cada avanço, cada pendência, cada teste, cada bloqueio, com action_id e SHA; nada pode se perder. Não edite rastreadores, inventário nem arquivos de outro grupo; só o coordenador escreve em dev. Commits pequenos em português, push da sua branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador; bloqueio retém só o dependente.
```

## P3 — operacoes — Codex, Luna médio

**Resumo:** Suporte, Conta, Planos e Auditoria ponta a ponta. Sem mídia.
Suporte e Conta ganham camada Supabase agora. Do mais fácil ao mais difícil.

```text
Você é o grupo operacoes da Rodada 3 da Etapa 2 do Coelo (Codex). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias em .agents/skills: rtk, ponytail, coelo-flutter-review (coelo-frontend), coelo-supabase (coelo-backend), coelo-flutter-supabase-review (coelo-frontend-backend), coelo-ui, coelo-knowledge, flutter-dart-code-review, e a skill supabase. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-operacoes, branch work/etapa2-r03-operacoes, criada a partir de base.fase0Head em comunicacao/coordenacao.json; se ainda não existir, comece pelo backend e rebase quando a base sair.

Recorte: famílias support, account, plans e audit do inventário (21 ações). Ordem, do mais fácil: Conta (Perfil e Configurações, camada Supabase real); Planos; Auditoria (candidato existente na fila); Suporte (tabela, kanban, detalhe, com backend Supabase construído agora conforme Decisão 4 da ADR 0034). Para cada action_id prove a régua do MVP: rota normal abre, CRUD persiste no Supabase de produção, RLS nega outro tenant (pgTAP), reload mantém estado. Telas seguem o composto da Fase 0 e a lista de decisões dos goldens (Suporte: tabela e filtros no padrão, card Criar); não crie Table, Toolbar, Pagination ou Header próprios.

Comunicação: escreva somente em docs/reviews/etapa-2-operacao/comunicacao/operacoes.json (revisão 1 na abertura; atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e nos seus commits/handoffs. Repasse TUDO ao coordenador Claude por esse arquivo: avanços, pendências, testes, bloqueios, com action_id e SHA; nada pode se perder. Não edite rastreadores, inventário nem arquivos de outro grupo; só o coordenador escreve em dev. Commits pequenos em português, push da sua branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador.
```

## P4 — estrutura — Claude, Opus

**Resumo:** Instituições, Unidades, Turmas, Atividades, Avaliações e Locais
ponta a ponta com CRUD real e RLS. Primeiro grupo a fechar E2E. Migrations
prontas da fila (save atômico de Turma/Atividade, Locais, catálogo) entram por
ele.

```text
Você é o grupo estrutura da Rodada 3 da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias: rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-estrutura, branch work/etapa2-r03-estrutura, a partir de base.fase0Head em comunicacao/coordenacao.json; antes da base, trabalhe no backend (migrations da fila: save atômico Group/Activity, Locais, bindings) e rebase quando ela sair.

Recorte: famílias institutions, units, groups, activities, assessments, locations (49 ações). Ordem: Instituições (inclusive a confirmação de saída, se a Fase 0 não fechou) → Unidades (leitura de pg_proc em produção autorizada, via coordenador, para confirmar as cinco RPCs) → Turmas → Atividades → Locais → Avaliações. Para cada action_id prove a régua do MVP: rota normal abre sem fixture nem fail-closed, CRUD persiste no Supabase de produção, RLS nega outro tenant em pgTAP, reload mantém estado. Entregue migration + pgTAP + chave de composição por pacote; o coordenador aplica e liga. Telas seguem o composto da Fase 0 e a lista de decisões dos goldens; não crie widgets de diretório próprios.

Comunicação: somente docs/reviews/etapa-2-operacao/comunicacao/estrutura.json (revisão 1 na abertura, atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e seus commits/handoffs de meia página. Nenhuma pendência se perde, nenhum avanço fica sem registro. Só o coordenador escreve em dev e nos rastreadores. Commits pequenos em português, push da branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador.
```

## P5 — acessos-pessoas — Claude, Opus

**Resumo:** Pessoas, Perfis de acesso, Modelos de acesso, Convites, Usuários
internos, Segurança infantil e Arquivos de perfil ponta a ponta, preservando
duplicação e confinamento de Convites já integrados.

```text
Você é o grupo acessos-pessoas da Rodada 3 da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias: rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-acessos-pessoas, branch work/etapa2-r03-acessos-pessoas, a partir de base.fase0Head; antes da base, backend primeiro (contratos de escrita/negação, SQL de Modelos, Safety) e rebase depois.

Recorte: famílias people, access_profiles, access_models, invites, internal_users, child_safety, profile_files (38 ações). Ordem: Pessoas → Convites → Perfis de acesso → Modelos → Usuários internos (o coordenador confirma as RPCs internas em produção) → Segurança infantil → Arquivos de perfil (import/export continuam adiados e honestos). Régua do MVP por action_id: rota normal abre, CRUD persiste em produção, RLS nega outro tenant em pgTAP, reload mantém estado. Migration + pgTAP + chave por pacote; coordenador aplica e liga. Telas seguem o composto da Fase 0 e a lista de decisões dos goldens.

Comunicação: somente comunicacao/acessos-pessoas.json (revisão 1 na abertura; atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e handoffs de meia página. Nenhuma pendência se perde, nenhum avanço fica sem registro. Só o coordenador escreve em dev e nos rastreadores. Commits pequenos em português, push da branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador.
```

## P6 — formularios-cuidado-rotina — Claude, Opus

**Resumo:** Formulários (autoria, respostas, arquivos, XLSX no R2), Perfis de
cuidado, Medicação, Alunos, Assiduidade e Rotina diária ponta a ponta.

```text
Você é o grupo formularios-cuidado-rotina da Rodada 3 da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias: rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase; cloudflare quando tocar o XLSX no R2. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-formularios-cuidado-rotina, branch work/etapa2-r03-formularios-cuidado-rotina, a partir de base.fase0Head; antes da base, backend primeiro (objetos app_private de Rotina e student_tracking sem migration, limites de resposta, care) e rebase depois.

Recorte: famílias forms_authoring, forms_responses, forms_files, health_care, medication, students, attendance, daily_routine (43 ações). Ordem: Perfis de cuidado e Medicação (mais simples) → Alunos → Assiduidade (chave de idempotência no servidor, default D11) → Formulários autoria/respostas → Arquivos e XLSX (forms.responses.export, único export do MVP, R2 privado via gateway) → Rotina (guarda de saída ligada, default D8; Lançamentos com tela mínima, D7; rota Testar como leitura autorizada, default D6). Régua do MVP por action_id. Migration + pgTAP + chave por pacote; coordenador aplica. Telas seguem o composto da Fase 0 e a lista de decisões dos goldens (filtros e tabelas de Formulários no padrão; Criar Perfil de cuidado no padrão de Criar instituição; rodapé mobile).

Comunicação: somente comunicacao/formularios-cuidado-rotina.json (revisão 1 na abertura; atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e handoffs de meia página. Nenhuma pendência se perde, nenhum avanço fica sem registro. Só o coordenador escreve em dev e nos rastreadores. Commits pequenos em português, push da branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador.
```

## P7 — principal-chat-sistema — Claude, Opus

**Resumo:** Coelo Principal (Acontece, Agora, Momentos, Perfil), Chat
administrativo e Principal, Cardápios, Importações (honestas), Catálogo,
páginas de erro, Auth e Shell. Mídia via gateway R2 depois que o coordenador
executar o pacote Cloudflare.

```text
Você é o grupo principal-chat-sistema da Rodada 3 da Etapa 2 do Coelo (Claude, Opus). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R03-prompts.md e R03-plano.md, depois AGENTS.md e as skills obrigatórias: rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui (superfícies do Principal), coelo-knowledge, flutter-dart-code-review, supabase, cloudflare. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-principal-chat-sistema, branch work/etapa2-r03-principal-chat-sistema, a partir de base.fase0Head; antes da base, backend primeiro (catálogo de mídia, RPCs de feed com cursor, Cardápios p_expected_revision) e rebase depois.

Recorte: famílias acontece, agora, momentos, principal_profile, chat, meal_plans, imports, catalog, error_pages, auth, shell (55 ações). Ordem: Auth e Shell (sessão, rotas reais, sem MFA) → Cardápios (p_expected_revision ao apagar imagem; botão arquivar no conceito do modelo de atividade) → Chat administrativo e Principal (regressão de Criar grupo/Fixar/bandeiras se a Fase 0 não fechou; Arquivos escondido em Conversas) → Acontece (cursor do servidor, default D5; mensagens de prévia removidas, default D3; SHELL e MAIS) → Momentos (IMG) → Perfil (referência aprovada com Acompanhar/Seguidores/Seguindo e acompanhamento automático da hierarquia, D1; FOTO; leitura do Sobre, D9) → Agora (R2 master; Stream HOT por até 24 h, D2) → Importações e Catálogo → páginas de erro (409 na família existente, default D10). Mídia real só pelo gateway R2 depois de o coordenador publicar o pacote Cloudflare em coordenacao.json; até lá, contrato e testes. Régua do MVP por action_id. Migration + pgTAP + chave por pacote; coordenador aplica. Principal preserva suas composições aprovadas dentro do Superadmin.

Comunicação: somente comunicacao/principal-chat-sistema.json (revisão 1 na abertura; atualização a cada correção, lote, bloqueio e pelo menos a cada 30 min) e handoffs de meia página. Nenhuma pendência se perde, nenhum avanço fica sem registro. Só o coordenador escreve em dev e nos rastreadores. Commits pequenos em português, push da branch. Não pare de trabalhar de forma alguma até finalizar o recorte ou receber ordem do Owner ou do coordenador.
```
