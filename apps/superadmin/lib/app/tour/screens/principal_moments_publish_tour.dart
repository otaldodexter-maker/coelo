/// Tour da tela Publicar em Momentos (`principal-moments-publish`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const principalMomentsPublishHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Publicar em Momentos',
  text:
      'Um momento novo.',
);

/// Passo 2 — publish.media.
const principalMomentsPublishMediaTourStep = CoeloTourStep(
  anchorId: 'publish.media',
  title: 'Mídia e capa',
  text:
      'Adicione a mídia e escolha a capa.',
);

/// Passo 3 — publish.caption.
const principalMomentsPublishCaptionTourStep = CoeloTourStep(
  anchorId: 'publish.caption',
  title: 'Legenda',
  text:
      'Conte o que torna este momento especial.',
);

/// Passo 4 — publish.audience.
const principalMomentsPublishAudienceTourStep = CoeloTourStep(
  anchorId: 'publish.audience',
  title: 'Público e contexto',
  text:
      'Quem vê o momento.',
);

/// Passo 5 — publish.schedule.
const principalMomentsPublishScheduleTourStep = CoeloTourStep(
  anchorId: 'publish.schedule',
  title: 'Agendamento e opções',
  text:
      'Publique agora, agende ou salve como rascunho.',
);

/// Passo 6 — publish.preview.
const principalMomentsPublishPreviewTourStep = CoeloTourStep(
  anchorId: 'publish.preview',
  title: 'Prévia',
  text:
      'Como o momento vai aparecer.',
);

/// Passo 7 — form.footer.
const principalMomentsPublishFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Publicar',
  text:
      '"Publicar" envia; "Salvar rascunho" guarda; Cancelar descarta.',
);

const principalMomentsPublishScreenTour = SuperadminScreenTour(
  destinationId: 'principal-moments-publish',
  steps: [
    principalMomentsPublishHeaderTourStep,
    principalMomentsPublishMediaTourStep,
    principalMomentsPublishCaptionTourStep,
    principalMomentsPublishAudienceTourStep,
    principalMomentsPublishScheduleTourStep,
    principalMomentsPublishPreviewTourStep,
    principalMomentsPublishFooterTourStep,
  ],
);
