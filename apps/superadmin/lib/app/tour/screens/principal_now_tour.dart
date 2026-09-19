/// Tour da tela Agora (`principal-now`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — now.viewer.
const principalNowViewerTourStep = CoeloTourStep(
  anchorId: 'now.viewer',
  title: 'O Agora',
  text:
      'Conteúdo institucional privado e temporário: fica 24 horas.',
);

/// Passo 2 — now.navigation.
const principalNowNavigationTourStep = CoeloTourStep(
  anchorId: 'now.navigation',
  title: 'Anterior e próximo',
  text:
      'Passe de um Agora para outro.',
);

/// Passo 3 — now.options.
const principalNowOptionsTourStep = CoeloTourStep(
  anchorId: 'now.options',
  title: 'Opções',
  text:
      'Audiência, compartilhar, publicar novo ou remover este Agora.',
);

/// Passo 4 — now.reply.
const principalNowReplyTourStep = CoeloTourStep(
  anchorId: 'now.reply',
  title: 'Resposta privada',
  text:
      'A família responde em particular à instituição.',
);

const principalNowScreenTour = SuperadminScreenTour(
  destinationId: 'principal-now',
  steps: [
    principalNowViewerTourStep,
    principalNowNavigationTourStep,
    principalNowOptionsTourStep,
    principalNowReplyTourStep,
  ],
);
