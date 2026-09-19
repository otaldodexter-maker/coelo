/// Tour da tela Publicar no Agora (`principal-now-publish`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — publish.media.
const principalNowPublishMediaTourStep = CoeloTourStep(
  anchorId: 'publish.media',
  title: 'Mídia',
  text: 'Adicione ou troque a mídia. O Agora fica disponível por 24 horas.',
);

/// Passo 2 — now-publish.tools.
const principalNowPublishToolsTourStep = CoeloTourStep(
  anchorId: 'now-publish.tools',
  title: 'Texto, música, cortar e capa',
  text: 'Ajuste o conteúdo sobre a mídia.',
);

/// Passo 3 — publish.caption.
const principalNowPublishCaptionTourStep = CoeloTourStep(
  anchorId: 'publish.caption',
  title: 'Contexto opcional',
  text: 'Uma frase curta que acompanha a mídia.',
);

/// Passo 4 — publish.audience.
const principalNowPublishAudienceTourStep = CoeloTourStep(
  anchorId: 'publish.audience',
  title: 'Público e contexto',
  text: 'Quem vê o Agora.',
);

/// Passo 5 — publish.schedule.
const principalNowPublishScheduleTourStep = CoeloTourStep(
  anchorId: 'publish.schedule',
  title: 'Agendar',
  text: 'Publique agora ou marque data e hora.',
);

/// Passo 6 — form.footer.
const principalNowPublishFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Publicar',
  text: '"Publicar no Agora" envia; "Salvar rascunho" guarda; Cancelar volta.',
);

const principalNowPublishScreenTour = SuperadminScreenTour(
  destinationId: 'principal-now-publish',
  steps: [
    principalNowPublishMediaTourStep,
    principalNowPublishToolsTourStep,
    principalNowPublishCaptionTourStep,
    principalNowPublishAudienceTourStep,
    principalNowPublishScheduleTourStep,
    principalNowPublishFooterTourStep,
  ],
);
