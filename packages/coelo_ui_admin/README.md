---
source: "specs/013-ui-packages-componentization.md"
status: "implemented-package"
generated_at: "2026-07-27"
---

# coelo_ui_admin

Componentes Flutter densos compartilhados por Admin e Superadmin: tabelas,
filtros, toolbars, importacao, formularios, dashboards, paginacao e operacoes.

## Regra

Promover para este pacote quando for um padrao administrativo aprovado e
compartilhavel entre Admin e Superadmin. Segundo uso real continua obrigatorio
para abstracoes experimentais ou especulativas, nao para padroes oficiais ja
validados.

## Status

Pacote materializado a partir dos padroes visuais aprovados da tela de
instituicoes. Busca, status, toolbar e paginacao ja comprovaram equivalencia
visual na Task 7. A mecanica generica da tabela tambem foi promovida com
tolerancia visual zero; celulas, status, copia, mensagens e modelos de
instituicoes continuam locais. Composicoes de estado, filtros de dominio e
cards permanecem locais enquanto seus contratos nao preservarem os goldens
existentes.

Na implementacao atual da tabela, a coluna fixa e uma copia visual excluida de
ponteiro e semantica para preservar o baseline aprovado. Seu `cellBuilder` deve
ser puramente visual, sem acao propria, `GlobalKey`, efeito colateral ou arvore
pesada. Uma coluna fixa interativa exige redesenho e nova validacao de foco,
semantica, hover e goldens antes de virar contrato publico.

Contratos publicos iniciais:

- `CoeloAdminListingToolbar`;
- `CoeloAdminMultiSelectFilter<T>`;
- `CoeloAdminMultiSelectField<T>`;
- `CoeloAdminPagination`;
- `CoeloAdminCreateAction`;
- `CoeloAdminTableColumn<T>`;
- `CoeloAdminResizableTable<T>`.
