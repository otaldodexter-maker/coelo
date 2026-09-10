---
title: "Handoff final — grupo estrutura, Rodada 3"
source: "worktree e2-r03-estrutura, branch work/etapa2-r03-estrutura"
status: "entregue ao coordenador coelo-af"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Handoff — grupo estrutura

**Base:** `origin/dev 347d4cf8a`, já com a baseline de produção e os lotes 1 e 2
aplicados. Árvore limpa, sem WIP não commitado.

## Feito

**Fila SQL.** Os três pacotes de Locais foram reemitidos sobre a baseline com
carimbos `20260910180000`, `180100` e `180200`.

**Locais, decisão do Owner implementada.** A bolinha de status foi para a linha
do nome, como no card de Instituições. O tipo do local deixou de ser uma linha no
corpo do card e virou título de grupo — "Locais internos da instituição" (ou da
unidade) e "Locais externos" — com o card Criar do composto abrindo cada grupo e
já definindo o tipo do que será criado. O botão "Novo local" do cabeçalho saiu, e
o card Criar passou a existir também em vazio e em sem resultados, para nenhum
estado ficar sem forma de criar. Nada de conceito novo:
`LocationKind{internal,external}` e `LocationScope` já existiam no domínio.

**Composição.** `SupabaseUnitDirectoryRepository` e
`SupabaseGroupDirectoryRepository` entraram no lugar dos `Unavailable*`.

**Antes, nesta rodada:** defeito da confirmação de saída de Instituições com
prova causal, guardas assíncronas em Unidades e na assinatura, exportação de
Unidades honesta, fail-closed das rotas de mutação provado nos dois sentidos,
decisão RODAPÉ e regra do chat aplicadas e gravadas nas skills.

## Pendências e o primeiro gate de cada uma

| Pendência | Primeiro gate |
| --- | --- |
| Aplicar os três pacotes de Locais | **Bloqueado:** faltam seis pacotes da cadeia histórica em produção. Lista ordenada em `producao-nao-tem-a-cadeia-v2.md`. Decisão de fila, do coordenador |
| `institutions.*` e `activities.*` na rota normal | **Bloqueado:** as oito RPCs internas v2 das duas famílias não existem em produção |
| Detalhe de Unidade e de Turma | `superadmin_unit_detail_v2` e `superadmin_group_detail_v2` ausentes em produção |
| Cards das unidades na tela de Locais da instituição | Depende do diretório de Unidades, que só agora saiu de `Unavailable` |
| `structureMutationsEnabled` | Proposta de separar por realm em `proposta-separar-chave-de-estrutura.md`, ainda sem decisão |
| 16 goldens de formulário | Esperando a Fase 0 fechar MENU e MENU-M, para uma passada única |
| 30 goldens órfãos de Locais | Decidir remoção; não removi por ser irreversível na prática |

## Testes

- **pgTAP sobre a baseline:** os três pacotes **não passam**, e a causa é
  dependência ausente em produção, não defeito deles. Antes da baseline eles
  eram 109 asserções PASS sobre a cadeia antiga.
- **Flutter:** 448 PASS em `test/features/locations`; 1341 PASS nas seis famílias
  mais `test/architecture` na medição anterior; `analyze` limpo.
- **`test/app` mais Unidades e Turmas:** 939 PASS, 16 FAIL. As dezesseis são
  **preexistentes**, não da composição: nenhum dos arquivos que falham
  referencia `unitDirectoryRepository`, `groupDirectoryRepository` ou
  `createSuperadminAuthScope`, e revertendo o meu hunk de composição para
  `347d4cf8a` os mesmos casos continuam falhando. São de dev_menu, dataset de
  desenvolvimento, rotas de import de desenvolvimento, shell persistente,
  detalhe de pessoa, Principal real, navegação de protótipo, detalhe de
  Estrutura e páginas de erro.
- **Vermelhos conhecidos meus:** 3 goldens de detalhe de Locais, que já falhavam
  antes das minhas mudanças (medido por baseline com stash), e os 16 goldens de
  formulário que esperam MENU/MENU-M.

## WIP não commitado

Nenhum.
