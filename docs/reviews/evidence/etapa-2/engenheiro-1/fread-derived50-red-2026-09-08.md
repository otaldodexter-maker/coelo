---
title: F-READ — resultado real do RED derivado de 50 arquivos
source: Autorização nominal do Coordenador; b236f2c6; fixture897ee8f7; execução root
status: base50 aplicada; duas falhas por funções ausentes e aborto da fixture
generated: 2026-09-08
executed_utc: 2026-09-08T02:59:58.5944171Z
cleanup_verified_utc: 2026-09-08T03:01:27.6963608Z
---

# FReadDerived50

**Os50 arquivos aplicaram integralmente** no banco local descartável. A materialização nominal superou o42601 da base canônica histórica. A fixture117 aprovada executou somente **dois TAP, ambos FAIL**, e abortou na linha8 por função pública ausente. O reader20260908000049 não integra esse RED.

## Pacote e execução

Perfil FReadDirectoryContractRedDerived, target20260901200206, wrapperb236f2c6. Inputs, guards, hashes e272Pester estão em fread-derived-preparation-2026-09-07.md. O conversor gerou somente155005 (hash06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe) e manteve os49outros. A fixture117 foi conferida novamente:35594bytesLF, c2758681c420651557cfff9078651cb60a74a9b4cb98fa75fb2f38094b83c986.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile FReadDirectoryContractRedDerived `
  -TestPath packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql
```

Identidade coelo_safe_0950663a49624f46a118e612b5109. Início02:59:58.5944171UTC; staging criado02:59:59.4529287UTC, marcador conferido durante a execução.

```text
Applying migration 20260813155005_forms_definition_and_capabilities.sql...
Applying migration 20260813155116_forms_distribution_and_occurrences.sql...
Applying migration 20260827235500_superadmin_internal_institution_list_filter.sql...
Applying migration 20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql...
Finished supabase db reset on branch main.
# Failed test 1: "internal directory public boundary exists"
# Failed test 2: "internal directory private implementation exists"
Non-zero exit status: 3
Parse errors: No plan found in TAP output
Files=1, Tests=2
Result: FAIL
superadmin_forms_directory_internal_read_test.sql:8: ERROR: function "public.superadmin_forms_directory_v2(jsonb)" does not exist
safe local pgTAP failed with exit code 1
```

O log não imprime SQLSTATE literalmente; a mensagem corresponde a undefined_function/42883. Não se trata de117falhas funcionais nem de um GREEN parcial da fixture. O primeiro has_function_privilege exige a função ausente e impede alcançar o plan117. pg_prove reportou exit3, CLI/wrapper1.

## Cleanup e próximo gate

Verificação independente03:01:27.6963608UTC: zero containers, volumes e redes próprios; staging ausente; staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a preservado.

Próximo pacote proposto ao Coordenador: perfil separado GREEN derivado51 com reader aprovado e a mesma transformação nominal. A autorização deste RED não inclui esse reader. Nenhum grant extra, bridge, ledger, remoto, deploy ou conclusão E2E. README e plano próprios refletem o resultado; nenhuma regra durável de produto mudou.
