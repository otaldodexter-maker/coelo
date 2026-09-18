---
title: "D02 — perfil nominal ActivityAggregateConcurrency"
source: "assignment D00 r12; A01DirectoryAuditGreen; aggregate 20260908154257"
status: "profile-local-green; shared-wrapper-hunks-proposed; docker-not-executed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Entrega

Arquivos novos reservados e materializados:

- `packages/coelo_database/replay/profiles/ActivityAggregateConcurrency/profile.json`
- `packages/coelo_database/replay/profiles/ActivityAggregateConcurrency/Resolve-ActivityAggregateConcurrency.ps1`
- `packages/coelo_database/scripts/tests/ActivityAggregateConcurrencyProfile.Tests.ps1`

O perfil deriva o retorno pinado de `A01DirectoryAuditGreen`: 53 migrations
canônicas + 2 preflights. Acrescenta somente
`20260908154257_superadmin_activity_save_v2.sql`, terminando com 54 canônicas,
2 preflights, 56 SQL e zero bridge.

Proveniência normalizada CRLF/UTF-8:

| Artefato | SHA-256 |
| --- | --- |
| parent descriptor | `bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba` |
| parent resolver | `6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2` |
| aggregate migration | `17a282d3105536c751a6b908cf6dbb9ff8820ebbdc2751cab9f0227faf991a90` |
| novo descriptor | `4c836eb765c726c6cbcac342314230856df4b5611e82e085a2ff1f14e3690450` |
| novo resolver | `408831ed44f0f00a1417edf448644e3560d21e301c9e137ae5c0fa449f2e2412` |
| teste | `3c004fc13dba788b7472dc6666ac0414f6eef7a86f341e6a99ece340efbb75c7` |

Pester 3.4.0 focal: 3 pass, 0 fail. Nenhum Docker/banco foi iniciado. Houve
uma invocação anterior com `BeforeAll` incompatível com Pester 3 e uma asserção
de mensagem incompatível; ambas foram corrigidas antes do resultado verde e não
são contadas como casos adicionais.

## Hunks compartilhados propostos a D00

Em `Prepare-SafeMigrationReplay.ps1`:

```diff
- [ValidateSet(..., 'A01DirectoryAuditGreen', 'FReadDirectoryContractGreenDerived')]
+ [ValidateSet(..., 'A01DirectoryAuditGreen', 'FReadDirectoryContractGreenDerived', 'ActivityAggregateConcurrency')]
```

E no switch de resolver:

```diff
+ 'ActivityAggregateConcurrency' { 'profiles\ActivityAggregateConcurrency\Resolve-ActivityAggregateConcurrency.ps1' }
```

Em `Invoke-SafeLocalMigrationReplay.ps1`, aplicar a mesma entrada ao
`ValidateSet` e o path:

```diff
+ 'ActivityAggregateConcurrency' { 'replay\profiles\ActivityAggregateConcurrency\Resolve-ActivityAggregateConcurrency.ps1' }
```

Substituir a proibição genérica de concorrência em perfil nominal por uma
exceção fechada e adicionar o guard global abaixo antes de resolver o perfil:

```powershell
$activityAggregateConcurrencyRun =
  $RunActivityV2Concurrency -and
  $NominalProfile -ceq 'ActivityAggregateConcurrency' -and
  $TargetVersion -ceq '20260908154257' -and
  -not $FoundationOnly -and -not $AuthOnly -and
  $AdditionalMigration.Count -eq 0 -and -not $RunAuthLifecycle

if ($RunActivityV2Concurrency -and -not $activityAggregateConcurrencyRun) {
  throw 'activity v2 concurrency requires nominal profile ActivityAggregateConcurrency at target 20260908154257 without additions'
}

if ($NominalProfile) {
  if ($FoundationOnly -or $AuthOnly -or $AdditionalMigration.Count -gt 0 -or
      $RunAuthLifecycle -or
      ($RunActivityV2Concurrency -and -not $activityAggregateConcurrencyRun)) {
    throw 'nominal replay cannot be combined with other replay profiles, additions or an unrelated runner'
  }
  # existing resolver switch follows
}
```

Isso torna `-RunActivityV2Concurrency` inválido em full/Foundation/Auth,
qualquer outro perfil, outro target ou com adicionais. A invocação nominal fica:

```powershell
./scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260908154257 `
  -NominalProfile ActivityAggregateConcurrency `
  -TestPath @('supabase/tests/superadmin_activity_save_v2_test.sql') `
  -RunActivityV2Concurrency
```

O TAP esperado continua 46; o runner acrescenta a corrida já existente e duas
negações reais pós-lock. Isso permanece não executado até D00 integrar os hunks
compartilhados, revisar o conjunto e conceder novo slot.
