---
title: "Coelo Tutor Implementation Plan"
source: "docs/superpowers/specs/2026-07-14-coelo-tutor-design.md"
status: "implementation-plan"
generated_at: "2026-07-14"
updated_at: "2026-07-14"
---

# Coelo Tutor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Disponibilizar `$coelo-tutor` como tutor persistente para uma pessoa iniciante absoluta, usando o codigo real do Coelo e lembrando onde o estudo parou e por que o proximo passo foi escolhido.

**Architecture:** Uma skill local define os gatilhos e o contrato pedagogico. Dois documentos versionados separam o curriculo estavel da memoria viva de progresso; o tutor le ambos antes da aula e atualiza somente a memoria ao encerrar uma interacao de estudo.

**Tech Stack:** Codex skills (`SKILL.md` e `agents/openai.yaml`), Markdown com frontmatter, Python de validacao fornecido pelo `skill-creator`, Git.

## Global Constraints

- Tratar a pessoa como iniciante absoluta e nao presumir vocabulario tecnico.
- Usar `apps/superadmin` como fonte inicial de exemplos reais.
- Explicar o que, por que, onde e como cada conceito se conecta.
- Separar conceitos apresentados de conceitos demonstrados como compreendidos.
- Registrar o proximo passo e sua justificativa.
- Nao alterar codigo nem sistemas externos durante uma aula sem pedido explicito.
- Nunca tratar guard Flutter como autorizacao real nem colocar `service_role` no cliente.
- Preservar todas as mudancas preexistentes do Superadmin.

---

### Task 1: Testar o comportamento sem a skill

**Files:**
- Inspect: `apps/superadmin/lib/main.dart`
- Inspect: `apps/superadmin/lib/README.md`
- Inspect: `apps/superadmin/lib/features/README.md`

**Interfaces:**
- Consumes: pedido natural de uma pessoa iniciante por uma aula do Coelo.
- Produces: lista de falhas observadas que a skill deve corrigir.

- [ ] **Step 1: Executar um cenario sem a skill**

Enviar a um agente sem o conteudo futuro da skill:

```text
Sou 100% iniciante. Dê minha aula de hoje usando apps/superadmin/lib/main.dart e continue de onde paramos. Ao final, registre o que compreendi e diga por que o próximo tema é o certo.
```

- [ ] **Step 2: Confirmar a falha esperada**

Esperar pelo menos uma destas lacunas: inventar memoria anterior, nao distinguir apresentado de compreendido, presumir termos, nao justificar o proximo passo ou nao indicar um registro persistente.

- [ ] **Step 3: Registrar os requisitos revelados**

Usar as lacunas observadas como requisitos diretos do contrato em `SKILL.md`, sem criar arquivo auxiliar de teste.

### Task 2: Criar a skill local

**Files:**
- Create: `.codex/skills/coelo-tutor/SKILL.md`
- Create: `.codex/skills/coelo-tutor/agents/openai.yaml`

**Interfaces:**
- Consumes: `docs/learning/curriculum.md`, `docs/learning/progress.md`, pedido da pessoa e arquivos atuais do Coelo.
- Produces: respostas nos modos `aula`, `explique`, `revise mudanças`, `exercício`, `quiz` e `progresso`.

- [ ] **Step 1: Inicializar a estrutura oficial**

Executar:

```powershell
& 'C:\Users\adrie\AppData\Local\Programs\Python\Python312\python.exe' C:\Users\adrie\.codex\skills\.system\skill-creator\scripts\init_skill.py coelo-tutor --path C:\Users\adrie\Documents\Coelo\.codex\skills --interface 'display_name=Tutor Coelo' --interface 'short_description=Aprenda o Coelo do zero, passo a passo' --interface 'default_prompt=Use $coelo-tutor para continuar minha aula do ponto em que paramos.'
```

Esperado: pasta `coelo-tutor` criada com `SKILL.md` e `agents/openai.yaml`.

- [ ] **Step 2: Escrever o contrato pedagogico minimo**

O `SKILL.md` deve conter, nesta ordem: principio central, leitura obrigatoria, selecao do modo, contrato da aula, contrato da memoria, linguagem para iniciante, uso do codigo real, seguranca, referencia rapida e erros comuns.

- [ ] **Step 3: Verificar metadados**

Confirmar que `agents/openai.yaml` usa `Tutor Coelo`, descricao entre 25 e 64 caracteres e `default_prompt` contendo `$coelo-tutor`.

### Task 3: Criar curriculo e memoria inicial

**Files:**
- Create: `docs/learning/curriculum.md`
- Create: `docs/learning/progress.md`

**Interfaces:**
- Consumes: arquitetura documentada do Coelo e nivel `iniciante absoluto`.
- Produces: fase atual, assuntos dependentes, evidencias de compreensao e proximo passo justificado.

- [ ] **Step 1: Criar o curriculo**

Escrever oito fases: mapa do projeto; Dart; Flutter; estrutura do Superadmin; interface e comportamento; dados e backend; SQL/PostgreSQL; Supabase no Coelo. Para cada fase, registrar objetivo, assuntos, evidencia de conclusao e motivo da posicao na trilha.

- [ ] **Step 2: Criar o progresso inicial**

Inicializar `fase atual` como `1 — Mapa do projeto`, `assunto atual` como `Como o Superadmin começa: lib e main.dart`, conceitos compreendidos como `nenhum ainda`, e proximo passo com justificativa baseada em pre-requisito.

- [ ] **Step 3: Validar o frontmatter**

Confirmar em ambos os documentos as chaves `source`, `status`, `generated_at` e `updated_at`, todas com valores definidos.

### Task 4: Validar e testar a skill

**Files:**
- Test: `.codex/skills/coelo-tutor/SKILL.md`
- Test: `.codex/skills/coelo-tutor/agents/openai.yaml`
- Test: `docs/learning/curriculum.md`
- Test: `docs/learning/progress.md`

**Interfaces:**
- Consumes: arquivos produzidos nas Tasks 2 e 3.
- Produces: evidencia de validacao estrutural e comportamental.

- [ ] **Step 1: Executar o validador oficial**

Executar:

```powershell
& 'C:\Users\adrie\AppData\Local\Programs\Python\Python312\python.exe' C:\Users\adrie\.codex\skills\.system\skill-creator\scripts\quick_validate.py C:\Users\adrie\Documents\Coelo\.codex\skills\coelo-tutor
```

Esperado: `Skill is valid!` e codigo de saida `0`.

- [ ] **Step 2: Testar tres modos com a skill**

Executar cenarios independentes para `$coelo-tutor aula`, `$coelo-tutor explique main.dart` e `$coelo-tutor progresso`. Confirmar leitura da memoria, nivel iniciante, uso do codigo real e justificativa do proximo passo.

- [ ] **Step 3: Verificar isolamento das mudancas**

Executar:

```powershell
git status --short
git diff -- .codex/skills/coelo-tutor docs/learning docs/superpowers/plans/2026-07-14-coelo-tutor.md
```

Esperado: somente os novos arquivos do tutor e este plano no diff da entrega; mudancas preexistentes do Superadmin permanecem intactas.

- [ ] **Step 4: Commit da entrega**

Executar:

```powershell
git add .codex/skills/coelo-tutor docs/learning docs/superpowers/plans/2026-07-14-coelo-tutor.md
git commit -m "feat: add persistent Coelo tutor"
```
