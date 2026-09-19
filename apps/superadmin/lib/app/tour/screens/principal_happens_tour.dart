/// Tour da tela Acontece (`principal-happens`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — principal.nav.
const principalHappensNavTourStep = CoeloTourStep(
  anchorId: 'principal.nav',
  title: 'O app das famílias',
  text:
      'Aqui você vê o Coelo como a família vê. Home, Para você, Momentos, Publicar e Mensagens.',
);

/// Passo 2 — principal.context.
const principalHappensContextTourStep = CoeloTourStep(
  anchorId: 'principal.context',
  title: 'Trocar contexto',
  text:
      'Veja o app como outra instituição, unidade ou pessoa do seu escopo.',
);

/// Passo 3 — happens.now.
const principalHappensNowTourStep = CoeloTourStep(
  anchorId: 'happens.now',
  title: 'Agora',
  text:
      'A faixa de conteúdos temporários de 24 horas. "Publicar agora" cria um novo.',
);

/// Passo 4 — happens.feed.
const principalHappensFeedTourStep = CoeloTourStep(
  anchorId: 'happens.feed',
  title: 'O feed',
  text:
      'Publicações da instituição: comente, compartilhe ou retire uma publicação.',
);

/// Passo 5 — happens.side.
const principalHappensSideTourStep = CoeloTourStep(
  anchorId: 'happens.side',
  title: 'Ao lado',
  text:
      'Próximos eventos, avisos importantes e aniversariantes.',
);

const principalHappensScreenTour = SuperadminScreenTour(
  destinationId: 'principal-happens',
  steps: [
    principalHappensNavTourStep,
    principalHappensContextTourStep,
    principalHappensNowTourStep,
    principalHappensFeedTourStep,
    principalHappensSideTourStep,
  ],
);
