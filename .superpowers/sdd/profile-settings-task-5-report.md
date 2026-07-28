---
source: ".superpowers/sdd/profile-settings-task-5-brief.md"
status: "completed-with-external-test-failure"
generated_at: "2026-07-28"
---

# Task 5 — Verificação responsiva e de regressão

## Resultado

Os quatro goldens de Perfil foram atualizados a partir da implementação
aprovada e a matriz golden passou sem atualização posterior. A análise focada e
completa não encontrou issues.

## Goldens e QA visual

- Atualizados: `profile_375_light.png`, `profile_768_light.png`,
  `profile_1024_dark.png` e `profile_1440_dark.png`.
- Inspeção visual manual dos quatro arquivos gerados: 375 px mantém uma coluna
  sem corte aparente; 768 px usa a grade compacta aprovada; 1024 e 1440 px em
  dark preservam sidebar, colunas, cards e rodapé alinhados. Nenhum overflow,
  faixa estrutural cinza ou corte visual foi observado.
- A confirmação sem `--update-goldens` passou os oito casos: Perfil e
  Configurações em 375, 768, 1024 e 1440 px, com mobile light e desktop dark.

## Comandos e saídas

```powershell
# Primeira regressão (antes da atualização dos baselines)
flutter test test/features/account test/features/institutions/presentation/screens/institution_form_page_test.dart test/app/shell/superadmin_shell_test.dart
# 109 testes passaram; quatro falhas de golden de Perfil então desatualizados
# e uma falha externa do teste de Instituições, detalhada em Concerns.

flutter test test/features/account
# All tests passed! (34 testes)

flutter test test/features/account/presentation/screens/account_pages_golden_test.dart --update-goldens
# All tests passed! (8 testes)

flutter test test/features/account/presentation/screens/account_pages_golden_test.dart
# All tests passed! (8 testes)

dart analyze lib/features/account lib/features/institutions/presentation/widgets/institution_form_sections.dart lib/app/widgets test/features/account test/app/widgets
# No issues found!

flutter analyze
# No issues found! (ran in 28.6s)

& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1
# PASS: base de conhecimento válida.

& .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1
# PASS: validação, consulta e cenários da memória Coelo.
```

## Conhecimento Coelo

No-op. A execução somente confirmou o comportamento já aprovado em
`docs/superpowers/specs/2026-07-28-superadmin-profile-settings-refinement-design.md`;
nenhuma fonte canônica ou projeção de conhecimento foi alterada.

## Concerns

- `institution_form_page_test.dart`, caso `location offers CEP lookup and
  representatives use a neutral surface`, continua falhando em
  `test/features/institutions/presentation/screens/institution_form_page_test.dart:812`
  com `Bad state: No element`. A falha ocorre fora dos goldens de Perfil e foi
  preservada, assim como `test/features/account/presentation/screens/failures/`.
- `progress.md` já possuía alteração não relacionada no worktree e não foi
  incluído nesta tarefa.
