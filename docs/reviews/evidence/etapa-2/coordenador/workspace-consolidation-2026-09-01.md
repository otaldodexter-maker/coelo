---
title: "Consolidação física do workspace — Etapa 2"
source: "Auditoria local read-only; inventário de recoveries; Git worktree list"
status: "archives-preserved; git-consolidation-in-progress"
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

## Por que os arquivos não foram apagados

A auditoria encontrou material ainda não alcançável pelo `dev`: 33 versões SQL,
seis arquivos Dart, 11 documentos históricos e 76 tips preservadas somente nos
bundles. Também existe um clone Git aninhado limpo. Por isso, limpeza e
deduplicação ficam bloqueadas até reconciliação explícita desses artefatos.

## Worktrees Git

As seis worktrees reais ficam em `Coelo\.worktrees`, usam o mesmo common-dir
`Coelo\.git` e não possuem registros órfãos. Elas só serão removidas depois de:

1. handoff e status limpo;
2. integração dos commits em uma branch de consolidação;
3. testes e regressão;
4. atualização dos três rastreadores oficiais;
5. prova de que cada HEAD está alcançável pelo consolidado.

