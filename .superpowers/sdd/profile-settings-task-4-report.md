---
source: ".superpowers/sdd/profile-settings-task-4-brief.md"
status: "completed"
generated_at: "2026-07-28"
---

# Task 4 — diálogo de senha e Configurações

## RED

- Os testes novos falharam antes da mudança de produção: faltavam as chaves
  `account-password-close` e `settings-reduce-motion-row`.
- O comando direcionado retornou falha esperada pela ausência desses contratos.

## GREEN

- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics test test/features/account/presentation/screens/profile_page_test.dart test/features/account/presentation/screens/settings_page_test.dart`
  retornou `All tests passed!` (9 testes).
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics analyze`
  retornou `No issues found!`.
- `Test-CoeloKnowledge.ps1` e seus testes retornaram `PASS`.

## Alterações e revisão

- O diálogo agora expõe fechamento vermelho canônico de 48 px, com tooltip e
  semântica nativa, e ações Cancelar/Alterar senha em `Expanded` 50/50,
  separadas por `CoeloSpacing.space3`.
- A linha Reduzir animações permanece em `Material` transparente e o tile
  mantém hover e overlay transparentes.
- A revisão do diff e `git diff --check` não encontraram problemas. Goldens e
  `failures/` não foram alterados (reservados para a Task 5).

## Memória Coelo

No-op: a spec aprovada e a projeção `superadmin-profile-settings` já registram
este comportamento durável; não houve nova regra de produto a capturar.

## Arquivos

- `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart`
- `apps/superadmin/lib/features/account/presentation/screens/settings_page.dart`
- `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`
- `apps/superadmin/test/features/account/presentation/screens/settings_page_test.dart`

## Commit e concerns

- Código: `b863593 fix(superadmin): refine password dialog and settings row`.
- Sem concerns funcionais. O Flutter informou 11 dependências com versões mais
  novas fora das restrições; isso não afetou testes nem análise.
