---
source: ".superpowers/sdd/task-3-brief.md; docs/superpowers/plans/2026-09-01-principal-ui-ux-closure.md"
status: completed
generated_at: 2026-09-01
---

# Task 3 — Circulares em Coelo (Principal)

## Recorte

Movidos somente os nós existentes `circulars` e `circular-create` de
Comunicação para o fim de Coelo (Principal). Chat, Notices, Invites, shell,
cabeçalho, backend, `apps/admin`, `apps/site` e `apps/principal` não foram
alterados. `393fc7ff` não foi integrado nem copiado.

## RED

Antes dos handoffs, o teste de navegação passou a exigir:

- `coeloNavigationAncestors('circulars') == {'principal'}`;
- `coeloNavigationAncestors('circular-create') == {'principal', 'circulars'}`;
- `communication` sem `circulars` entre suas ancestrais.

`rtk flutter test test/app/navigation/superadmin_navigation_test.dart` falhou
como esperado: `circulars` ainda tinha a ancestral `communication` e não
continha `principal`.

## GREEN

- Handoff visual preservado: `f6d44af9` → `ebc0ac29`
  (`docs: preserve communication visual references`).
- Ações canônicas de arquivo integradas: `d22a9b3d` → `cb6763ed`
  (`feat(circulars): expose canonical file actions`).
- A hierarquia agora preserva IDs, ícones, rotas e capabilities e produz
  `principal > circulars > circular-create`.

Verificações executadas em `apps/superadmin`:

```powershell
rtk flutter test test/app/navigation/superadmin_navigation_test.dart test/features/circulars/presentation/circular_directory_page_test.dart
rtk dart analyze lib/app/navigation/superadmin_navigation.dart test/app/navigation/superadmin_navigation_test.dart lib/features/circulars/presentation/circular_directory_page.dart test/features/circulars/presentation/circular_directory_page_test.dart
rtk git diff --check
```

Resultados: 21 testes focais aprovados; analyzer sem issues; diff sem
whitespace inválido.

## Commit da hierarquia

O commit exclusivo `feat(principal): move circular navigation` contém somente
`apps/superadmin/lib/app/navigation/superadmin_navigation.dart`,
`apps/superadmin/test/app/navigation/superadmin_navigation_test.dart` e este
relatório.

## Riscos e limites

- A mudança é somente de navegação e UI local; não promove backend, autorização
  remota, RLS, persistência ou E2E.
- Importar/exportar do handoff usam callbacks existentes ou feedback explícito
  de indisponibilidade; nenhum fluxo remoto foi inventado.
- O conjunto de referências visuais foi preservado, mas não altera as telas WIP
  de composer ou detalhe da Comunicação.
