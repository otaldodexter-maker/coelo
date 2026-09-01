---
source: ".superpowers/sdd/task-1-brief.md"
status: "completed"
generated_at: "2026-09-01"
---

# Task 1 — Shell único do Principal

## Resultado

As rotas de Acontece, Para você, Perfil e publicação de Acontece/Agora/Momentos
agora são `GoRoute`s de nível superior, fora do `ShellRoute` persistente. Seus
builders retornam as páginas do Principal diretamente com `embedded: false`.
As declarações equivalentes que usavam `operationalPage` foram removidas.

O viewer de Momentos permaneceu aninhado; nenhuma rota de Chat do Principal foi
adicionada. `SuperadminShell` não foi alterado.

## Arquivos alterados

- `apps/superadmin/lib/app/router/superadmin_router.dart`
- `apps/superadmin/test/app/router/principal_happens_preview_route_test.dart`
- `apps/superadmin/test/app/router/principal_for_you_preview_route_test.dart`
- `apps/superadmin/test/app/router/principal_profile_preview_route_test.dart`
- `apps/superadmin/test/app/router/principal_moments_publication_route_test.dart`
- `apps/superadmin/test/app/router/principal_now_preview_route_test.dart`

## TDD

### RED

Command (from `apps/superadmin`):

```text
rtk flutter test test/app/router/principal_happens_preview_route_test.dart
```

Observed result: failed as expected. The updated test expected
`PrincipalHappensPreviewPage.embedded` to be `false`, while the old route
supplied `true` (three expected failures: initial Acontece route, responsive
route composition, and Acontece publication route).

### GREEN

Command (from `apps/superadmin`):

```text
rtk flutter test test/app/router/principal_happens_preview_route_test.dart test/app/router/principal_for_you_preview_route_test.dart test/app/router/principal_profile_preview_route_test.dart test/app/router/principal_moments_publication_route_test.dart
```

Result: `00:05 +14: All tests passed!`

Additional affected-route check:

```text
rtk flutter test test/app/router/principal_now_preview_route_test.dart
```

Result: `00:03 +8: All tests passed!`

`rtk git diff --check` also completed without output.

## Self-review

- Route names, paths and callbacks were retained.
- The six moved routes occur only before `ShellRoute`; the Momentos viewer is
  still nested.
- Acontece asserts no persistent shell, Superadmin chat launcher or mobile
  menu, and exactly one `principal-global-messages` launcher.
- Para você and Perfil assert their own Principal header/navigation.
- No `coelo_ui_admin` import was added to the affected Principal features.
- Knowledge-memory search for `Principal shell` returned no durable approved
  knowledge to project: no-op.

## Concern / handoff

A 1440 px route render at 200% text exposes a pre-existing `RenderFlex`
overflow in Acontece’s `_ContextPanel` (`principal_happens_preview_page.dart`),
which becomes visible only after removing the Superadmin shell. The routing
test retains 200% coverage through 1024 px; correcting the 1440 px visual
overflow is intentionally left to the visual task that owns that surface.

## Commit

Pending commit hash.
