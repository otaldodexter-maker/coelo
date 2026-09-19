/// Tour da tela Publicar no Acontece (`principal-happens-publish`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — publish.media.
const principalHappensPublishMediaTourStep = CoeloTourStep(
  anchorId: 'publish.media',
  title: 'Mídia',
  text: 'Adicione fotos ou vídeos; arraste para reordenar.',
);

/// Passo 2 — publish.caption.
const principalHappensPublishCaptionTourStep = CoeloTourStep(
  anchorId: 'publish.caption',
  title: 'Legenda',
  text: 'O texto do post.',
);

/// Passo 3 — publish.audience.
const principalHappensPublishAudienceTourStep = CoeloTourStep(
  anchorId: 'publish.audience',
  title: 'Público e contexto',
  text: 'O contexto da publicação e quem vê: famílias, equipe ou ambos.',
);

/// Passo 4 — publish.schedule.
const principalHappensPublishScheduleTourStep = CoeloTourStep(
  anchorId: 'publish.schedule',
  title: 'Agendamento e opções',
  text: 'Marque data e hora para agendar; "Salvar como rascunho" guarda automaticamente.',
);

/// Passo 5 — publish.preview.
const principalHappensPublishPreviewTourStep = CoeloTourStep(
  anchorId: 'publish.preview',
  title: 'Prévia',
  text: 'Como o post vai aparecer no feed do Acontece.',
);

/// Passo 6 — form.footer.
const principalHappensPublishFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Publicar',
  text: '"Publicar no Acontece" envia (ou agenda); "Salvar rascunho" guarda; Cancelar volta.',
);

const principalHappensPublishScreenTour = SuperadminScreenTour(
  destinationId: 'principal-happens-publish',
  steps: [
    principalHappensPublishMediaTourStep,
    principalHappensPublishCaptionTourStep,
    principalHappensPublishAudienceTourStep,
    principalHappensPublishScheduleTourStep,
    principalHappensPublishPreviewTourStep,
    principalHappensPublishFooterTourStep,
  ],
);
