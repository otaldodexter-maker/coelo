/// Tour da tela Cardápios (`meal-plans`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const mealPlansHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Cardápios',
  text: 'Modelos de cardápio e a publicação semanal para as famílias.',
);

/// Passo 2 — directory.leading.
const mealPlansLeadingTourStep = CoeloTourStep(
  anchorId: 'directory.leading',
  title: 'Modelos ou cardápios',
  text: '"Modelos" são a base; "Cardápios" são as publicações com abrangência e período.',
);

/// Passo 3 — directory.search.
const mealPlansSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar cardápio',
  text: 'Encontre pelo nome.',
);

/// Passo 4 — directory.filters.
const mealPlansFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Origem, Conflito e Revisão.',
);

/// Passo 5 — directory.view.
const mealPlansViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text: 'A tabela mostra abrangência, período, origem e conflito.',
);

/// Passo 6 — directory.files.
const mealPlansFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe ou exporte cardápios.',
);

/// Passo 7 — directory.create.
const mealPlansCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar cardápio',
  text: 'Abre o assistente de um novo cardápio ou modelo.',
);

/// Passo 8 — directory.body.
const mealPlansBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Nas ações de cada item: Editar, Enviar revisão, Publicar, Arquivar ou Excluir.',
);

/// Passo 9 — directory.pagination.
const mealPlansPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const mealPlansScreenTour = SuperadminScreenTour(
  destinationId: 'meal-plans',
  steps: [
    mealPlansHeaderTourStep,
    mealPlansLeadingTourStep,
    mealPlansSearchTourStep,
    mealPlansFiltersTourStep,
    mealPlansViewTourStep,
    mealPlansFilesTourStep,
    mealPlansCreateTourStep,
    mealPlansBodyTourStep,
    mealPlansPaginationTourStep,
  ],
);
