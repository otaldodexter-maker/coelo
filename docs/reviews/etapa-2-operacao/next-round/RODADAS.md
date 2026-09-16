---
title: "Etapa 2 — índice das rodadas R01–R15"
source: "ETAPA-2-estado-atual.md; R01–R13 fechamentos, planos e pendências; R14-catalogo.md; AGENTS.md"
status: "active index; R15 vigente (fila única consolidada); R01–R14 históricos"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-16"
---

# Etapa 2 — índice das rodadas

Este índice separa a fila operacional das fontes históricas. A fila vigente é
a R15, em [`R15-pendencias.md`](R15-pendencias.md), reunindo tudo o que ficou
não terminal de R01 a R14 (Owner items, H, itens da ADR 0038, ações do
inventário e resíduos operacionais). R01–R14 continuam como fontes de
proveniência; nenhum item é duplicado ou renumerado. R15 foi aberta em
16/09/2026 por decisão do Owner (ADR 0042); R14 foi encerrada e congelada.

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
| R13 | histórica (encerrada em 14/09/2026) | 9 Owner done, H06/H17/OQ-028 e anexos fechados; os não terminais foram consolidados na R14 | `R13-checkpoint-20260914-1800.md`, `R13-pendencias.md` (congelado) |
| R14 | histórica (encerrada em 16/09/2026) | +3 E2E, OQ-046, lotes 72/73, C1, B1/B2/B3/B8 locais; não terminais consolidados na R15 | `R14-fechamento.md`, `R14-checkpoint-20260916.md`, `R14-pendencias.md` (congelado) |
| R15 | vigente — fila única consolidada | executar pela ordem de `R15-pendencias.md`; itens `done` não retornam | `R15-pendencias.md` (fonte), ADR 0042 |

## Regra de reconciliação

- Os textos de R08–R13 podem conter percentuais e filas da época. Eles não
  substituem o inventário atual nem a fila vigente R14.
- O inventário atual é a referência dos estados por `action_id`; os três
  rastreadores devem permanecer sincronizados com ele.
- O catálogo R12/R13 conserva os IDs `owner.r12-*`, inclusive os 44
  abertos/parciais e os 9 concluídos. Os não terminais e H02–H28 agora
  pertencem à fila R14, sem novo action_id.
- Nenhuma rodada é reaberta pela leitura de um arquivo histórico. Um novo
  trabalho exige abertura explícita, recorte e primeiro gate documentados.
- R15 herda todos os itens não terminais confirmados no fechamento da R14 e os
  resíduos operacionais da varredura R01–R14; `R15-pendencias.md` é a única
  fila corrente de trabalho.

## Navegação rápida

- [Estado atual da Etapa 2](../ETAPA-2-estado-atual.md)
- [R07 fechamento](R07-fechamento.md)
- [R07 varredura R01–R07](R07-varredura-r01-r07.md)
- [R12 pendências — origem histórica](R12-pendencias.md)
- [R13 pendências — histórico](R13-pendencias.md)
- [R14 pendências — histórico](R14-pendencias.md) e [R14 fechamento](R14-fechamento.md)
- [R15 fila única — vigente](R15-pendencias.md)
