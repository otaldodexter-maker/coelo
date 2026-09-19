/// Tour da tela Pessoas (`people`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const peopleHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Pessoas',
  text:
      'O cadastro único de cada pessoa: responsáveis, equipe e alunos, com seus vínculos.',
);

/// Passo 2 — directory.search.
const peopleSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text:
      'Encontre uma pessoa pelo nome.',
);

/// Passo 3 — directory.filters.
const peopleFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text:
      'Tipo, instituição, unidade, turma, papel, localidade e situação de acesso.',
);

/// Passo 4 — directory.view.
const peopleViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text:
      'Cards mostram vínculos e crianças; a tabela mostra papel contextual e acesso.',
);

/// Passo 5 — directory.files.
const peopleFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Importe pessoas de uma planilha ou exporte em CSV ou XLSX.',
);

/// Passo 6 — directory.tabs.
const peopleTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Segmentos',
  text:
      'Filtre por tipo de pessoa: responsáveis, equipe, alunos.',
);

/// Passo 7 — directory.create.
const peopleCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar pessoa',
  text:
      'Abre o formulário de uma nova pessoa.',
);

/// Passo 8 — directory.body.
const peopleBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Abra uma pessoa para editar dados, vínculos e acesso.',
);

/// Passo 9 — directory.pagination.
const peoplePaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const peopleScreenTour = SuperadminScreenTour(
  destinationId: 'people',
  steps: [
    peopleHeaderTourStep,
    peopleSearchTourStep,
    peopleFiltersTourStep,
    peopleViewTourStep,
    peopleFilesTourStep,
    peopleTabsTourStep,
    peopleCreateTourStep,
    peopleBodyTourStep,
    peoplePaginationTourStep,
  ],
);
