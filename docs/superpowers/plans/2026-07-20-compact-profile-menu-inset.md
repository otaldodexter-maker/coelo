---
title: "Compact Profile Menu Safe Inset Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-compact-profile-menu-inset-design.md"
status: "completed"
generated_at: "2026-07-20"
---

# Compact Profile Menu Safe Inset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar respiro direito ao menu de perfil compacto sem alterar sua apresentação desktop.

**Architecture:** Ajustar somente a geometria do `MenuAnchor` em `_ProfileSummary`, condicionada por `compact`, e cobrir o comportamento com teste de widget em mobile e tablet.

**Tech Stack:** Dart, Flutter Material 3 e Flutter Test.

## Global Constraints

- Margem direita mínima compacta: `CoeloSpacing.space4`.
- Desktop não compacto não muda.
- Conteúdo, estilos, hover e ações não mudam.
- Nenhuma nova dependência, cor ou abstração.

---

### Task 1: Geometria compacta do menu de perfil

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `_ProfileSummary.compact`, `MenuAnchor.alignmentOffset` e `CoeloSpacing`.
- Produces: menu compacto com painel afastado da borda direita.

- [ ] **Step 1: Escrever teste RED em 375 e 768 px**

Abrir `superadmin-profile-menu`, medir a ação direita do painel e exigir espaço suficiente para `CoeloSpacing.space4` mais o padding interno do menu.

- [ ] **Step 2: Executar teste focado e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: falha porque o menu atual usa o limite padrão da viewport.

- [ ] **Step 3: Aplicar deslocamento compacto mínimo**

Definir o deslocamento horizontal compacto no `MenuAnchor`, preservando o deslocamento zero no desktop e `CoeloSpacing.space2` no eixo vertical.

- [ ] **Step 4: Executar teste focado e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes do shell passam.

- [ ] **Step 5: Validar e commit**

Executar `flutter analyze`, `flutter test` e `flutter build web --dart-define=COELO_DEV_MFA=true`; atualizar o preview, confirmar HTTP 200 e criar commit isolado.

## Resultado da execução

- Implementação concluída em 2026-07-20 com ciclo RED/GREEN em 375 e 768 px.
- `flutter analyze`: sem problemas.
- `flutter test`: 146 testes aprovados.
- `flutter build web --dart-define=COELO_DEV_MFA=true`: concluído.
