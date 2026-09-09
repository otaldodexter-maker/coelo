$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$profileRoot = Join-Path $packageRoot 'replay\profiles\LocationCatalogV2'
$resolverPath = Join-Path $profileRoot 'Resolve-LocationCatalogV2.ps1'
$descriptorPath = Join-Path $profileRoot 'profile.json'

function Get-LocationCatalogTestHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'LocationCatalogV2 nominal profile' {
  It 'resolves the reviewed catalog chain without running SQL' {
    $resolved = & $resolverPath

    @($resolved.Canonical).Count | Should Be 53
    @($resolved.Preflight).Count | Should Be 2
    @($resolved.Additional).Count | Should Be 4
    @($resolved.LocationBootstrap).Count | Should Be 2
    @($resolved.Additional.Name) | Should Be @(
      '20260908031000_superadmin_location_catalog_v2.sql',
      '20260908190646_superadmin_locations_update_status_v2.sql',
      '20260908190648_superadmin_locations_copy_v2.sql',
      '20260908190650_superadmin_locations_schedule_v2.sql'
    )
    @($resolved.LocationBootstrap.Name) | Should Be @(
      '20260908030958_location_form_options_remote_snapshot_local.sql',
      '20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
    )
  }

  It 'inherits the reviewed invalid-argument envelope bridge without a new pin' {
    $resolved = & $resolverPath
    $bridge = @($resolved.Canonical | Where-Object {
      $_.Name -eq '20260827235500_superadmin_internal_institution_list_filter.sql'
    })

    $bridge.Count | Should Be 1
    (Get-LocationCatalogTestHash $bridge[0].FullName) |
      Should Be 'c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa'
    @(([IO.File]::ReadAllText($descriptorPath) | ConvertFrom-Json).extra_bridges).Count |
      Should Be 0
  }

  It 'keeps the remote options snapshot local and explicitly selected' {
    $resolved = & $resolverPath
    $snapshot = [IO.File]::ReadAllText(@($resolved.LocationBootstrap)[0].FullName)

    $snapshot | Should Match 'LOCAL SNAPSHOT ONLY, NOT A PRODUCTION MIGRATION'
    $snapshot | Should Match "coelo.local_replay',true\)\s+is distinct from 'location-catalog-v2-remote-options-snapshot'"
    $snapshot | Should Match 'definition_md5_raw": "65fe6408f0f2c6b0c1c9d71a809f2d80"'
    $snapshot | Should Match 'local options baseline drift'
  }

}

