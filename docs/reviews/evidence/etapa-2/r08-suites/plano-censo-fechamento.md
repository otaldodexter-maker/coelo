---
fonte: R07 censo-final.md, JSON privado R07 e gate C0 R08
status: plano executável, não executado
atualizado: 2026-09-12
---

# Plano do censo completo de fechamento

Executar uma única vez na base integrada final do C0, em um processo, a partir de `apps/superadmin`. A suíte completa é `test`, incluindo `test/app`, `test/core/config`, `test/shared` e `test/features`.

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = "../../docs/reviews/evidence/etapa-2/r08-suites/censo-fechamento-$stamp.jsonl"
flutter test test --concurrency=2 --timeout=10m --reporter=json 2>&1 | Tee-Object -FilePath $out
$exit = $LASTEXITCODE
"nativeExitCode=$exit" | Add-Content -Path $out
exit $exit
```

A previsão operacional do C0 é 35–45 minutos, aproximadamente até 15:10. Não fazer rerun, não matar processos por nome genérico e não converter exit code. O caminho `../../docs/...` é relativo a `apps/superadmin`.

## Parser

Usar `censo-parser.js` com `--input`, `--output`, `--base` e `--exit-code`. Indexar `suite.id -> suite.path` e `testStart.test.id -> suiteID/name/metadata`; contar somente `testDone.testID` ligado a start conhecido. Preservar IDs e path relativo. Separar passed, failed, skipped, hidden, loading, errors, órfãos e desconhecidos. Capturar evento `done` como `{success,time}`, marcar duplicidade e registrar SHA-256 do input. Não colapsar casos por nome.

## Proveniência temporal

O R07 teve `426.010s` com `flutter test --reporter json -j 6`, portanto é referência paralela, não estimativa serial. A análise privada do JSON R07 encontrou `658` suítes, soma das durações por suíte `4130.980s`, mediana `4.688s` e máximo/span paralelo `59.166s`. Esses números informam o planejamento, mas o censo `--concurrency=2` deve medir sua duração própria.

## Critério de entrega

Publicar JSONL bruto, resultado derivado, SHA da base integrada, SHA do input, comando, timestamp, exit code nativo, evento done e listas detalhadas de pass/fail/skip/timeout/órfãos. Não declarar fechamento ou promoção enquanto houver merge posterior pendente.
