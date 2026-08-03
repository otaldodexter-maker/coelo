[CmdletBinding()]
param(
    [string]$Id,
    [string]$Query,
    [string]$Consumer,
    [string]$OwnerPackage,
    [string]$Status,
    [string]$IndexPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($IndexPath)) {
    $repositoryRoot = Resolve-Path -LiteralPath (
        Join-Path $PSScriptRoot '..\..\..\..'
    )
    $IndexPath = Join-Path $repositoryRoot.Path (
        'apps\catalog\assets\coelo-ui.index.jsonl'
    )
}

$resolvedIndex = Resolve-Path -LiteralPath $IndexPath
$entries = @(
    Get-Content -LiteralPath $resolvedIndex.Path -Encoding UTF8 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ | ConvertFrom-Json }
)

$hasFilter = -not (
    [string]::IsNullOrWhiteSpace($Id) -and
    [string]::IsNullOrWhiteSpace($Query) -and
    [string]::IsNullOrWhiteSpace($Consumer) -and
    [string]::IsNullOrWhiteSpace($OwnerPackage) -and
    [string]::IsNullOrWhiteSpace($Status)
)

$queryTerms = @(
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $Query.Trim() -split '\s+' | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
    }
)

$candidates = @(
    $entries | ForEach-Object {
        $entry = $_
        $matchesId = [string]::IsNullOrWhiteSpace($Id) -or $entry.id -eq $Id
        $matchesConsumer = (
            [string]::IsNullOrWhiteSpace($Consumer) -or
            @($entry.consumers) -contains $Consumer
        )
        $matchesOwner = (
            [string]::IsNullOrWhiteSpace($OwnerPackage) -or
            $entry.ownerPackage -eq $OwnerPackage
        )
        $matchesStatus = (
            [string]::IsNullOrWhiteSpace($Status) -or
            $entry.status -eq $Status
        )
        if (
            $matchesId -and $matchesConsumer -and $matchesOwner -and
            $matchesStatus
        ) {
            $haystack = @(
                $entry.id,
                $entry.name,
                $entry.category,
                $entry.status,
                $entry.purpose,
                $entry.useWhen,
                $entry.doNotUseWhen,
                $entry.ownerPackage,
                (@($entry.consumers) -join ' '),
                (@($entry.variants) -join ' '),
                (@($entry.states) -join ' '),
                (@($entry.tokens) -join ' '),
                $entry.accessibility,
                $entry.publicFile,
                (@($entry.tests) -join ' '),
                $entry.example,
                $entry.replacement
            ) -join ' '
            $matchedTermCount = @(
                $queryTerms | Where-Object {
                    $haystack.IndexOf(
                        $_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
                }
            ).Count
            [pscustomobject]@{
                entry = $entry
                matchedTermCount = $matchedTermCount
            }
        }
    }
)

$matches = @(
    $candidates | Where-Object {
        $_.matchedTermCount -eq $queryTerms.Count
    } | ForEach-Object { $_.entry }
)

if ($queryTerms.Count -gt 0 -and $matches.Count -eq 0) {
    $matches = @(
        $candidates |
            Where-Object { $_.matchedTermCount -gt 0 } |
            Sort-Object -Property @(
                @{ Expression = 'matchedTermCount'; Descending = $true },
                @{ Expression = { $_.entry.id }; Ascending = $true }
            ) |
            ForEach-Object { $_.entry }
    )
}

if (-not $hasFilter) {
    $matches = @(
        $matches | Select-Object id, name, category, status, ownerPackage, consumers
    )
}

[ordered]@{
    count = $matches.Count
    entries = $matches
} | ConvertTo-Json -Depth 8 -Compress
