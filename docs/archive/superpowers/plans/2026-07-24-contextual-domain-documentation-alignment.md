---
title: "Alinhamento Documental De Pessoas E Acessos Contextuais"
source: "docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md"
status: "approved-for-execution"
generated_at: "2026-07-24"
---

# Contextual Domain Documentation Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alinhar o corpus oficial do Coelo ao desenho aprovado de identidade, familia, profissionais, atividades, chat e assiduidade, sem alterar o Supabase.

**Architecture:** Registrar primeiro as decisoes normativas em ADR e spec de produto. Propagar depois os conceitos para arquitetura, mapa de dominios, modelo de dados, seguranca e PRDs, preservando a prioridade documental e marcando claramente o que ja existe e o que ainda depende de migration.

**Tech Stack:** Markdown com frontmatter; Git; `rg`; `git diff --check`.

## Global Constraints

- Nao executar DDL, migrations, RPCs ou qualquer mutacao no Supabase.
- Preservar integralmente alteracoes nao relacionadas no workspace.
- Pessoa e global; papel, experiencia, escopo e permissao sao contextuais.
- Instituicao e sempre proprietaria dos dados e das atividades.
- Unidade nunca recebe acesso automatico a unidade irma.
- Crianca nao possui login no MVP, mas o modelo fica preparado para perfil futuro.
- Documentos derivados devem manter frontmatter com fonte, status e data.
- Divergencias nao resolvidas permanecem em `docs/open-questions.md`.

---

### Task 1: Registrar Decisao Normativa E Spec De Dominio

**Files:**
- Create: `decisions/0015-contextual-people-authorizations-attendance.md`
- Create: `specs/015-contextual-people-access-attendance.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md`
- Produces: decisao normativa e requisitos funcionais usados pelos documentos derivados.

- [ ] **Step 1: Criar a ADR normativa**

Registrar:

- identidade global e experiencias familiar/profissional separadas;
- escopos automaticos ou selecionados;
- papeis aditivos com deny individual prevalecendo;
- responsaveis convidados somente por instituicao/unidade;
- pessoas autorizadas sem login;
- transferencia entre unidades com aceite;
- atividades locais promoviveis sem duplicacao;
- chat hierarquico com autoria pessoal;
- avisos de presenca separados do registro oficial.

- [ ] **Step 2: Criar a spec funcional**

Incluir objetivo, escopo, fora de escopo, superficies, entidades, regras de
tenant, estados de UX, eventos, criterios de aceite, testes exigidos, riscos e
decisoes adiadas.

- [ ] **Step 3: Verificar estrutura**

Run:

```powershell
rg -n "^#|^##|status:|generated_at:" decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md
git diff --check -- decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md
```

Expected: frontmatter completo, secoes obrigatorias presentes e nenhum erro de whitespace.

### Task 2: Atualizar Arquitetura E Mapa De Dominios

**Files:**
- Modify: `docs/architecture/macro-architecture.md`
- Modify: `docs/architecture/domain-map.md`
- Modify: `docs/architecture/activity-domain-addendum.md`

**Interfaces:**
- Consumes: ADR 0015 e spec 015.
- Produces: fronteiras e dependencias oficiais para Identity, Tenancy, Family, Authorization, Activities, Chat e Attendance.

- [ ] **Step 1: Atualizar a arquitetura macro**

Adicionar um addendum que declare:

- `people` como raiz global;
- experiencias como projecoes de vinculos, nao novas identidades;
- hierarquia de escopo;
- autorizacao por capacidade e contexto;
- Attendance como dominio proprio;
- Chat como consumidor de contexto, sem ser fonte de presenca;
- notificacoes e auditoria como consumidores transversais.

- [ ] **Step 2: Atualizar o mapa de dominios**

Registrar responsabilidades e dependencias:

```text
Identity -> Tenancy -> Family/Professional Authorization
Tenancy + Authorization -> Activities
Family/Professional Authorization + Activities -> Chat/Attendance/Agenda/Routine/Media
Todos os comandos sensiveis -> Audit
Eventos operacionais -> Notifications/Analytics
```

Separar `Authorized Contacts` de `Guardian Access` e registrar `Attendance`
como dominio independente.

- [ ] **Step 3: Atualizar o addendum de atividades**

Adicionar:

- origem, disponibilidade e politica institucional;
- promocao de atividade local sem duplicacao;
- participacao de toda a turma ou criancas selecionadas;
- configuracao de capacidades obrigatoria/default/proibida;
- dependencia futura de Attendance, Chat, Routine, Agenda e Media.

- [ ] **Step 4: Verificar terminologia**

Run:

```powershell
rg -n "Attendance|Assiduidade|pessoa global|atividade fixa|promov" docs/architecture
git diff --check -- docs/architecture/macro-architecture.md docs/architecture/domain-map.md docs/architecture/activity-domain-addendum.md
```

Expected: dominios novos localizaveis e nenhum conflito de whitespace.

### Task 3: Atualizar Modelo De Dados E Seguranca

**Files:**
- Modify: `docs/data/data-model.md`
- Modify: `docs/security/auth-multitenant-permissions.md`
- Modify: `specs/011-superadmin-database-rls.md`
- Modify: `specs/014-atividade-contextual.md`

**Interfaces:**
- Consumes: arquitetura atualizada.
- Produces: modelo conceitual e regras de autorizacao para o futuro plano de migrations.

- [ ] **Step 1: Atualizar o modelo de dados**

Adicionar entidades conceituais para:

