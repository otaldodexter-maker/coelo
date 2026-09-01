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

## Follow-up P1 correction

### RED

```text
rtk flutter test test/app/router/principal_happens_preview_route_test.dart test/app/router/principal_profile_preview_route_test.dart
```

Observed result: the Profile dock Home action remained on Perfil because its
callback was absent, and the restored 1440 px / 200% Acontece assertion found
three `_ContextPanel` `RenderFlex` overflows.

### GREEN

```text
rtk flutter test test/app/router/principal_happens_preview_route_test.dart test/app/router/principal_for_you_preview_route_test.dart test/app/router/principal_profile_preview_route_test.dart test/app/router/principal_moments_publication_route_test.dart test/app/router/principal_now_preview_route_test.dart
```

Result: `00:07 +23: All tests passed!`

```text
rtk dart analyze lib/app/router/superadmin_router.dart lib/features/principal_happens/presentation/principal_happens_preview_page.dart test/app/router/principal_happens_preview_route_test.dart test/app/router/principal_profile_preview_route_test.dart
```

Result: `No issues found!`

The Perfil route now connects Home/Acontece, Para você, Publicar no Agora,
Momentos and Agenda. The test exercises each visible action and asserts no
`SnackBar`. `_ContextPanel` now stacks its title and action on narrow layout
constraints, preserving both accessible controls at 1440 px / 200% text.

## Commit

`a6c48751 feat(superadmin): isolate principal preview routes`

`714d9b86 fix(superadmin): complete principal shell isolation`
