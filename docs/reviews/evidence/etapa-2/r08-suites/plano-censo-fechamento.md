---
fonte: R07 censo-final.md e verificacao-fechamento.md; gate C0 R08
status: corrigido para fechamento integrado
atualizado: 2026-09-12
---

# Plano executável do censo completo de fechamento

## Execução autorizada

Executar uma única vez, na base integrada do C0, dentro da janela de fechamento de 30 minutos. A partir de `apps/superadmin`, o recorte é a suíte completa descoberta pelo diretório `test`, incluindo `test/app`, `test/core/config`, `test/shared` e todas as famílias `test/features`; não restringir aos três diretórios de G8.

```powershell
$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = "../../docs/reviews/evidence/etapa-2/r08-suites/censo-fechamento-$stamp.jsonl"
flutter test test --concurrency=1 --timeout=10m --reporter=json 2>&1 | Tee-Object -FilePath $out
$flutterExit = $LASTEXITCODE
"nativeExitCode=$flutterExit" | Add-Content -Path $out
exit $flutterExit
```

O comando deve ser executado em `apps/superadmin`; o caminho `../../docs/...` aponta para a raiz do repositório. Não fazer rerun, não matar processos por nome genérico e não converter `exit 1` em sucesso. O timeout de 10 minutos é por unidade reportada pelo runner; a janela global de fechamento é 30 minutos.

## Parser e identidade

Consumir o JSONL bruto sem inferir casos por `print`, `testStart` ou `allSuites`. O parser deve indexar `suite.id -> suite.path` e `testStart.test.id -> {suiteID, name, metadata}`; contar somente `testDone.testID` ligado a um start conhecido. Preservar `testID`, `suiteID`, caminho e nome completos. Separar `passed`, `failed`, `skipped`, `hidden/loading`, timeout, órfãos e desconhecidos, mantendo `skipReason` e o exit code nativo.

Chaves de caso são IDs/eventos ligados (`suiteID + testID`), não somente nomes. Nomes repetidos em arquivos diferentes ou no mesmo arquivo não podem ser colapsados. A reconciliação anônima R08 (`293` observados, `281` nomes únicos, `12` duplicações) é uma medição textual separada e não deve ser misturada ao censo JSONL.

## Skips e resultado esperado

O ponto de comparação R07 é `6727 PASS, 33 FAIL, 11 SKIP`, medido em `426.010s` (`7m06.010s`) com exit `1`; os 11 skips devem ser listados individualmente pelo parser, com motivo, sem allowlist. O relatório deve publicar contagens e casos, não apenas totais, e explicar qualquer variação sem somar reruns históricos.

## Estimativa medida

A execução R07 levou `426.010s` no reporter. Para o censo serial (`concurrency=1`), reservar os `30m` do protocolo; o limite operacional é `1800s`, equivalente a `4,23x` o tempo R07 medido. A previsão deve registrar início/fim, duração real, p50/p95 por unidade quando os timestamps estiverem disponíveis, máximo, timeout e margem restante. Não usar contagem de testes como substituto de duração.

## Recibo obrigatório

Entregar ao C0 o JSONL bruto, relatório derivado, comando, SHA da base integrada, timestamp, exit code nativo, duração e listas de pass/fail/skip/timeout/órfãos. Sem esse pacote, não declarar o censo completo nem promover cobertura.
