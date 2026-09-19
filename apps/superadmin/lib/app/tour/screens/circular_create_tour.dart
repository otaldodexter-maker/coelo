/// Tour da tela Publicar Circular (`circular-create`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const circularCreateHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Publicar Circular',
  text: 'Uma circular nova: comunicado formal com texto, mídia e perguntas.',
);

/// Passo 2 — circular.title.
const circularCreateTitleTourStep = CoeloTourStep(
  anchorId: 'circular.title',
  title: 'Título',
  text: 'O assunto da circular.',
);

/// Passo 3 — circular.blocks.
const circularCreateBlocksTourStep = CoeloTourStep(
  anchorId: 'circular.blocks',
  title: 'Conteúdo',
  text:
      'Adicione texto, mídia (PDF, imagem ou vídeo) e perguntas na ordem de leitura; mova ou exclua blocos.',
);

/// Passo 4 — publish.audience.
const circularCreateAudienceTourStep = CoeloTourStep(
  anchorId: 'publish.audience',
  title: 'Público e contexto',
  text: 'Quem recebe a circular e a resposta esperada.',
);

/// Passo 5 — publish.schedule.
const circularCreateScheduleTourStep = CoeloTourStep(
  anchorId: 'publish.schedule',
  title: 'Agendamento e opções',
  text: 'Publique agora, agende ou salve como rascunho.',
);

/// Passo 6 — publish.preview.
const circularCreatePreviewTourStep = CoeloTourStep(
  anchorId: 'publish.preview',
  title: 'Prévia',
  text: 'Como a circular aparece para a família.',
);

/// Passo 7 — form.footer.
const circularCreateFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Publicar',
  text: '"Publicar" envia; "Salvar rascunho" guarda; Cancelar volta.',
);

const circularCreateScreenTour = SuperadminScreenTour(
  destinationId: 'circular-create',
  steps: [
    circularCreateHeaderTourStep,
    circularCreateTitleTourStep,
    circularCreateBlocksTourStep,
    circularCreateAudienceTourStep,
    circularCreateScheduleTourStep,
    circularCreatePreviewTourStep,
    circularCreateFooterTourStep,
  ],
);
