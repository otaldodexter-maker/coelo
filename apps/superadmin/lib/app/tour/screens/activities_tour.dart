/// Tour da tela Atividades (`activities`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const activitiesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Atividades',
  text:
      'Aulas, oficinas e projetos vinculados a unidades e turmas.',
);

/// Passo 2 — directory.leading.
const activitiesLeadingTourStep = CoeloTourStep(
  anchorId: 'directory.leading',
  title: 'Modelos ou atividades',
  text:
      '"Modelos de atividade" são a base reutilizável; "Atividades" são as instâncias em turmas.',
);

/// Passo 3 — directory.search.
const activitiesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text:
      'Busque por nome ou descrição.',
);

/// Passo 4 — directory.filters.
const activitiesFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text:
      'Instituições, Unidades, Turmas e Origem. Em modelos: Origem e Categorias.',
);

/// Passo 5 — directory.view.
const activitiesViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text:
      'Na tabela, veja Agrupado, Por Unidades ou Por Turmas.',
);

/// Passo 6 — directory.files.
const activitiesFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Importe de planilha ou exporte em CSV ou XLSX.',
);

/// Passo 7 — directory.tabs.
const activitiesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text:
      'Todos, Ativos, Rascunhos, Inativos; modelos têm também Arquivados.',
);

/// Passo 8 — directory.create.
const activitiesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar atividade',
  text:
      'Abre o formulário. Num modelo, "Começar a partir deste modelo" já preenche a atividade.',
);

/// Passo 9 — directory.body.
const activitiesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Abra uma atividade para ver turmas, configuração avaliativa e lançamentos.',
);

/// Passo 10 — directory.pagination.
const activitiesPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const activitiesScreenTour = SuperadminScreenTour(
  destinationId: 'activities',
  steps: [
    activitiesHeaderTourStep,
    activitiesLeadingTourStep,
    activitiesSearchTourStep,
    activitiesFiltersTourStep,
    activitiesViewTourStep,
    activitiesFilesTourStep,
    activitiesTabsTourStep,
    activitiesCreateTourStep,
    activitiesBodyTourStep,
    activitiesPaginationTourStep,
  ],
);
