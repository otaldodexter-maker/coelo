---
fonte: [R07 final, C0 gate 160]
status: proposta executável para fechamento integrado
atualizado: 2026-09-12
---

# Plano do censo completo único de fechamento

## Limite e autorização

Executar uma única vez, somente na base integrada consolidada e somente quando o C0 abrir o slot de fechamento. Não executar na branch G8 durante este gate. O censo deve medir o recorte Superadmin autorizado da Etapa 2: `test/app`, `test/core/config` e `test/shared`; não incluir `lib/features`, `lib/shared/presentation`, `packages/coelo_ui` ou `pubspec`.

## Comando PowerShell

Executar a partir de `apps/superadmin`, preservando o exit code nativo do Flutter e salvando o JSON bruto:

```powershell
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = "docs/reviews/evidence/etapa-2/r08-suites/censo-fechamento-$stamp.jsonl"
$dirs = @('test/app', 'test/core/config', 'test/shared')
flutter test --concurrency=1 --timeout=10m --reporter=json @dirs 2>&1 | Tee-Object -FilePath $out
$flutterExit = $LASTEXITCODE
"flutterExitCode=$flutterExit" | Add-Content -Path $out
exit $flutterExit
```

O executor não deve somar reruns, interromper `dart.exe`/`flutter_tester.exe` por nome genérico, nem converter falha em sucesso. Se o processo exceder `10m` por unidade reportada pelo runner, registrar timeout e preservar o arquivo parcial; não repetir automaticamente.

## Parser e métricas

Após a execução, usar um parser dedicado sobre o JSONL, sem inferir casos por `print` ou `testStart`. O parser deve:

- indexar `suite.id -> suite.path`;
- indexar `testStart.test.id -> {suiteID, name, metadata}`;
- aceitar como execução apenas `testDone.testID` ligado a um `testStart` conhecido;
- preservar `testID`, `suiteID`, caminho e nome completos em cada registro;
- separar `passed`, `failed`, `skipped`, `timeout`, `hidden/loading` e eventos desconhecidos;
- contar `skipped` pela combinação de `testDone.skipped` e `testStart.test.metadata.skip`, sem apagar o motivo;
- emitir exit code nativo, contagens e lista de anomalias, mesmo quando o Flutter falhar;
- rejeitar casos órfãos, `testDone` sem start e `widget_tester.dart` como suite semântico.

A saída derivada deve conter base, revisão, SHA integrado, timestamp, diretórios, comando, exit code, duração medida, casos únicos por `suite.path :: test.name`, aprovados, falhos, ignorados, timeout, não executados e desconhecidos. Não reutilizar percentuais históricos como resultado atual.

## Skips conhecidos e reconciliação

O censo R07 final informado pelo C0 é `6.727 aprovados, 33 falhos, 11 ignorados`. Os 11 ignorados devem aparecer individualmente no JSON final, com `testID`, `suiteID`, caminho, nome e `skipReason`; não criar allowlist nova. O conjunto histórico de 11 é apenas referência de reconciliação, não autorização para esconder novos skips. Qualquer diferença deve ser explicada por caso, não absorvida em total agregado.

## Estimativa medida

A estimativa operacional deve ser calculada somente depois de ler os timestamps `start`/`testDone` do JSONL R07 e dos ciclos disponíveis, usando duração observada do runner e uma margem explícita para inicialização. Relatar `p50`, `p95`, máximo por unidade e soma serial; não usar faixa fixa nem contar testes como substituto de tempo. O planejamento reserva uma janela de fechamento de até quatro horas conforme o protocolo, mas a previsão publicada deve usar os tempos efetivamente medidos nos logs R07.

## Critério de fechamento

C0 recebe o JSON bruto, o relatório derivado, o exit code nativo e o recibo com SHA da base integrada. Sem esse pacote, não declarar censo completo, promoção FE/BE/E2E ou encerramento de G8.
