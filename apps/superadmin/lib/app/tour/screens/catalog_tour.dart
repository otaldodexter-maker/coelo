/// Tour da tela Catálogo (`catalog`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const catalogHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Catálogo',
  text: 'Fundamentos, componentes e padrões aprovados da interface.',
);

/// Passo 2 — page.actions.
const catalogActionsTourStep = CoeloTourStep(
  anchorId: 'page.actions',
  title: 'Abrir em nova aba',
  text: 'Abra o catálogo numa aba própria do navegador.',
);

/// Passo 3 — catalog.frame.
const catalogFrameTourStep = CoeloTourStep(
  anchorId: 'catalog.frame',
  title: 'O catálogo',
  text: 'Navegue pelos componentes aqui mesmo.',
);

const catalogScreenTour = SuperadminScreenTour(
  destinationId: 'catalog',
  steps: [catalogHeaderTourStep, catalogActionsTourStep, catalogFrameTourStep],
);