- catalogo de relacoes;
- capacidades familiares por crianca e escopo;
- pessoas e tipos de autorizacao operacional;
- transferencias entre unidades;
- atribuicoes profissionais por crianca;
- participacao infantil em atividades;
- governanca/promocao de atividades;
- equipes de atendimento;
- sessoes e registros de presenca;
- avisos, justificativas, motivos e revisoes;
- snapshots contextuais de chat.

Marcar explicitamente que os nomes fisicos finais dependem do plano tecnico.

- [ ] **Step 2: Atualizar Auth e permissoes**

Formalizar:

- experiencia familiar/profissional separada;
- convite institucional versus convite de unidade;
- matriz familiar default `Sim`, editavel;
- escopos automaticos e selecionados;
- soma de allows e precedencia de deny individual;
- revogacao imediata;
- RLS por tenant, unidade, grupo, atividade e crianca.

- [ ] **Step 3: Alinhar specs 011 e 014**

Na spec 011, registrar lacunas entre schema atual e modelo aprovado sem
declarar migration implementada. Na spec 014, adicionar promocao, politicas e
participacao infantil.

- [ ] **Step 4: Verificar cobertura**

Run:

```powershell
rg -n "authorized|autorizad|transfer|attendance|assiduidade|activity_child|participa" docs/data/data-model.md docs/security/auth-multitenant-permissions.md specs/011-superadmin-database-rls.md specs/014-atividade-contextual.md
git diff --check -- docs/data/data-model.md docs/security/auth-multitenant-permissions.md specs/011-superadmin-database-rls.md specs/014-atividade-contextual.md
```

Expected: todas as lacunas aparecem como futuras e nenhuma e descrita como ja aplicada.66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666

### Task 4: Atualizar PRDs De Produto

**Files:**
- Modify: `docs/product/prd-master.md`
- Modify: `docs/product/prd-admin.md`
- Modify: `docs/product/prd-app.md`
- Modify: `docs/product/prd-superadmin.md`

**Interfaces:**
- Consumes: ADR, spec, arquitetura e modelo de dados.
- Produces: rotinas oficiais por superficie.

- [ ] **Step 1: Atualizar PRD Master**

Adicionar resumo transversal de experiencias, autorizacoes operacionais,
atividades promoviveis, chat hierarquico e assiduidade.

- [ ] **Step 2: Atualizar PRD Admin**

Adicionar rotinas de:

- convite e permissao familiar;
- pessoas autorizadas;
- transferencia;
- escopos profissionais;
- governanca e promocao de atividade;
- configuracao de equipe de atendimento;
- gestao de presenca e dashboards.

- [ ] **Step 3: Atualizar PRD App**

Adicionar:

- experiencias separadas;
- avisos familiares de presenca;
- central de pendencias e lembretes;
- cards de presenca no chat;
- visibilidade de pessoas autorizadas somente com capacidade;
- chat por instituicao, unidade, grupo e atividade.

- [ ] **Step 4: Atualizar PRD Superadmin**

Registrar que o Superadmin inspeciona e audita catalogos/estruturas, mas nao
substitui a governanca operacional da instituicao.

- [ ] **Step 5: Verificar superficies**

Run:

```powershell
rg -n "Assiduidade|pessoas autorizadas|experiencia profissional|atividade fixa|transferencia" docs/product
git diff --check -- docs/product/prd-master.md docs/product/prd-admin.md docs/product/prd-app.md docs/product/prd-superadmin.md
```

Expected: cada superficie declara apenas as rotinas que lhe pertencem.

### Task 5: Atualizar Perguntas Abertas E Validar O Corpus

**Files:**
- Modify: `docs/open-questions.md`

**Interfaces:**
- Consumes: todos os documentos atualizados.
- Produces: lista honesta de decisoes adiadas e manifest de lacunas para o plano Supabase.

- [ ] **Step 1: Corrigir OQ-019**

Remover a afirmacao desatualizada de que tabelas familiares nao existem.
Registrar que a fundacao estrutural existe, mas RLS operacional, matriz de
capacidades e fluxos server-side permanecem pendentes.

- [ ] **Step 2: Registrar decisoes adiadas**

Manter abertas:

- modelo comercial de quantidade de responsaveis;
- retencao juridica de chat e dados infantis;
- experiencia infantil futura;
- nomes fisicos finais das novas estruturas;
- catalogos iniciais e politica de documentos de justificativa.

- [ ] **Step 3: Executar verificacao cruzada**

Run:

```powershell
rg -n -i "TODO|TBD|\\?\\?\\?|a definir" decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/architecture docs/data/data-model.md docs/security/auth-multitenant-permissions.md docs/product/prd-master.md docs/product/prd-admin.md docs/product/prd-app.md docs/product/prd-superadmin.md docs/open-questions.md
git diff --check
git diff --name-only
```

Expected: nenhuma nova marca provisoria fora das decisoes explicitamente
adiadas; somente arquivos documentais do escopo aparecem no diff planejado.

- [ ] **Step 4: Criar commit documental isolado**

```powershell
git add -- decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/architecture/macro-architecture.md docs/architecture/domain-map.md docs/architecture/activity-domain-addendum.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md specs/011-superadmin-database-rls.md specs/014-atividade-contextual.md docs/product/prd-master.md docs/product/prd-admin.md docs/product/prd-app.md docs/product/prd-superadmin.md docs/open-questions.md
git diff --cached --name-only
git diff --cached --check
git commit -m "docs: align contextual people and attendance domains"
```

Expected: commit contem somente os 14 documentos listados.
