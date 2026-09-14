---
source: R12-pendencias.md; R12-owner-items.json; inventario-etapa-2.json
status: R13 em abertura operacional; execução ainda não iniciada
generated_at: 2026-09-14
---

# R13 — Projeção operacional atual

A R13 recebe os 50 compromissos ainda não `done` da R12, preservando os IDs
`owner.r12-*`. Os itens 07, 41 e 43 ficam fora da fila por já estarem
concluídos. A fonte atual por item é `R12-pendencias.md`/`R12-owner-items.json`;
os arquivos R13 antigos permanecem como histórico de origem.

## Avanço atual

Base: 231 action IDs únicos, revisão em 2026-09-14, checkout `dev`, commit
`4ca959d9b6d9552735da6b9d5ae3ca82a4ce76c9`.

| Métrica | Concluídos | Base | Percentual |
|---|---:|---:|---:|
| Front-end verificado | 151 | 231 | 65,4% |
| Back-end concluído/verificado | 159 | 231 | 68,8% |
| Integrado E2E/flutter-only | 132 | 231 | 57,1% |
| Front-end local-green | 37 | 231 | 16,0% |
| Owner items done | 3 | 53 | 5,7% |
| Owner items abertos/parciais | 50 | 53 | 94,3% |

Não somar camadas nem usar item de Owner como denominador de action ID.
Validação estrutural não certifica runtime. A R13 só pode ser completa após
fechar os gates e repetir o delivery gate com evidência real.

## Ordem operacional

1. R12-51: confirmar PITR, backup e ordem serial.
2. R12-48–50: aplicar candidatos SQL aprovados e provar persistência, reload e isolamento.
3. R12-38/R12-46: Media Gateway/R2 privado e contrato de mídia.
4. R12-47/R12-45: SMTP, redirect e entrega real.
5. R12-01–06, R12-08–40, R12-42, R12-44 e R12-52: concluir provas conforme cada gate.
6. R12-53 somente após sua condição formal; não abrir macrotema novo.

Bloqueios externos permanecem pendências, não percentuais inventados.
