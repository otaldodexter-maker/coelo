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

function Assert-Equal {
    param(
        [Parameter(Mandatory)]
        $Actual,
        [Parameter(Mandatory)]
        $Expected,
        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Esperado: '$Expected'. Recebido: '$Actual'."
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
Assert-QueryContains -Query 'table views grouped detailed' `
    -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'hover card institutions' `
    -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'institution card status compact 24 hover focus touch' `
    -ExpectedId 'pattern.institution-card-status'
Assert-QueryContains -Query 'acessos pessoas tabs lineares categorias underline toolbar' `
    -ExpectedId 'pattern.directory-linear-tabs'
Assert-QueryContains -Query 'anti padrao hover cinza filtro cinza date picker radio checkbox rodape sem espacamento' `
    -ExpectedId 'pattern.rejected-visual-patterns'
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
Assert-QueryContains -Query 'login security checkbox password' `
    -ExpectedId 'pattern.approved-superadmin-surfaces'
Assert-QueryContains -Query 'home help center conversations' `
    -ExpectedId 'pattern.approved-superadmin-surfaces'
Assert-QueryContains -Query 'sidebar rail menu selected child' `
    -ExpectedId 'pattern.approved-superadmin-surfaces'
Assert-QueryContains -Query 'profile settings avatar theme reduced motion' `
    -ExpectedId 'pattern.approved-superadmin-surfaces'
Assert-QueryContains -Query 'institution create edit wizard footer' `
    -ExpectedId 'pattern.approved-superadmin-surfaces'

$broadQuery = 'hover cinza reto flyout instituicoes card'
$broadResult = & $queryScript -Query $broadQuery | ConvertFrom-Json
$broadIds = @($broadResult.entries | ForEach-Object { $_.id })

if ($broadResult.count -eq 0) {
    throw "Consulta ampla '$broadQuery' deveria usar correspondencias parciais."
}

Assert-Equal -Actual $broadIds[0] -Expected 'pattern.admin-directory' `
    -Message 'A correspondencia parcial com mais termos deve aparecer primeiro.'

$fixturePath = Join-Path ([System.IO.Path]::GetTempPath()) (
    "coelo-ui-query-$([guid]::NewGuid().ToString('N')).jsonl"
)

try {
    @(
        '{"id":"z.partial","name":"alpha beta","category":"pattern","status":"approved","purpose":"","useWhen":"","doNotUseWhen":"","ownerPackage":"test","consumers":[],"variants":[],"states":[],"tokens":[],"accessibility":"","publicFile":"","tests":[],"example":"","replacement":null}',
        '{"id":"a.partial","name":"alpha beta","category":"pattern","status":"approved","purpose":"","useWhen":"","doNotUseWhen":"","ownerPackage":"test","consumers":[],"variants":[],"states":[],"tokens":[],"accessibility":"","publicFile":"","tests":[],"example":"","replacement":null}',
        '{"id":"exact.match","name":"alpha beta gamma","category":"pattern","status":"approved","purpose":"","useWhen":"","doNotUseWhen":"","ownerPackage":"test","consumers":[],"variants":[],"states":[],"tokens":[],"accessibility":"","publicFile":"","tests":[],"example":"","replacement":null}'
    ) | Set-Content -LiteralPath $fixturePath -Encoding UTF8

    $exactResult = & $queryScript -Query 'alpha beta gamma' `
        -IndexPath $fixturePath | ConvertFrom-Json
    $exactIds = @($exactResult.entries | ForEach-Object { $_.id })
    Assert-Equal -Actual $exactResult.count -Expected 1 `
        -Message 'Correspondencias exatas devem ter precedencia sobre o fallback.'
    Assert-Equal -Actual $exactIds[0] -Expected 'exact.match' `
        -Message 'A consulta exata retornou uma entrada inesperada.'

    $rankedResult = & $queryScript -Query 'alpha beta ausente' `
        -IndexPath $fixturePath | ConvertFrom-Json
    $rankedIds = @($rankedResult.entries | ForEach-Object { $_.id })
    Assert-Equal -Actual ($rankedIds -join ',') `
        -Expected 'a.partial,exact.match,z.partial' `
        -Message 'Empates no fallback devem ser ordenados por id.'
}
finally {
    if (Test-Path -LiteralPath $fixturePath) {
        Remove-Item -LiteralPath $fixturePath -Force
    }
}

Write-Output 'query-index.tests.ps1: PASS'
