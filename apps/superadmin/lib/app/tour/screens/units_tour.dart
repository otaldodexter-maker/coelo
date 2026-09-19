/// Tour da tela Unidades (`units`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const unitsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Unidades',
  text: 'Cada escola, sede ou filial. Turmas, equipe e famílias pertencem sempre a uma unidade.',
);

/// Passo 2 — directory.search.
const unitsSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text: 'Encontre uma unidade pelo nome.',
);

/// Passo 3 — directory.filters.
const unitsFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Filtre por instituição e situação. "Limpar filtros" desfaz tudo.',
);

/// Passo 4 — directory.view.
const unitsViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text: 'Na tabela você pode ver Agrupado, Por turmas ou Por atividades.',
);

/// Passo 5 — directory.files.
const unitsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe unidades de uma planilha ou exporte em CSV ou XLSX.',
);

/// Passo 6 — directory.tabs.
const unitsTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text: 'Todos, Ativos, Em Implantação ou Inativos.',
);

/// Passo 7 — directory.create.
const unitsCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar unidade',
  text: 'Abre o formulário de uma nova unidade dentro de uma instituição.',
);

/// Passo 8 — directory.body.
const unitsBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Abra uma unidade para ver turmas, locais e equipe.',
);

/// Passo 9 — directory.pagination.
const unitsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const unitsScreenTour = SuperadminScreenTour(
  destinationId: 'units',
  steps: [
    unitsHeaderTourStep,
    unitsSearchTourStep,
    unitsFiltersTourStep,
    unitsViewTourStep,
    unitsFilesTourStep,
    unitsTabsTourStep,
    unitsCreateTourStep,
    unitsBodyTourStep,
    unitsPaginationTourStep,
  ],
);
