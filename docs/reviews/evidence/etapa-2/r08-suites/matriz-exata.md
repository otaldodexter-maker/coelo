---
title: R08 G8 matriz exata atual
fonte: ciclos JSONL 30/60/90 e log anonimo final
status: atual; sem execucao Flutter
updated_at: 2026-09-12
---

# Matriz exata atual

O parser usa `testStart.test.id -> testDone.testID`, `suite.id -> suite.path`, loader por igualdade estrutural entre `loading <suite.path>` e caminho canonicalizado, e caminhos relativos `apps/superadmin/...`. Não conta `testStart`, `print` ou `allSuites` como casos.

| Fonte | observedEvents | uniqueDisplayKeys | displayKeyCollisions |
| --- | ---: | ---: | ---: |
| ciclo30 | 121 | 121 | 0 |
| ciclo60 | 238 | 238 | 0 |
| ciclo90 | 422 | 410 | 12 |
| anonimo293 | 293 | 281 | 12 |

Diagnóstico dos ciclos: ciclo30 `testStart=131`, `testDone=131`, `loaderMatched=10`; ciclo60 `249/249/11`; ciclo90 `433/433/11`. Os casos efetivos são somente `testDone` não hidden, não skipped e não loader. O log anônimo contém 293 eventos observados, 281 chaves de exibição distintas e 12 colisões; isso não significa 281 casos.

Interseções de chaves canonicalizadas: ciclo30∩ciclo60 `0`, ciclo30∩ciclo90 `0`, ciclo30∩anonimo `0`, ciclo60∩ciclo90 `112`, ciclo60∩anonimo `0`, ciclo90∩anonimo `221`.

O resultado bruto está em `matriz-exata-result.json`; o script é `matriz-exata.js`. Este artefato é reconciliação textual de logs e não promove cobertura FE/BE/E2E.
