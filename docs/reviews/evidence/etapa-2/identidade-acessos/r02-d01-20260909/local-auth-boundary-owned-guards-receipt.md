---
title: "D01 — mecanismo físico dos três negativos do guard local"
source: "local-auth-boundary-owned-guards.txt; execução PowerShell inline de 2026-09-09; packages/coelo_database/scripts/Test-LocalAuthRecoveryBoundary.ps1"
status: "verified-tool-guards-only"
generated_at: "2026-09-09"
---

Complemento retrospectivo da execução já registrada: 3/3 negativas PASS e
cleanup confirmado. Não houve nova execução. O harness foi um comando
PowerShell inline; não existe arquivo temporário de harness a preservar.

Cada raiz foi gerada por `'coelo_safe_' +
[guid]::NewGuid().ToString('N').Substring(0,29)` sob
`[IO.Path]::GetTempPath()`. Os IDs aleatórios completos não foram registrados no
log original. Os nomes abaixo identificam as variáveis efetivamente usadas;
`%TEMP%\coelo_safe_<29hex>` representa o formato nominal dos paths.

| Fixture | Construção física | Resultado esperado e observado |
| --- | --- | --- |
| `$mismatchFixture.Path` | Diretório normal, arquivo `.coelo-safe-replay` contendo `wrong-project-id` | `SAFE_MARKER_IDENTITY` |
| `$rootLinkFixture.Path` → `$rootTargetFixture.Path` | Junction de diretório criada por `New-Item -ItemType Junction`; alvo continha marcador com o ID correto da raiz nominal | `SAFE_ROOT_REPARSE` |
| `$markerLinkFixture.Path\.coelo-safe-replay` → `$markerTargetFixture.Path` | Raiz normal com marcador que era uma junction para outro diretório TEMP | `SAFE_MARKER_REPARSE` |

Trechos executados do mecanismo de criação:

```powershell
[IO.File]::WriteAllText((Join-Path $mismatchFixture.Path '.coelo-safe-replay'), 'wrong-project-id')
[IO.File]::WriteAllText((Join-Path $rootTargetFixture.Path '.coelo-safe-replay'), $rootLinkFixture.Id)
$null = New-Item -ItemType Junction -Path $rootLinkFixture.Path -Target $rootTargetFixture.Path
$markerLink = Join-Path $markerLinkFixture.Path '.coelo-safe-replay'
$null = New-Item -ItemType Junction -Path $markerLink -Target $markerTargetFixture.Path
```

O marcador reparse foi uma junction de diretório, não um symlink de arquivo.
O guard verifica `ReparsePoint` antes de verificar tipo/conteúdo do marcador;
o harness exigiu exatamente a exceção `SAFE_MARKER_REPARSE`. Não foi alegado
teste separado de symlink de arquivo.

Cada caso chamou o script real com `-ProjectRoot $Fixture.Path -ProjectId
$Fixture.Id`; o harness capturou a exceção e comparou sua mensagem completa
com `'recovery boundary rejected: ' + $Expected`. A recusa ocorreu antes da
importação dos helpers que consultam Supabase/Docker, sem inicializar recursos.

O `finally` primeiro conferiu o path absoluto de cada junction sob o prefixo
TEMP e chamou `[IO.Directory]::Delete($ownedLink)` **sem opção recursiva**,
removendo somente a junction. Em seguida, para cada diretório próprio, conferiu
novamente o path absoluto sob TEMP, recusou o próprio diretório TEMP ou um
reparse ainda presente e executou `Remove-Item -LiteralPath
$resolvedGuardPath -Recurse -Force`. Assim a limpeza recursiva ocorreu apenas
em diretórios normais criados pelo harness, depois de remover os links.

Ao final, `Test-Path -LiteralPath` para todas as raízes próprias retornou
ausência. A quarta linha PASS do log registra cleanup; não é um quarto teste
funcional. Hash SHA-256 do log existente:
`07F5AC6CBBA929087353B41CC39492BFA0AA410B69325325FA037073BF06BE08`.
Essa prova de ferramenta permanece separada dos 46 gates integrados pendentes.
