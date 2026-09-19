/// Tour da tela Momentos (`principal-moments`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — principal.nav.
const principalMomentsNavTourStep = CoeloTourStep(
  anchorId: 'principal.nav',
  title: 'Momentos',
  text:
      'Registros em vídeo e foto que merecem ser lembrados.',
);

/// Passo 2 — moments.feed.
const principalMomentsFeedTourStep = CoeloTourStep(
  anchorId: 'moments.feed',
  title: 'O feed',
  text:
      'Cada momento tem autor, contexto e legenda. Comente, compartilhe ou retire.',
);

/// Passo 3 — moments.create.
const principalMomentsCreateTourStep = CoeloTourStep(
  anchorId: 'moments.create',
  title: 'Enviar momento',
  text:
      'Publique um momento novo.',
);

const principalMomentsScreenTour = SuperadminScreenTour(
  destinationId: 'principal-moments',
  steps: [
    principalMomentsNavTourStep,
    principalMomentsFeedTourStep,
    principalMomentsCreateTourStep,
  ],
);
