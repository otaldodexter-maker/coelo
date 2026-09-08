---
title: Modelos — comparação local antes/depois da autorização pré-lookup
source: Autorização do Coordenador; corretiva63e2cdd6; pacote464a947d; execuções root
status: RED49 reproduzido; GREEN50 com38 pgTAP PASS
generated: 2026-09-08
red_started_utc: 2026-09-08T03:10:30.4660359Z
green_started_utc: 2026-09-08T03:13:46.9549294Z
green_cleanup_verified_utc: 2026-09-08T03:15:13.8697189Z
---

# Modelos READ:49 para50

A corretiva20260908021821 eliminou as falhas de autorização anterior à busca. Na base49, as fixtures11+17 emitiram28TAP completos:24PASS/4FAIL, com asserções5 e7 falhando em ambas. Na base50 corrigida, as mesmas fixtures mais ACL10 passaram: **38/38 PASS, exit0**.

## Pacote fixo

Perfis ModelReadAuthorizationRed49/target20260901200206 e ModelReadAuthorizationGreen50/target20260908021821. Base Auth45 +20260901170731 +20260901193000 +2preflights; GREEN acrescenta somente a corretiva21821 do commit63e2cdd6011e25822cfc7ac2be6de7b6b3208b4e, SHA CRLF b489f6ece6bc12c681d868ff9c68fdc13c00bdb52c3deda09b30aeccd418f992.

O pacote464a947dff729acfaabb5ee6fbdd7faa242b6b1e teve332/332Pester, parse e revisão independente aprovados. Hashes completos de perfil/resolver/scripts/fixtures estão em models-a01-green-preparation-2026-09-08.md.

Nenhuma fixture foi alterada entre os dois replays. A11 manteve8611bytesLF/fa1b23feb4089ae597b6cc4592ff66d51bb6d6f7ae11d3a7b6ad32e8e8d2b81b. A17 estava em12513bytesCRLF/d3464394c05ba86cc021e4fccdbcc4c8884548819b80048a48e61ba812beb76a, equivalente ao LF084d70c291552ff779192f96c4821b9d9b1a98dc4efaa0bec9d3435874de8e73 aprovado. Uma checagem inicial exigiu apenasLF na17 e parou antes de staging/SQL; a checagem foi corrigida para aceitar exatamente os dois hashes aprovados, sem regravar a fixture.

## RED49 real

Início03:10:30.4660359UTC; identidade coelo_safe_57753ddf58a746a18c7b4fb71df63; staging criado03:10:36.5545356UTC, marcador conferido. A base49 aplicou integralmente.

| Asserção em cada fixture | Obtido | Esperado |
|---|---|---|
| 5 — sessão inválida em modelo existente/inexistente | SAI_SESSION_INVALID / SAI_PERMISSION_DENIED | SAI_SESSION_INVALID em ambos |
| 7 — pessoa global em modelo existente/inexistente | SAI_INTERNAL_CONTEXT_DENIED / SAI_PERMISSION_DENIED | SAI_INTERNAL_CONTEXT_DENIED em ambos |

As seis asserções adicionais da fixture17 passaram na base antiga. As quatro falhas totais representam duas condições repetidas nas duas fixtures, sem aborto ou falha ACL. pg_prove reportou Files2/Tests28/FAIL; wrapperexit1.

Cleanup independente03:13:35.1074601UTC: zero containers, volumes e redes próprios; staging ausente; histórico alheio preservado.

## GREEN50 real

Início03:13:46.9549294UTC; identidade coelo_safe_dfcbcbafabb74cb38dd3d1a5f196d; staging criado03:13:47.8990032UTC, marcador conferido. A base50 aplicou integralmente, incluindo21821.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260908021821 -NominalProfile ModelReadAuthorizationGreen `
  -TestPath @(
    'packages/coelo_database/supabase/tests/access_profile_models_read_authorization_test.sql',
    'packages/coelo_database/supabase/tests/access_profile_models_read_prelookup_regression_test.sql',
    'packages/coelo_database/supabase/tests/access_profile_models_read_helper_acl_test.sql'
  )
```

```text
Applying migration 20260908021821_access_profile_models_read_prelookup_authorization.sql...
Finished supabase db reset on branch main.
All tests successful.
Files=3, Tests=38
Result: PASS
Safe local replay completed through 20260908021821 with isolated identity coelo_safe_dfcbcbafabb74cb38dd3d1a5f196d and zero residual resources.
```

Os dez TAP de catálogo provaram helper existente, ownerpostgres, SECURITYDEFINER, STABLE, search_path vazio e EXECUTE efetivo negado a anon/authenticated/service_role e PUBLIC. Não houve grants novos. As fixtures funcionais chamam as RPCs sob authenticated e emitem TAP após RESET ROLE.

Cleanup independente03:15:13.8697189UTC: zero containers, volumes e redes próprios; staging ausente; staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a preservado.

## Limites

As permissões por domínio sem platform.read foram mantidas nas asserções existentes e novas. Esta prova local não cobre toda a matriz possível de roles/tenants, o fluxo Flutter completo ou produção.38 é a contagem TAP, incluindo as11asserções repetidas dentro da fixture17. Nenhuma mutação remota, ledger, deploy ou mudança de regra de produto. Plano e README próprios atualizados; rastreadores centrais pertencem ao Coordenador.
