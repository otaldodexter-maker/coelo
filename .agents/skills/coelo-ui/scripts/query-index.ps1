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

$matches = @(
    $entries | Where-Object {
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
        $queryTerms = @(
            if (-not [string]::IsNullOrWhiteSpace($Query)) {
                $Query.Trim() -split '\s+' | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            }
        )
        $matchesQuery = (
            $queryTerms.Count -eq 0 -or
            @(
                $queryTerms | Where-Object {
                    $haystack.IndexOf(
                        $_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -lt 0
                }
            ).Count -eq 0
        )
        $matchesId -and $matchesConsumer -and $matchesOwner -and
            $matchesStatus -and $matchesQuery
    }
)

if (-not $hasFilter) {
    $matches = @(
        $matches | Select-Object id, name, category, status, ownerPackage, consumers
    )
}

[ordered]@{
    count = $matches.Count
    entries = $matches
} | ConvertTo-Json -Depth 8 -Compress
