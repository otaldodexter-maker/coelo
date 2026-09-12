---
title: Composto de diretório administrativo (CoeloAdminDirectory)
knowledge_id: coelo-admin-directory-composite
source: docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md
status: validated
generated_at: 2026-09-10
updated_at: 2026-09-12
audience: team
surfaces:
  - superadmin
  - admin
visibility: internal
review_owner: Coelo Owner
---

# Composto de diretório administrativo

Decisão do Owner em 10/09/2026: o conceito de família de diretório (cabeçalho
com Pesquisar e Bug, menu, toolbar, abas de estado, toggle Cards/Tabela, grade
com o card Criar primeiro, tabela, paginação e comportamento em 375/768/1024/
1440) vive uma única vez e as telas o consomem.

## Onde vive

- `CoeloAdminDirectory<TView>` em `packages/coelo_ui_admin`, com goldens por
  largura e tema no próprio pacote.
- Cabeçalho, menu e balão de chat vivem no shell do Superadmin
  (`apps/superadmin/lib/app/shell`): o botão de Bug nunca é omitido e o campo
  Pesquisar do menu é mantido.

## O que a tela entrega

Só conteúdo de domínio: campo de busca, filtros, cards, linhas da tabela
(`*Rows`), textos de estado, ações de arquivo e paginação. A tela não declara
Table, Toolbar, Pagination, Header ou Directory próprios; um teste de
arquitetura em `apps/superadmin/test/architecture` falha quando isso acontece
e mantém uma allowlist que só diminui.

## Regras visuais incorporadas

- Card Criar aparece primeiro na grade, inclusive nos estados vazio e de
  falha; em tabela vira banner acima do conteúdo. Sem callback, fica visível e
  desabilitado.
- Grade de 340 px com cards da mesma altura por linha; card mínimo de 216 px.
- Rodapé de paginação fixo, compacto abaixo de 600 px (setas com rótulo).
- Arquivos é configuração: a tela passa a lista de ações ou `null` para
  esconder o botão (Conversas).
- Estado com linha principal e linha secundária opcional (mensagem do serviço
  ou orientação), com Tentar novamente ou Limpar filtros.
- Na tabela, alça e ordenação têm alvos separados; a pintura do cabeçalho
  preserva a composição aprovada. Colunas fixas não oferecem alça sem efeito.
  A faixa de 48 px da alça não certifica o alvo de ordenação em colunas estreitas.
  Regra complementar: [Design System, seção 17.1](../../design/design-system.md#171-tabelas).

## Diretórios já migrados (10/09/2026)

Instituições, Atividades (Atividades e Modelos), Turmas, Unidades,
Formulários, Perfis de cuidado, Planos de medicação, Planos, Cardápios,
Circulares, Comunicações, Pessoas, Convites e Perfis de acesso. Suporte e
Auditoria são workspaces com painel de detalhe e seguem com toolbar própria na
allowlist até o grupo responsável alinhá-la ao composto.
