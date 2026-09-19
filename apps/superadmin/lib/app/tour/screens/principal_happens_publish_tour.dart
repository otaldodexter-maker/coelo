/// Tour da tela Publicar no Acontece (`principal-happens-publish`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const principalHappensPublishHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Publicar no Acontece',
  text:
      'Um post novo no feed das famílias.',
);

/// Passo 2 — publish.media.
const principalHappensPublishMediaTourStep = CoeloTourStep(
  anchorId: 'publish.media',
  title: 'Mídia',
  text:
      'Adicione fotos ou vídeos.',
);

/// Passo 3 — publish.caption.
const principalHappensPublishCaptionTourStep = CoeloTourStep(
  anchorId: 'publish.caption',
  title: 'Legenda',
  text:
      'O texto do post.',
);

/// Passo 4 — publish.audience.
const principalHappensPublishAudienceTourStep = CoeloTourStep(
  anchorId: 'publish.audience',
  title: 'Público e contexto',
  text:
      'Quem vê: instituição, unidade ou turma.',
);

/// Passo 5 — publish.schedule.
const principalHappensPublishScheduleTourStep = CoeloTourStep(
  anchorId: 'publish.schedule',
  title: 'Agendamento e opções',
  text:
      'Publique agora, agende ou salve como rascunho.',
);

/// Passo 6 — publish.preview.
const principalHappensPublishPreviewTourStep = CoeloTourStep(
  anchorId: 'publish.preview',
  title: 'Prévia',
  text:
      'Como o post vai aparecer no feed.',
);

/// Passo 7 — form.footer.
const principalHappensPublishFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Publicar',
  text:
      '"Publicar" envia; "Salvar rascunho" guarda; Cancelar descarta.',
);

const principalHappensPublishScreenTour = SuperadminScreenTour(
  destinationId: 'principal-happens-publish',
  steps: [
    principalHappensPublishHeaderTourStep,
    principalHappensPublishMediaTourStep,
    principalHappensPublishCaptionTourStep,
    principalHappensPublishAudienceTourStep,
    principalHappensPublishScheduleTourStep,
    principalHappensPublishPreviewTourStep,
    principalHappensPublishFooterTourStep,
  ],
);
