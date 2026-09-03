# Etapa 2 E2E Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Concluir e consolidar a Etapa 2 por cinco verticais E2E paralelas, com uma plataforma compartilhada de mídia de produção e sem sobreposição de ownership.

**Architecture:** Um Coordenador é o único integrador da branch principal, dos rastreadores e dos recursos remotos compartilhados. Cinco worktrees entregam verticais independentes; Superadmin é o único app alterado, enquanto `coelo_domain`, `coelo_api`, Supabase e Cloudflare preservam contratos reutilizáveis por Admin e Principal.

**Tech Stack:** Flutter/Dart, packages do monorepo Coelo, Supabase/Postgres/Auth/RLS/Edge Functions, Cloudflare Workers/R2/Stream, RTK e Git worktrees.

## Global Constraints

- Todo remoto Coelo é produção; testar localmente e aplicar somente pacotes nominais, forward-only, revisados e serializados.
- Nunca usar nem pedir no chat o token Cloudflare exposto; uma nova credencial least-privilege deve ser provisionada diretamente no secret store e bloqueia apenas o primeiro gate remoto que realmente depende dela.
- Separar credenciais por função: bootstrap/admin R2 apenas para bucket, runtime R2 limitado a objetos/buckets, Stream Edit para HOT e Workers deploy para o Worker nominal; não usar token amplo único nem bootstrap no runtime.
- Implementar somente `apps/superadmin` e packages/backends usados por ele nesta Etapa 2.
- Não criar bucket, path, gateway ou catálogo por app.
- Usar `coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`, todos privados.
- Há relatos conflitantes sobre os três buckets: E2E 3 confirma conta/estado read-only, cria somente os ausentes no pacote autorizado ou configura os existentes; nunca recria, renomeia, esvazia ou exclui.
- O Coordenador mantém um ledger de leases remotos. Cada pacote nomeia exatamente um executor, recursos e janela; sem lease, toda frente é read-only. O executor encerra o lease com evidência antes da próxima mutação.
- Não criar raízes globais `v1`/`v2`; histórico de ativos vive no Postgres.
- Cache de mídia privada no cliente é temporário e escopado por sessão/realm; logout, revogação e troca de contexto sensível invalidam tickets e purgam o cache.
- Workers não editam os três rastreadores; somente o Coordenador consolida pendências por tela/subtela/action_id.
- Cada mudança usa TDD, commit atômico, revisão independente, secret scan e worktree limpa no handoff.

---

### Task 1: Congelar baseline e ownership

**Files:**
- Read: `AGENTS.md`
- Read: `docs/reviews/coelo-flutter-pendencias.md`
- Read: `docs/reviews/coelo-supabase-pendencias.md`
- Read: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- Read: `docs/reviews/evidence/etapa-2/coordenador/prompts-etapa-2-e2e.md`
- Modify: somente os três rastreadores pelo Coordenador

**Interfaces:**
- Consumes: Git HEAD, branches, worktrees, commits e `action_id` vivos.
- Produces: mapa exclusivo de ownership e ordem serial de migrations/deploys.

- [ ] **Step 1: Capturar estado Git compacto**

Run: `rtk git status --short && rtk git worktree list && rtk git log -10 --oneline`

Expected: base SHA, sujeira e worktrees conhecidas sem alterar arquivos.

- [ ] **Step 2: Reconciliar os cinco owners**

Registrar E2E 1 Identidade/Acessos; E2E 2 Estruturas/Pessoas/Locais; E2E 3 Comunicação/Mídia/Coelo Principal; E2E 4 Formulários/Respostas/Cuidado; E2E 5 Agenda/Eventos/Operações.

- [ ] **Step 3: Remover sobreposições conhecidas**

Fixar erros Auth em E2E 1, páginas globais de erro em E2E 5, `groups.location` em E2E 2 e `activities.location`/`agenda.location`/`locations.schedule` em E2E 5.

- [ ] **Step 4: Publicar denominadores iniciais**

Contar action_ids únicos e registrar separadamente Front-end, Back-end e E2E, sem promover evidência antiga.

- [ ] **Step 5: Abrir o ledger de leases remotos**

Para cada pacote de produção, registrar executor único, recursos, janela, plano forward-only e critério de encerramento; nenhuma frente escreve remotamente sem esse registro.

### Task 2: Despachar as cinco worktrees

**Files:**
- Read: `docs/reviews/evidence/etapa-2/coordenador/prompts-etapa-2-e2e.md`

**Interfaces:**
- Consumes: ownership da Task 1.
- Produces: cinco branches/worktrees com bases SHA registradas.

- [ ] **Step 1: Criar ou validar uma worktree exclusiva por frente**

