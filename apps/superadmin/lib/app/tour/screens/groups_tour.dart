/// Tour da tela Turmas (`groups`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const groupsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Turmas',
  text: 'Os grupos de crianças ou alunos dentro de cada unidade, com seus educadores.',
);

/// Passo 2 — directory.search.
const groupsSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text: 'Encontre uma turma pelo nome.',
);

/// Passo 3 — directory.filters.
const groupsFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Instituições, Unidades e Tipo da turma. "Limpar filtros" volta ao início.',
);

/// Passo 4 — directory.view.
const groupsViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text:
      'Cards mostram unidade, tipo, alunos, atividades e professores; a tabela agrupa por unidade.',
);

/// Passo 5 — directory.files.
const groupsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe turmas de uma planilha ou exporte em CSV ou XLSX.',
);

/// Passo 6 — directory.tabs.
const groupsTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text: 'Filtre pela situação da turma.',
);

/// Passo 7 — directory.create.
const groupsCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar turma',
  text: 'Abre o formulário de uma nova turma.',
);

/// Passo 8 — directory.body.
const groupsBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Abra uma turma para ver alunos, atividades e professores.',
);

/// Passo 9 — directory.pagination.
const groupsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const groupsScreenTour = SuperadminScreenTour(
  destinationId: 'groups',
  steps: [
    groupsHeaderTourStep,
    groupsSearchTourStep,
    groupsFiltersTourStep,
    groupsViewTourStep,
    groupsFilesTourStep,
    groupsTabsTourStep,
    groupsCreateTourStep,
    groupsBodyTourStep,
    groupsPaginationTourStep,
  ],
);
