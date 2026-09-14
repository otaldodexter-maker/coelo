---
title: "Etapa 2 — índice das rodadas R01–R14"
source: "ETAPA-2-estado-atual.md; R01–R13 fechamentos, planos e pendências; R14-catalogo.md; AGENTS.md"
status: "active index; R13 vigente; R01–R12 históricos"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
---

# Etapa 2 — índice das rodadas

Este índice separa a fila operacional das fontes históricas. A fila vigente é
a R13, em [`ETAPA-2-estado-atual.md`](../ETAPA-2-estado-atual.md), reunindo os
50 Owner items `owner.r12-*` e H02–H28 incorporados de R01–R07. R01–R12
continuam como fontes de proveniência; nenhum item é duplicado ou renumerado.
R14 não foi iniciada.

| Rodada | Estado documental | Uso atual | Fonte principal |
|---|---|---|---|
| R01 | encerrada, parcial | origem dos resíduos noturna/R01 e H01–H28 | `reports/R01-fechamento-20260909.md` |
| R02 | encerrada, parcial | origem de H08 e reconciliações R01/R02 | `R02-distribuicao-e-fechamento.md` |
| R03 | encerrada, parcial | histórico de integração e gates | `R03-fase0-handoff.md` |
| R04 | encerrada, parcial | histórico de Auth, Operações e gates G4/G5 | `R04-perguntas-ao-owner-20260911.md` |
| R05 | encerrada, parcial | histórico de correções e pendências | `R05-fechamento.md` |
| R06 | encerrada, parcial | origem de H09, H14–H20 e decisões de segurança | `R06-fechamento.md` |
| R07 | encerrada, parcial | origem histórica de H02–H28 | `R07-fechamento.md` e `R07-varredura-r01-r07.md` |
| R08 | histórica, fora da fila vigente | preservar provas/limites; não reabrir | `R08-fechamento.md` e `R08-backlog.md` |
| R09 | histórica, fora da fila vigente | preservar fechamento e revisão 118 | `R09-fechamento.md` e `R09-pendencias.md` |
| R10 | histórica, fora da fila vigente | preservar fechamento e métricas da época | `R10-fechamento.md` e `R10-estado-por-tela.md` |
| R11 | histórica, fora da fila vigente | preservar herança e transferência | `R11-fechamento.md` e `R11-pendencias.md` |
| R12 | histórica, origem dos 53 Owner IDs | os 3 concluídos não voltam; 50 foram para R13 | `R12-fechamento.md`, `R12-pendencias.md`, `R12-owner-items.json` |
| R13 | vigente, execução parcial | 50 IDs + H02–H28; sem novo aceite terminal | `R13-fechamento.md`, `R13-pendencias.md`, `R13-owner-items-atual.json` |
| R14 | preparada, não iniciada | não executar automaticamente | `R14-catalogo.md` e `R14-plano-de-rodada.md` |

## Regra de reconciliação

- Os textos de R08–R12 podem conter percentuais e filas da época. Eles não
  substituem o inventário atual nem a fila vigente R13.
- O inventário atual é a referência dos estados por `action_id`; os três
  rastreadores devem permanecer sincronizados com ele.
- O catálogo R12/R13 conserva os IDs `owner.r12-*`, inclusive os 50
  abertos/parciais e as exclusões `owner.r12-07`, `owner.r12-41` e
  `owner.r12-43`. Os 50 e H02–H28 agora pertencem à fila R13, sem novo
  action_id.
- Nenhuma rodada é reaberta pela leitura de um arquivo histórico. Um novo
  trabalho exige abertura explícita, recorte e primeiro gate documentados.

## Navegação rápida

- [Estado atual da Etapa 2](../ETAPA-2-estado-atual.md)
- [R07 fechamento](R07-fechamento.md)
- [R07 varredura R01–R07](R07-varredura-r01-r07.md)
- [R12 pendências — origem histórica](R12-pendencias.md)
- [R13 pendências — fila vigente](R13-pendencias.md)
- [R13 projeção vigente](R13-projecao-atual.md)
- [R13 fechamento do corte](R13-fechamento.md)
