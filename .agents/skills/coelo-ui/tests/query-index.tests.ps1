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
Assert-QueryContains -Query 'popup modal dialog overlay' `
    -ExpectedId 'pattern.overlay-surfaces'
Assert-QueryContains -Query 'hover laranja arredondado' `
    -ExpectedId 'pattern.interaction-states'
Assert-QueryContains -Query 'envio antecipado disabled' `
    -ExpectedId 'pattern.interaction-states'
Assert-QueryContains -Query 'glifo assimetrico' `
    -ExpectedId 'pattern.interaction-states'
Assert-QueryContains -Query 'close dismiss vermelho' `
    -ExpectedId 'pattern.overlay-surfaces'
Assert-QueryContains -Query 'single-select' `
    -ExpectedId 'pattern.selection-controls'
Assert-QueryContains -Query 'scrollbar horizontal sempre visivel' `
    -ExpectedId 'admin.resizable-table'
Assert-QueryContains -Query 'cadastros edicoes superficie neutra' `
    -ExpectedId 'pattern.form-controls'
Assert-QueryContains -Query 'confirmacao binaria 50/50' `
    -ExpectedId 'pattern.form-controls'
Assert-QueryContains -Query 'rodape responsivo texto 200%' `
    -ExpectedId 'pattern.form-controls'
$instituicoes = "institui$([char]0x00E7)$([char]0x00F5)es"
$paginacao = "pagina$([char]0x00E7)$([char]0x00E3)o"
$autenticacao = "autentica$([char]0x00E7)$([char]0x00E3)o"

Assert-QueryContains -Query $instituicoes `
    -ExpectedId 'admin.resizable-table'
Assert-QueryContains -Query 'institutions' `
    -ExpectedId 'admin.pagination'
Assert-QueryContains -Query $paginacao `
    -ExpectedId 'admin.pagination'
Assert-QueryContains -Query 'pagination' `
    -ExpectedId 'admin.pagination'
Assert-QueryContains -Query $autenticacao `
    -ExpectedId 'core.form-text-field'
Assert-QueryContains -Query 'authentication' `
    -ExpectedId 'core.form-text-field'
Assert-QueryContains -Query 'login' `
    -ExpectedId 'core.form-text-field'
Assert-QueryContains -Query 'senha' `
    -ExpectedId 'core.form-text-field'
Assert-QueryContains -Query 'password' `
    -ExpectedId 'core.form-text-field'
Assert-QueryContains -Query 'view toggle cards table' `
    -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'hover card institutions' `
    -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'gap create banner table' `
    -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'flyout profile logout divider' `
    -ExpectedId 'pattern.flyout-actions'
Assert-QueryContains -Query 'settings profile menu' `
    -ExpectedId 'pattern.flyout-actions'
Assert-QueryContains -Query 'files import export' `
    -ExpectedId 'admin.file-actions'
Assert-QueryContains -Query 'negative exit close delete' `
    -ExpectedId 'pattern.negative-actions'
Assert-QueryContains -Query 'sair desligar encerrar fechar excluir' `
    -ExpectedId 'pattern.negative-actions'
Assert-QueryContains -Query 'popup two three equal buttons' `
    -ExpectedId 'pattern.dialog-actions'
Assert-QueryContains -Query 'dialog 50 50 stacked actions' `
    -ExpectedId 'pattern.dialog-actions'
Assert-QueryContains -Query 'screen footer buttons opposite extremes' `
    -ExpectedId 'pattern.form-controls'
Assert-QueryContains -Query 'orange outlined ghost button hierarchy' `
    -ExpectedId 'pattern.action-hierarchy'
Assert-QueryContains -Query 'primary secondary tertiary buttons' `
    -ExpectedId 'pattern.action-hierarchy'

Write-Output 'query-index.tests.ps1: PASS'
