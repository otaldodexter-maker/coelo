---
fonte: execução Flutter G1 sob posse nominal
status: verificado
data: 2026-09-12
rodada: E2-R08-20260912
---

# Transcript de PNGs A

Execução final, sem atualização, sob `--concurrency=1`:

```text
flutter test test/features/activities/presentation/activity_golden_test.dart test/app/router/structure_detail_golden_test.dart test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart --concurrency=1
00:22 +20: All tests passed!
```

Regravações anteriores no mesmo slot: Atividades 9/9, detalhes 4/4 e Instituições 7/7, todas com `--update-goldens` e PASS. A comparação anterior falhou apenas nos 45 nomes A autorizados. `git diff --name-only 581b27f95 41d3c518a` nos três diretórios aprovados devolveu 45 arquivos: 31 Atividades, 12 detalhes Unidade/Turma e 2 paginações de Instituições. Não há A+/R nem frame G3.

O hash antes/depois auditável é o diff bruto do commit de conteúdo `41d3c518a` contra `581b27f95`:

```text
git diff --raw 581b27f95 41d3c518a -- apps/superadmin/test/goldens/activities apps/superadmin/test/app/router/goldens apps/superadmin/test/features/institutions/presentation/screens/goldens
```

Esse comando retorna uma linha por alvo no formato `:100644 100644 <blob-antes> <blob-depois> M <path>`; são 45 linhas, e os dois commits preservam todos os hashes completos sem depender de artefato temporário.
