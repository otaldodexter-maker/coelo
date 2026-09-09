---
title: "Consolidação do repositório e das skills"
source: "Pedido do Owner de 2026-09-09; Git local/origin; backup verificado; fechamento R01"
status: "consolidação local verificada; publicação em preparação"
generated_at: "2026-09-09"
---

# Consolidação do repositório e das skills

A branch Git `dev` é a base compartilhada de código e instruções do Coelo.
Não é um ambiente de testes. As skills orientam o agente também na entrega do
app real e na implantação autorizada; os recursos remotos continuam produção.

## O que foi consolidado

- O checkout principal recebeu por fast-forward os 235 commits que já estavam
  em `origin/dev`, chegando à base `ed37c04d`. Preservadas as alterações locais
  antes da atualização; deltas já integrados não foram reaplicados.
- Foram reaplicadas as melhorias de skills/referências, os ajustes locais de
  Tutor/learning já aprovados e o validador documental. O Design System e os
  rastreadores atuais prevaleceram sobre cópias locais antigas.
- As duas certificações FE já existentes receberam metadados da evidência
  nominal de 08/09. Nenhuma ação mudou de estado. O validador agora reconhece
  a matriz vigente, separando-a de tabelas de testes e históricos.
- Uma worktree Git permanece: `C:/Users/adrie/Documents/Coelo`. As nove antigas
  foram retiradas de operação, preservando diretórios e evidências. As branches
  locais ativas são `dev` e `main`; o stash antigo foi arquivado.

## Preservação e candidatos retidos

Os 17 heads de branches encerradas possuem tags `archive/2026-09-09/...`;
o stash e o checkout detached também têm referências nominais. As 48 pontas
de commits sem referência encontradas pelo Git foram protegidas em
`refs/archive/2026-09-09/recovery/`, somente no arquivo local de recuperação.

O [manifesto nominal](evidence/2026-09-09-skill-maintenance/git-consolidation.json)
registra SHAs, referências e destinos. O backup local completo está em
`C:/Users/adrie/Documents/Coelo.preserved/skills-consolidation-20260909/`:

- `repository-before-consolidation.bundle`: verificado pelo Git, com o histórico;
- `root-local/` e patches: alterações anteriores do checkout principal;
- `retired-checkouts/`: arquivos das nove worktrees, inclusive evidências ignoradas;
- `archive-refs.json` e `retired-checkouts.json`: identificação para recuperação.

Uma pasta vazia de C07 ficou presa por um processo existente; não contém
arquivos nem metadados Git e não é uma worktree. Nenhum processo alheio foi
encerrado para removê-la. Os arquivos dessa origem estão no arquivo preservado.

**Arquivado não significa integrado.** A fila de candidatos/WIP retidos continua
no [fechamento R01](etapa-2-operacao/reports/R01-fechamento-20260909.md) e seus
manifestos. Nenhum merge de ancestralidade foi usado para fingir incorporação.
O trabalho não integrado precisa da revisão/correção indicada antes de entrar
no app. Esses commits têm origem e destino de recuperação, não ficam soltos.

## Regras para a próxima execução

Retomar pelo [índice da Etapa 2](coelo-etapa-2-coordenacao.md), no checkout
consolidado. Corrigir os pontos que o Owner marcou nos anexos e sua integração.
Usar a mesma base na implementação e validação; registrar o aceite e as falhas
resolvidas/novas. Testes verdes só se repetem por motivo material ou gate exigido.

Entrega que inclui integração/publicação também confere commit, push, arquivos
locais, stash e divergência remota. As skills/referências entram no mesmo fluxo.
Criar outra worktree somente quando houver necessidade de isolamento, com
destino e responsável de integração. Conversas/ordens R01 permanecem históricas.

## Validação e publicação

O estado remoto será registrado após o push verificado. A igualdade de `dev`
e `origin/dev` é conferida por SHA e contagem ahead/behind; existência de commit
local não é publicação. Esta manutenção não implanta o app nem certifica E2E.