Usar branches `codex/e2e-identidade-acessos`, `codex/e2e-estruturas-pessoas-locais`, `codex/e2e-comunicacao-midia-principal`, `codex/e2e-formularios-cuidado` e `codex/e2e-agenda-operacoes`.

- [ ] **Step 2: Enviar o prompt correspondente sem resumi-lo**

Cada tarefa recebe o bloco integral, preservando skills, produção, reporting e encerramento.

- [ ] **Step 3: Confirmar handoff periódico**

Cada frente reporta a cada 60 minutos e após commit, regressão, bloqueio ou mudança de ETA.

### Task 3: Integrar fundações compartilhadas

**Files:**
- Modify: `packages/coelo_domain/**` somente quando o crosswalk comprovar ausência de tipo reutilizável
- Modify: `packages/coelo_api/**` para o contrato compartilhado do gateway
- Modify: `packages/coelo_database/**` em migrations novas forward-only
- Modify: configuração Cloudflare versionada sem segredos
- Test: testes Dart, SQL/pgTAP e Worker correspondentes

**Interfaces:**
- Consumes: handoffs E2E 1, E2E 2 e E2E 3.
- Produces: identidade/autorização, catálogo de entidades, Media Gateway e contratos consumíveis pelas verticais.

- [ ] **Step 1: Executar crosswalk de tabelas de mídia existentes**

Comparar `media_assets`, `now_media_assets`, `moments_media_assets`, `circular_media_assets`, `form_assets`, `meal_plan_image_assets` e Chat antes de propor tabela nova.

- [ ] **Step 2: Revisar REDs locais de Auth, RLS e mídia**

Exigir negativas de tenant A/B, revogado, ID adulterado, MIME falso, excesso de bytes/pixels e ticket expirado.

- [ ] **Step 3: Integrar commits por dependência**

Ordem: Identidade/Acessos → Estruturas/Pessoas/Locais → Media Gateway/R2/Stream.

- [ ] **Step 4: Aplicar pacote remoto de produção serializado**

Executar somente após replay local, revisão, secret scan, plano de recuperação e nova credencial Cloudflare quando necessária.

### Task 4: Integrar verticais consumidoras

**Files:**
- Modify: `apps/superadmin/**`
- Modify: packages/backends compartilhados já aprovados na Task 3
- Test: testes focados Flutter, SQL, Edge/Worker e E2E

**Interfaces:**
- Consumes: fundações integradas da Task 3.
- Produces: ações E2E de Comunicação, Formulários/Cuidado e Agenda/Operações.

- [ ] **Step 1: Integrar E2E 3 e provar mídia compartilhada**

Provar avatar/capa aplicável, Acontece, Agora, Momentos, Chat e anexos sem path por app, incluindo hook de invalidação de tickets/cache privado conectado pela E2E 1 em logout, revogação e troca de contexto sensível.

- [ ] **Step 2: Integrar E2E 4**

Provar imagens de respostas e XLSX do formulário em `coelo-transient-prod`, sem CSV/ZIP/PDF ou exportação individual.

- [ ] **Step 3: Integrar E2E 5**

Provar eventos/galerias e mídia operacional aplicável, consumindo o mesmo gateway.

- [ ] **Step 4: Reexecutar negativos após cada merge**

Nenhuma vertical avança se regressar Auth, RLS, tenant, revogação, cleanup ou segredo.

### Task 5: Fechar rastreadores, regressão e Git

**Files:**
- Modify: `docs/reviews/coelo-flutter-pendencias.md`
- Modify: `docs/reviews/coelo-supabase-pendencias.md`
- Modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- Modify: fontes canônicas e `docs/knowledge/**` quando houver mudança durável

**Interfaces:**
- Consumes: todos os commits e resultados de testes.
- Produces: Etapa 2 auditável, percentual real, pendências restantes e árvore Git limpa.

- [ ] **Step 1: Rodar gates finais**

Executar replay/pgTAP/RLS/Advisors, testes Worker/R2/Stream, analyzer/testes Flutter, validação visual, knowledge gate, secret scan e E2E.

- [ ] **Step 2: Atualizar estados por action_id**

Promover somente ações com evidência compatível; registrar primeiro gate aberto e ETA nas restantes.

- [ ] **Step 3: Recalcular percentuais**

Publicar Front-end `verified`, Back-end `done` e integração `verified-e2e`, geral e Etapa 2, com numerador/denominador.

- [ ] **Step 4: Limpar worktrees com prova**

Remover cada worktree somente após commit integrado, ancestralidade confirmada e ausência de arquivo não rastreado.

- [ ] **Step 5: Criar commit final de coordenação**

Run: `rtk git status --short && rtk git diff --check`

Expected: nenhum resíduo e nenhum erro de whitespace antes do commit final.
