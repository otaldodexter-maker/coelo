---
title: "Etapa 2 — índice das rodadas R01–R14"
source: "ETAPA-2-estado-atual.md; R01–R13 fechamentos, planos e pendências; R14-catalogo.md; AGENTS.md"
status: "active index; R01–R07 residual source; R08–R13 historical"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
---

# Etapa 2 — índice das rodadas

Este índice separa a fila operacional dos registros históricos. A fila vigente
é [`ETAPA-2-estado-atual.md`](../ETAPA-2-estado-atual.md) e usa somente os
resíduos R01–R07 H02–H28. R08–R13 não são reabertas nem reutilizadas para
alterar essa fila; seus arquivos continuam como fonte histórica e de
proveniência. R14 não foi iniciada.

| Rodada | Estado documental | Uso atual | Fonte principal |
|---|---|---|---|
| R01 | encerrada, parcial | origem dos resíduos noturna/R01 e H01–H28 | `reports/R01-fechamento-20260909.md` |
| R02 | encerrada, parcial | origem de H08 e reconciliações R01/R02 | `R02-distribuicao-e-fechamento.md` |
| R03 | encerrada, parcial | histórico de integração e gates | `R03-fase0-handoff.md` |
| R04 | encerrada, parcial | histórico de Auth, Operações e gates G4/G5 | `R04-perguntas-ao-owner-20260911.md` |
| R05 | encerrada, parcial | histórico de correções e pendências | `R05-fechamento.md` |
| R06 | encerrada, parcial | origem de H09, H14–H20 e decisões de segurança | `R06-fechamento.md` |
| R07 | encerrada, parcial | última fonte da fila residual operacional | `R07-fechamento.md` e `R07-varredura-r01-r07.md` |
| R08 | histórica, fora da fila atual | preservar provas/limites; não reabrir | `R08-fechamento.md` e `R08-backlog.md` |
| R09 | histórica, fora da fila atual | preservar fechamento e revisão 118 | `R09-fechamento.md` e `R09-pendencias.md` |
| R10 | histórica, fora da fila atual | preservar fechamento e métricas da época | `R10-fechamento.md` e `R10-estado-por-tela.md` |
| R11 | histórica, fora da fila atual | preservar herança e transferência | `R11-fechamento.md` e `R11-pendencias.md` |
| R12 | histórica, origem dos 53 Owner IDs | os 3 concluídos não voltam; 50 ficam preservados | `R12-fechamento.md`, `R12-pendencias.md`, `R12-owner-items.json` |
| R13 | histórica, execução parcial | 50 IDs preservados; sem novo aceite terminal | `R13-fechamento.md`, `R13-pendencias.md`, `R13-owner-items-atual.json` |
| R14 | preparada, não iniciada | não executar automaticamente | `R14-catalogo.md` e `R14-plano-de-rodada.md` |

## Regra de reconciliação

- Os textos de R08–R13 podem conter percentuais e filas da época. Eles não
  substituem o inventário atual nem a fila residual R01–R07.
- O inventário atual é a referência dos estados por `action_id`; os três
  rastreadores devem permanecer sincronizados com ele.
- O catálogo R12/R13 conserva os IDs `owner.r12-*`, inclusive os 50
  abertos/parciais e as exclusões `owner.r12-07`, `owner.r12-41` e
  `owner.r12-43`. Preservar não significa adicioná-los à fila H atual.
- Nenhuma rodada é reaberta pela leitura de um arquivo histórico. Um novo
  trabalho exige abertura explícita, recorte e primeiro gate documentados.

## Navegação rápida

- [Estado atual da Etapa 2](../ETAPA-2-estado-atual.md)
- [R07 fechamento](R07-fechamento.md)
- [R07 varredura R01–R07](R07-varredura-r01-r07.md)
- [R12 pendências — origem histórica](R12-pendencias.md)
- [R13 projeção — origem histórica](R13-projecao-atual.md)
- [R13 fechamento — origem histórica](R13-fechamento.md)
