[CmdletBinding()]
param([string]$TargetVersion = '20260910120000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-PeopleAalFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "PeopleReadAal1 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "PeopleReadAal1 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-PeopleAalHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local extension for the people read AAL1 candidate.
#
# Base: the reviewed foundation manifest minus the three entries that cannot
# apply anywhere as written and that this domain does not depend on --
# 20260901101500 chat v2 (23502, platform_permissions insert without the three
# NOT NULL labels), 20260901185008 notices v2 (42P01, alters public.notice_events
# after the chain's own second entry moved it to analytics) and 20260901191921
# circulars v2 (23502, the same defect as chat v2). All three belong to other
# packages and are reported, not repaired here.
#
# 20260901190432 invites v2 is verified against its own pin rather than the
# manifest's, because it was corrected in this round (gen_random_bytes without a
# schema inside a search_path='' function) and the manifest still records the
# pre-fix content. Re-blessing the manifest is the harness owner's call, since
# its hash is pinned by ten other profiles.
#
# Addition: the candidate itself, which is NOT in the manifest.
#
# This is not a generic extension mechanism and not a remote authorization.
#
# Contagens revisadas em 2026-09-10: o manifesto de fundacao passou de 67 para 68
# entradas quando a coordenacao acrescentou 20260812000000_chat_production_contract.sql
# em ordem de versao (F-R03-FCR-003), fechando a lacuna que impedia qualquer base
# posterior a 20260901101500 de ser montada. As exclusoes deste perfil continuam
# valendo: o reparo do manifesto resolve a TABELA ausente, nao os defeitos de
# conteudo de chat v2, avisos v2 e circulares v2, que seguem sem correcao em dev.

if ($TargetVersion -cne '20260910120000') {
  throw "PeopleReadAal1 requires target 20260910120000; received $TargetVersion"
}

$manifestFile = Assert-PeopleAalFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
$entries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'PeopleReadAal1 base manifest entry is invalid'
  }
  [pscustomobject]@{ file = $Matches[1]; version = $Matches[2]; sha256_crlf_utf8 = $Matches[3] }
})
if ($entries.Count -ne 68 -or $entries[-1].version -cne '20260901200206') {
  throw 'PeopleReadAal1 requires the unchanged 68-entry foundation manifest'
}

$excludedNames = @(
  '20260901101500_superadmin_internal_chat_v2.sql',
  '20260901185008_superadmin_internal_notices_v2.sql',
  '20260901191921_superadmin_internal_circulars_v2.sql'
)
$repinnedName = '20260901190432_superadmin_internal_invites_v2.sql'
$selected = @($entries | Where-Object {
  $_.file -cnotin $excludedNames -and $_.file -cne $repinnedName
})
if ($selected.Count -ne 64) {
  throw 'PeopleReadAal1 requires the three unreachable entries and the repinned invites migration to be present in the manifest and handled here'
}

$repinned = Assert-PeopleAalFile (Join-Path (Join-Path $packageRoot 'migrations') $repinnedName)
if ((Get-PeopleAalHash $repinned.FullName) -cne
    'e213807cab3a07bf49384cc832b6074d81d7fef26269001f239463dac72d07c3') {
  throw "PeopleReadAal1 input hash mismatch: $repinnedName"
}

$candidateName = '20260910120000_people_read_aal1_for_mvp.sql'
$candidate = Assert-PeopleAalFile (Join-Path (Join-Path $packageRoot 'migrations') $candidateName)
if ((Get-PeopleAalHash $candidate.FullName) -cne
    'd5bd0f04e7e87b603b7f858e57acfae3d02d9c6aa3963ffd7643a9a009e0089f') {
  throw "PeopleReadAal1 input hash mismatch: $candidateName"
}

$fromManifest = @($selected | ForEach-Object {
  $file = Assert-PeopleAalFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-PeopleAalHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "PeopleReadAal1 input hash mismatch: $($_.file)"
  }
  $file
})
$canonical = @(@($fromManifest) + @($repinned) + @($candidate) | Sort-Object Name)

$preflight = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql' |
  Sort-Object Name | ForEach-Object { Assert-PeopleAalFile $_.FullName })
if ($preflight.Count -ne 2) {
  throw 'PeopleReadAal1 requires exactly the two inherited preflights'
}

$allInputs = @($canonical) + @($preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 66 -or $allInputs.Count -ne 68 -or
    @($versions | Sort-Object -Unique).Count -ne 68 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'PeopleReadAal1 requires 66 unique canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($candidate)
  ManifestHash = (Get-PeopleAalHash $manifestFile.FullName)
}
