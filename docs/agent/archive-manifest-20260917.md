---
title: "Manifesto de arquivamento de documentação (17/09/2026)"
source: "Owner em 2026-09-17 (aprovação dos lotes L1–L8 na sessão coordenadora da R16); docs/agent/archive-manifest-20260917.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# Manifesto de arquivamento (17/09/2026)

Arrumação aprovada pelo Owner após o fechamento FE/BE/E2E da Etapa 2. Nada foi apagado do
histórico Git: arquivos rastreados foram movidos com `git mv` (histórico preservado); o que
não era rastreado foi movido para `Coelo-backups` (fora do repositório). Referências em fontes
vivas foram reescritas para os novos caminhos. Detalhe por arquivo em
`archive-manifest-20260917.json` (158 entradas).

| Lote | O que | Destino |
|---|---|---|
| L1 | 92 patches/logs soltos na raiz (não rastreados) | `Coelo-backups/root-scratch-20260917/` |
| L2 | `__pycache__`; `.recovery-archives/` (5,4 GB, ignorado) | apagado; `Coelo-backups/recovery-archives-20260825/` |
| L3 | `next-round/`: R01–R11 completas e handoffs/prompts/perguntas/históricos de R12–R15 (123 arquivos) | `docs/reviews/archive/rounds/R01…R15/` |
| L4 | `etapa-2-operacao/{noturna,reports,comunicacao,assignments,handoffs,evidence,TRABALHO-ATUAL,PROTOCOLO,scripts R01}` | `docs/reviews/archive/etapa-2-r01-r02/` |
| L5 | `docs/reviews/*.md` datados jul–set e deltas antigos; `docs/superpowers`, `docs/contexts`, `docs/handoffs`, `docs/spikes`, `spikes/`, `.superpowers/` | `docs/reviews/archive/reviews-2026/`; `docs/archive/{superpowers,contexts,handoffs,spikes,spikes-root,dot-superpowers}/` |
| L6 | `specs/` e `decisions/`: `lifecycle` normalizado e índices reescritos (sem mover) | — |
| L7 | `AGENTS.md`, `CLAUDE.md`, `docs/agent/*` reescritos para o estado de 17/09 | — |

## O que ficou em `next-round/` (fontes vivas)

`R16-*` (fila, prompts, execução, handoffs, checkpoint), `RODADAS.md`, `README.md`, fechamentos e
checkpoints finais de R12–R15, pendências congeladas R12–R15, `R12-owner-items.json` e
`sync-r12-owner-records.cjs` (fonte/sync dos Owner items), `R13-owner-items-atual.json`,
`R13-prompt-execucao-20260914.md`, `R14-catalogo.md`, `R14/R15-execucao-paralela.md` (modelos) e
`R07-decisoes-owner-20260912.md` (decisões do Owner citadas por ADR).

## Recuperação

`git log --follow <novo caminho>` mostra o histórico; `git mv` reverso restaura o caminho antigo.
Os itens fora do Git voltam por cópia de `Coelo-backups`.
