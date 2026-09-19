/// Tour da tela Instituições (`institutions`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const institutionsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Instituições',
  text:
      'Cada cliente do Coelo. A instituição é única e administra suas unidades.',
);

/// Passo 2 — directory.search.
const institutionsSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text:
      'Digite parte do nome para filtrar a lista na hora.',
);

/// Passo 3 — directory.filters.
const institutionsFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text:
      'Refine por plano, situação e outros critérios. "Limpar filtros" volta à lista completa.',
);

/// Passo 4 — directory.view.
const institutionsViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text:
      'Escolha ver como cards, com resumo de cada instituição, ou como tabela, com mais colunas.',
);

/// Passo 5 — directory.files.
const institutionsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Traga instituições de uma planilha ou exporte a lista atual em CSV ou XLSX.',
);

/// Passo 6 — directory.tabs.
const institutionsTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text:
      'Todos, Ativos, Em Implantação ou Inativos. A aba muda o que aparece abaixo.',
);

/// Passo 7 — directory.create.
const institutionsCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar instituição',
  text:
      'Abre o formulário de uma nova instituição. Fica sempre no início, mesmo com a lista vazia.',
);

/// Passo 8 — directory.body.
const institutionsBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Clique numa instituição para abrir seus dados, unidades e locais.',
);

/// Passo 9 — directory.pagination.
const institutionsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const institutionsScreenTour = SuperadminScreenTour(
  destinationId: 'institutions',
  steps: [
    institutionsHeaderTourStep,
    institutionsSearchTourStep,
    institutionsFiltersTourStep,
    institutionsViewTourStep,
    institutionsFilesTourStep,
    institutionsTabsTourStep,
    institutionsCreateTourStep,
    institutionsBodyTourStep,
    institutionsPaginationTourStep,
  ],
);
