---
source: R12-pendencias.md; R13-owner-items-atual.json; inventario-etapa-2.json; ETAPA-2-estado-atual.md
status: histórico; R13 parcial; fora da fila residual operacional atual
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# R13 — Projeção preservada (histórica)

A R13 recebeu documentalmente os 50 compromissos ainda não `done` da R12,
preservando os IDs `owner.r12-*`; `owner.r12-07`, `owner.r12-41` e
`owner.r12-43` ficaram fora por já estarem concluídos. A execução foi parcial,
sem novo aceite terminal. Este arquivo permanece como origem histórica da
transferência e não é a fila vigente da Etapa 2.

A fila operacional atual é [`ETAPA-2-estado-atual.md`](../ETAPA-2-estado-atual.md),
formada somente pelos resíduos R01–R07 H02–H28. R08–R13 são preservadas como
histórico e não devem ser somadas novamente ou usadas para reabrir R12/R13.

## Percentuais canônicos na revisão atual

Base: `docs/reviews/inventario-etapa-2.json`, 231 action IDs únicos, revisão em
2026-09-14, checkout `dev`, SHA `1f34b9dbfda5f94b98edbb154ce1841059df67bf`.
BE usa 224 ações aplicáveis e E2E usa 199 ações integradas ativas.

| Métrica | Concluídos | Base | Percentual |
|---|---:|---:|---:|
| Front-end verificado | 151 | 231 | 65,37% |
| Back-end concluído/verificado | 159 | 224 | 70,98% |
| E2E verificado | 125 | 199 | 62,81% |
| E2E + flutter-only | 132 | 231 | 57,14% |
| Front-end local-green | 37 | 231 | 16,02% |
| Back-end local-green | 21 | 224 | 9,38% |
| Owner items done | 3 | 53 | 5,66% |
| Owner items abertos/parciais | 50 | 53 | 94,34% |

Não somar camadas nem usar item de Owner como denominador de action ID.
`132/231` é a métrica combinada de E2E + flutter-only; não substitui o aceite
integrado `125/199`. Validação estrutural e checks locais não certificam
runtime.

## Ordem histórica registrada

1. R12-51: confirmar PITR, backup e ordem serial.
2. R12-48–50: aplicar candidatos SQL aprovados e provar persistência, reload e isolamento.
3. R12-38/R12-46: Media Gateway/R2 privado e contrato de mídia.
4. R12-47/R12-45: SMTP, redirect e entrega real.
5. R12-01–06, R12-08–40, R12-42, R12-44 e R12-52: concluir provas conforme cada gate.
6. R12-53 somente após sua condição formal; não abrir macrotema novo.

Os bloqueios externos permanecem registrados nos MDs de camada e no
`R13-owner-items-atual.json`. Eles não são recontados como resíduos R01–R07.
