---
source: R12-pendencias.md; R13-owner-items-atual.json; inventario-etapa-2.json; ETAPA-2-estado-atual.md
status: active; fila vigente R13; execução documental parcial
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# R13 — Projeção vigente e histórico do corte

A R13 recebeu documentalmente os 50 compromissos ainda não `done` da R12,
preservando os IDs `owner.r12-*`; `owner.r12-07`, `owner.r12-41` e
`owner.r12-43` ficaram fora por já estarem concluídos. A execução foi parcial,
sem novo aceite terminal. Este arquivo é a projeção vigente da fila R13 e
preserva também o histórico da transferência.

A fila operacional atual é [`ETAPA-2-estado-atual.md`](../ETAPA-2-estado-atual.md),
formada pelos 50 Owner items `owner.r12-*` e pelos resíduos H02–H28
incorporados de R01–R07. R01–R12 são fontes históricas; não se somam itens
duplicados nem se criam novos action IDs.

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

## Ordem vigente da R13

1. R12-51: confirmar PITR, backup e ordem serial.
2. R12-48–50: aplicar candidatos SQL aprovados e provar persistência, reload e isolamento.
3. R12-38/R12-46: Media Gateway/R2 privado e contrato de mídia.
4. R12-47/R12-45: SMTP, redirect e entrega real.
5. R12-01–06, R12-08–40, R12-42, R12-44 e R12-52: concluir provas conforme cada gate.
6. R12-53 somente após sua condição formal; não abrir macrotema novo.

Os bloqueios externos permanecem registrados nos MDs de camada, neste arquivo
e no `R13-owner-items-atual.json`. Eles pertencem à fila R13 e não devem ser
recontados como itens independentes ou duplicados por origem histórica.
