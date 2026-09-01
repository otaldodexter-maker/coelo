---
title: "Consolidação física do workspace — Etapa 2"
source: "Auditoria local read-only; inventário de recoveries; Git worktree list"
status: "archives-preserved; git-consolidated; one-empty-os-locked-directory"
generated_at: "2026-09-01"
updated_at: "2026-09-01"
---

# Consolidação física do workspace — Etapa 2

## Resultado das pastas externas

As três pastas de recovery foram movidas integralmente, sem deduplicação ou
remoção de conteúdo, para `C:\Users\adrie\Documents\Coelo\.recovery-archives`.
O diretório é ignorado pelo Git. A pasta externa `Coelo-worktrees` foi removida
somente depois de duas auditorias confirmarem zero itens, inclusive ocultos.

| Arquivo preservado | Arquivos | Bytes | Bundles | Patches | Verificação |
| --- | ---: | ---: | ---: | ---: | --- |
| `Coelo-recovery-20260825-final` | 3.314 | 3.669.319.224 | 11 | 59 | Contagem/tamanho iguais; bundles válidos. |
| `Coelo-recovery-20260827-143631-final-hygiene` | 199 | 128.029.958 | 1 | 8 | Contagem/tamanho iguais; bundle válido. |
| `Coelo-recovery-20260827-153001-final-residue` | 564 | 803.713.252 | 3 | 8 | Contagem/tamanho iguais; bundles válidos. |

Os 15 bundles passaram em `git bundle verify`. A movimentação ocorreu no mesmo
volume e as contagens e somas de bytes antes/depois foram idênticas.

Quatro arquivos não rastreados de `form-export-download`, encontrados na
worktree Comunicação mas pertencentes semanticamente à pendência de Formulários,
foram movidos sem alteração de hash para
`.recovery-archives/etapa-2-handoffs/communication-untracked-form-export-download`.
Eles não foram promovidos nem integrados como funcionalidade concluída.

## Por que os arquivos não foram apagados

A auditoria encontrou material ainda não alcançável pelo `dev`: 33 versões SQL,
seis arquivos Dart, 11 documentos históricos e 76 tips preservadas somente nos
bundles. Também existe um clone Git aninhado limpo. Por isso, limpeza e
deduplicação ficam bloqueadas até reconciliação explícita desses artefatos.

## Worktrees Git

Os seis HEADs recebidos (`1915f847`, `2b70c435`, `b191b727`, `0fe90573`,
`a921d174` e `f3ae2a2a`) foram comprovados como ancestrais do consolidado. O
histórico foi promovido por fast-forward para `dev`; as seis worktrees foram
retiradas do registro Git, podadas, e as branches temporárias foram excluídas
somente depois dessa prova. `git worktree list` termina com uma única entrada:
`C:\Users\adrie\Documents\Coelo` em `dev`.

Um processo antigo do ambiente Windows manteve aberto o diretório
`.worktrees\finalizacao-telas-operacoes\apps\superadmin` durante a remoção.
Todo o conteúdo foi movido para
`.recovery-archives\retired-worktree-residues\finalizacao-telas-operacoes`;
o caminho antigo contém **zero arquivos** e apenas dois diretórios vazios. Ele
não é worktree, não contém commit ou mudança e pode ser apagado depois que o
handle do aplicativo for liberado.

## Proteção pós-consolidação

- Bundle completo:
  `.recovery-archives\etapa-2-postconsolidation-20260901.bundle`.
- Tamanho: 351.863.257 bytes.
- SHA-256:
  `9F393E843366F15BA815BA0CD5141030964B349D1C4DD4F9F395AEE830D52DEF`.
- `git bundle verify`: válido, 356 refs e histórico completo.
- As refs `refs/backup/pre-consolidation-20260901/*` preservam nominalmente os
  seis HEADs anteriores à limpeza.

## Verificação do consolidado

- `flutter analyze --no-fatal-infos`: sem achados.
- Chat e Circulares: 18/18 testes focados.
- Rotas do menu Coelo (Principal): 17/17 testes focados.
- Harness seguro de replay: 13/13 Pester.
- Chat do Coelo (Principal): botão “Mensagens” ligado à mesma rota em prévia e
  produção, com retorno à origem correta.
- Nenhum arquivo de `apps/admin`, `apps/site` ou `apps/principal` foi alterado
  pelo recorte consolidado.
