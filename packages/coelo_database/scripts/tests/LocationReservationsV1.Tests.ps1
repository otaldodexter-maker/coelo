$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$profileRoot = Join-Path $packageRoot 'replay\profiles\LocationReservationsV1'
$resolverPath = Join-Path $profileRoot 'Resolve-LocationReservationsV1.ps1'
$descriptorPath = Join-Path $profileRoot 'profile.json'

function Get-ReservationTestHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'LocationReservationsV1 nominal profile' {
  It 'merges the six additions into the reviewed 64-file chain' {
    $resolved = & $resolverPath

    @($resolved.Canonical).Count | Should Be 59
    @($resolved.Preflight).Count | Should Be 2
    @($resolved.LocationBootstrap).Count | Should Be 3
    @($resolved.Additional.Name) | Should Be @(
      '20260831192831_activities_v2_actor_attribution.sql',
      '20260831195118_activities_v2_actor_provenance_hardening.sql',
      '20260831195944_activities_v2_actor_provenance_semantics.sql',
      '20260831203645_activities_v2_permissions_receipts.sql',
      '20260831211945_activities_v2_internal_gateways.sql',
      '20260909165000_superadmin_location_reservations_v2.sql'
    )
  }

  It 'orders Activities before the location cutover and the motor last' {
    $names = @((& $resolverPath).Canonical.Name)

    [array]::IndexOf($names, '20260831211945_activities_v2_internal_gateways.sql') |
      Should BeLessThan ([array]::IndexOf($names, '20260908031000_superadmin_location_catalog_v2.sql'))
    $names[-1] | Should Be '20260909165000_superadmin_location_reservations_v2.sql'
  }

  It 'pins every new canonical input' {
    $descriptor = [IO.File]::ReadAllText($descriptorPath) | ConvertFrom-Json
    foreach ($addition in @($descriptor.canonical_additions)) {
      Get-ReservationTestHash (Join-Path (Join-Path $packageRoot 'migrations') $addition.file) |
        Should Be $addition.sha256_crlf_utf8
    }
  }

  It 'keeps the location snapshots and forms materialization from its parent' {
    $resolved = & $resolverPath

    @($resolved.LocationBootstrap.Name)[0..1] | Should Be @(
      '20260908030958_location_form_options_remote_snapshot_local.sql',
      '20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
    )
    $resolved.FormsDefinitionMaterialization.SourceMigration |
      Should Be '20260813155005_forms_definition_and_capabilities.sql'
  }

  It 'adds three Owner-only capabilities without inventing an MFA gate' {
    $resolved = & $resolverPath
    $bootstrap = [IO.File]::ReadAllText($resolved.ReservationBootstrap.FullName)

    foreach ($capability in @(
      'locations.reservations.read',
      'locations.reservations.manage',
      'locations.reservations.override')) {
      $bootstrap | Should Match ([regex]::Escape("'$capability'"))
    }
    @([regex]::Matches($bootstrap, ",false,'active'\)")).Count | Should Be 3
    $bootstrap | Should Match "role_record.code='owner'"
    $bootstrap | Should Not Match 'requires_mfa\s*,?\s*true'
    $bootstrap | Should Not Match 'role_record.code\s+in'
  }

  It 'rejects a target other than the reserved motor version' {
    { & $resolverPath -TargetVersion '20260908190650' } |
      Should Throw 'LocationReservationsV1 requires target 20260909165000'
  }
}
