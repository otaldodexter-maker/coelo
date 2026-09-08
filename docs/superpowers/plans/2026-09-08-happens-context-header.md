---
title: "Acontece — execução do header de contexto"
source: "2026-09-08-happens-context-header-design.md; aprovação nominal do Coordenador"
status: "implemented-local; visual handoff required; not E2E"
generated_at: "2026-09-08"
---

# Acontece Context Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans inline;
> writer único nesta worktree e revisão independente read-only existente.

**Goal:** Medir título/ação reais para decidir linha ou empilhamento.

**Architecture:** Trocar apenas o header privado de ContextPanel por OverflowBar.
Não extrair widget público nem alterar o layout dos painéis fora do header.

**Tech Stack:** Flutter, Nunito Sans, flutter_test.

## Global Constraints

- Somente Superadmin; preservar textos, callbacks, tokens e touch targets.
- Sem alteração de PublishNowCard, Perfil, backend ou baseline PNG.
- Larguras 375/768/1024/1440, temas claro/escuro e texto 100%/200%.

### Task 1: Header por espaço real

**Files:**
- Modify: `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart`, `_ContextPanel.build`.
- Create: `apps/superadmin/test/features/principal_happens/presentation/principal_happens_context_header_test.dart`.

**Interfaces:** Consome title/action/onAction/children existentes; não cria API.

- [x] Escrever teste com fonte Nunito real, MaterialApp/CoeloTheme e demo.
  Em desktop, comparar os retângulos do título Aniversariantes e seu TextButton;
  escala 1 deve compartilhar centro vertical e escala 2 deve empilhar.
  Em compacto, a coluna permanece ausente. Executar ação Ver agenda e provar
  callback. Em todas as 16 combinações, `tester.takeException()` é null.

```dart
expect(tester.getCenter(title).dy, closeTo(tester.getCenter(action).dy, 1));
expect(tester.getRect(action).top, greaterThanOrEqualTo(tester.getRect(title).bottom));
```

- [x] Executar `flutter test --no-pub test/features/principal_happens/presentation/principal_happens_context_header_test.dart`; registrar RED da linha compacta.
- [x] Remover LayoutBuilder/threshold e usar os mesmos titleText/actionButton:

```dart
OverflowBar(
  alignment: MainAxisAlignment.spaceBetween,
  overflowAlignment: OverflowBarAlignment.start,
  children: [titleText, actionButton],
)
```

- [x] Executar teste focal e regressão inteira de principal_happens sem goldens;
  analyzer dos dois arquivos, format e diff check.
- [x] Executar goldens existentes sem update para comparação; inspecionar imagens
  master/test desktop e texto200%, preservar divergências prévias documentadas.
- [ ] Solicitar revisão read-only, registrar evidência local e commit atômico;
  handoff ao Coordenador antes de qualquer proposta de promoção de PNG.

## Autorrevisão

Contrato único sem alteração de produto. Matriz cobre constraints, escala e
ação; fonte real evita inferência de largura baseada em Ahem. Sem passos remotos.
