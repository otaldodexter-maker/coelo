---
title: "R08 G8 — interseção exata por caminho e nome"
source: "matriz-exata.js; JSONL C0 e log anônimo final"
status: "resultado observacional; sem execução Flutter"
generated_at: "2026-09-12T16:30:05Z"
---

# Resultado reproduzível

Comando: `node docs/reviews/evidence/etapa-2/r08-suites/matriz-exata.js`.

Chave exata: caminho normalizado + nome completo do teste. O script não cria ID
semântico e não soma reruns.

| Pacote | Eventos observados | Chaves únicas | Duplicatas por chave |
|---|---:|---:|---:|
| ciclo 30 | 245 | 245 | 0 |
| ciclo 60 | 476 | 476 | 0 |
| ciclo 90 | 820 | 820 | 0 |
| anônimo | 293 | 281 | 12 |

Interseções exatas observadas:

- ciclo 30 ∩ ciclo 60: 0
- ciclo 30 ∩ ciclo 90: 0
- ciclo 30 ∩ anônimo: 0
- ciclo 60 ∩ ciclo 90: 224
- ciclo 60 ∩ anônimo: 0
- ciclo 90 ∩ anônimo: 0

As 224 interseções são sintáticas. O JSONL contém tanto caminhos absolutos de
arquivo quanto `package:flutter_test/src/widget_tester.dart`; portanto a
interseção não é declarada como equivalência semântica de execução. O log
anônimo teve 12 nomes repetidos sob a chave exata; por isso preserva-se o valor
observado 293 e reportam-se 281 chaves únicas.

Linhas desconhecidas: zero em todos os quatro pacotes. Resultado bruto:
`matriz-exata-result.json`.

## Correção do gate de extração

O parser foi corrigido para contar somente `testDone` de casos não `hidden`, não `skipped` e não `loading`, ligados por `testStart.test.id -> testDone.testID`. Resultado: ciclo30 `121`, ciclo60 `238`, ciclo90 `422`; os totais brutos de `testStart/testDone` eram `131/131`, `249/249` e `433/433`, explicando por que a leitura anterior produzia `245/476/820` ao misturar eventos.

No log anônimo, `loading <path>` é apenas marcador de arquivo e não caso. Há `292` linhas de casos concluídos, `280` chaves exatas e `12` duplicações; o rodapé `+293: All tests passed!` é o prefixo final do runner e permanece documentado como total declarado `293`, não como caso adicional. O parser não usa `package:flutter_test/src/widget_tester.dart` como suite.

Interseção exata após a correção: ciclo30∩ciclo60 `0`, ciclo30∩ciclo90 `0`, ciclo60∩ciclo90 `112`; pares com anônimo `0`. O JSON inclui a decomposição completa em `diagnostics`.

## Reconciliação do prefixo anônimo

A inspeção por prefixo completo encontrou `300` linhas de progresso: os seis marcadores `loading <path>` são descartados; os casos efetivos percorrem continuamente `+0` até `+292`, sem salto. O rodapé `+293: All tests passed!` declara o total final do runner, mas não contém arquivo/nome e não é uma execução adicional identificável.

As 12 ocorrências duplicadas (diferença entre 293 casos e 281 chaves) ficam em quatro chaves: `rejects malformed URL without exposing it` nos prefixos `28..33` (6 ocorrências, 5 duplicações); `rejects invalid expiry or TTL over 300 seconds` em `34..38` (5, 4 duplicações); `expired receipt keeps the safe expired exception` em `39..40` (2, 1 duplicação); `backend failure is sanitized without implicit retry` em `43..45` (3, 2 duplicações). Todas pertencem a `forms_media_reader_test.dart`; o caminho completo e o nome completo permanecem na saída do parser.

