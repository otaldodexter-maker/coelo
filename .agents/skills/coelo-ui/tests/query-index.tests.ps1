[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$queryScript = Join-Path $PSScriptRoot '..\scripts\query-index.ps1'

function Assert-QueryContains {
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        [Parameter(Mandatory)]
        [string]$ExpectedId
    )

    $result = & $queryScript -Query $Query | ConvertFrom-Json
    $ids = @($result.entries | ForEach-Object { $_.id })

    if ($ids -notcontains $ExpectedId) {
        throw "Query '$Query' não retornou '$ExpectedId'. IDs: $($ids -join ', ')"
    }
}

Assert-QueryContains -Query 'disabled' -ExpectedId 'core.search-field'
Assert-QueryContains -Query 'color.action.focus-ring' `
    -ExpectedId 'admin.resizable-table'
Assert-QueryContains -Query 'teclado' -ExpectedId 'admin.multi-select-filter'
Assert-QueryContains -Query 'coelo_search_field_test.dart' `
    -ExpectedId 'core.search-field'
Assert-QueryContains -Query 'listagem densa' `
    -ExpectedId 'admin.listing-toolbar'
Assert-QueryContains -Query 'CoeloAdminResizableTable<Row>' `
    -ExpectedId 'admin.resizable-table'

Write-Output 'query-index.tests.ps1: PASS'
