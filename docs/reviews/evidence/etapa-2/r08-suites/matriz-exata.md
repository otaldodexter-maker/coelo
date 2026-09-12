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