Describe 'LocationCatalogV2 snapshot derivation' {
  It 'accepts only the three proven baseline EOL representations and rejects semantic drift' {
    $source = [IO.File]::ReadAllText((Join-Path $packageRoot 'migrations\20260811200614_activity_read_model_contract_hardening.sql'))
    $bodyMatch = [regex]::Match($source, '(?s)create or replace function app_private\.superadmin_get_activity_form_options\(p_institution_id uuid\).*?as \$\$(.*?)\$\$;')
    $bodyMatch.Success | Should Be $true
    $bodyLf = $bodyMatch.Groups[1].Value.Replace("`r`n", "`n")
    $header = "CREATE OR REPLACE FUNCTION app_private.superadmin_get_activity_form_options(p_institution_id uuid)`n RETURNS jsonb`n LANGUAGE plpgsql`n STABLE SECURITY DEFINER`n SET search_path TO ''`nAS " + '$function$'
    $footer = '$function$' + "`n"
    $md5 = [Security.Cryptography.MD5]::Create()
    try {
      $hash = { param([string]$Text)
        ([BitConverter]::ToString($md5.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Text)))).Replace('-', '').ToLowerInvariant()
      }
      $fixture = [IO.File]::ReadAllText((Join-Path $packageRoot 'tests\fixtures\20260908030958_location_form_options_remote_snapshot_local.sql'))
      $pinsMatch = [regex]::Match($fixture, '(?s)md5\(pg_get_functiondef\(proc_record\.oid\)\) not in \((.*?)\)')
      $pinsMatch.Success | Should Be $true
      $pins = @([regex]::Matches($pinsMatch.Groups[1].Value, "'[0-9a-f]{32}'") | ForEach-Object { $_.Value.Trim("'") })
      $pins.Count | Should Be 3
      foreach ($body in @($bodyMatch.Groups[1].Value, $bodyLf, $bodyLf.Replace("`n", "`r`n"))) {
        $definition = $header + $body + $footer
        $pins -contains (& $hash $definition) | Should Be $true
        (& $hash ($definition.Replace("`r`n", "`n"))) | Should Be 'b951e603ef34b7d26597356a16eb6d06'
      }
      $changed = ($header + $bodyLf + $footer).Replace("activities.read", "platform.read")
      $pins -contains (& $hash $changed) | Should Be $false
      (& $hash $changed) | Should Not Be 'b951e603ef34b7d26597356a16eb6d06'
    } finally { $md5.Dispose() }
  }

  It 'preserves the original snapshot apart from local opt-in and proven baseline EOL pins' {
    $resolved = & $resolverPath
    $derived = [IO.File]::ReadAllText(@($resolved.LocationBootstrap)[0].FullName).
      Replace("`r`n", "`n").Replace("`r", "`n")
    $optIn = "set local coelo.local_replay = 'location-catalog-v2-remote-options-snapshot';`n"
    $eolGuard = @'
  -- Same canonical body from 20260811200614: CRLF, LF, and checkout mixed EOL.
  -- Prepare copies bytes; its source fingerprint normalizes EOL. Keep both pins.
  if md5(pg_get_functiondef(proc_record.oid)) not in (
      '70700ddc38d42df4fae75765b7ff2617',
      'b951e603ef34b7d26597356a16eb6d06',
      '7a39603e364397b5b50f1a3a1f9e4b69')
'@
    $eolGuard = $eolGuard.Replace("`r`n", "`n")
    ([regex]::Matches($derived, [regex]::Escape($eolGuard))).Count | Should Be 1
    $derived = $derived.Replace($eolGuard,
      "  if md5(pg_get_functiondef(proc_record.oid)) <> '70700ddc38d42df4fae75765b7ff2617'")
    $withoutOptInPath = Join-Path $TestDrive 'location-options-original.sql'

    ([regex]::Matches($derived, [regex]::Escape($optIn))).Count | Should Be 1
    [IO.File]::WriteAllText($withoutOptInPath, $derived.Replace($optIn, ''),
      [Text.UTF8Encoding]::new($false))
    # Final original snapshot from 9e689374 / catalog read 25cd74a9.
    Get-LocationCatalogTestHash $withoutOptInPath |
      Should Be '6c3002b500da4ecd623c3bd5e0ddd04950785b31c4bbcc858a702e5f3ff11c5e'
  }
}

Describe 'LocationCatalogV2 nominal profile continuation' {
  It 'keeps the six location capabilities Owner-only and phase-policy neutral' {
    $resolved = & $resolverPath
    $bootstrap = [IO.File]::ReadAllText(@($resolved.LocationBootstrap)[1].FullName)

    foreach ($capability in @(
      'locations.read', 'locations.create', 'locations.update',
      'locations.status', 'locations.copy', 'locations.schedule')) {
      $bootstrap | Should Match ([regex]::Escape("'$capability'"))
    }
    $bootstrap | Should Match "role_record.code='owner'"
    @([regex]::Matches($bootstrap, ",false,'active'\)")).Count | Should Be 6
    $bootstrap | Should Not Match "requires_mfa\s*,?\s*true"
    $bootstrap | Should Not Match "role_record.code\s+in"
  }

  It 'rejects an earlier target before selecting files' {
    { & $resolverPath -TargetVersion '20260908190648' } |
      Should Throw 'LocationCatalogV2 requires target 20260908190650'
  }

  It 'pins the four final migration snapshots' {
    $descriptor = [IO.File]::ReadAllText($descriptorPath) | ConvertFrom-Json
    $expected = @{
      '20260908031000_superadmin_location_catalog_v2.sql' = '4c9500d9cb8c3f82b301796b71e83816142a941f0a0f63dec58e2ae04c2e5995'
      '20260908190646_superadmin_locations_update_status_v2.sql' = '2b96f81408fa1c1b99678ddf0b70e071a519f98acda6d43a8670d6d8457aa061'
      '20260908190648_superadmin_locations_copy_v2.sql' = 'b7e21511d0a8db634aefdf7ecaa89c75616f941a82728a48a86c7a16a852fd76'
      '20260908190650_superadmin_locations_schedule_v2.sql' = 'ef3e84af397b1808c27573ea8eb0a75541f1d0d32330fd4507c3464997760ac3'
    }

    foreach ($addition in @($descriptor.canonical_additions)) {
      $addition.sha256_crlf_utf8 | Should Be $expected[$addition.file]
      Get-LocationCatalogTestHash (Join-Path (Join-Path $packageRoot 'migrations') $addition.file) |
        Should Be $expected[$addition.file]
    }
  }
}
