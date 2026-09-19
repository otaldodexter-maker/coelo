/// Tour da tela Perfil (`principal-profile`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — profile.header.
const principalProfileHeaderTourStep = CoeloTourStep(
  anchorId: 'profile.header',
  title: 'O perfil',
  text:
      'Nome, brasão, campus e verificação da instituição.',
);

/// Passo 2 — profile.actions.
const principalProfileActionsTourStep = CoeloTourStep(
  anchorId: 'profile.actions',
  title: 'Acompanhar, mensagem e editar',
  text:
      'Siga o perfil, envie mensagem ou edite (quando permitido).',
);

/// Passo 3 — profile.highlights.
const principalProfileHighlightsTourStep = CoeloTourStep(
  anchorId: 'profile.highlights',
  title: 'Destaques e vínculos',
  text:
      'Conteúdos em destaque e as pessoas vinculadas.',
);

/// Passo 4 — profile.tabs.
const principalProfileTabsTourStep = CoeloTourStep(
  anchorId: 'profile.tabs',
  title: 'Abas',
  text:
      'Acontece, Momentos, Circulares e Sobre.',
);

const principalProfileScreenTour = SuperadminScreenTour(
  destinationId: 'principal-profile',
  steps: [
    principalProfileHeaderTourStep,
    principalProfileActionsTourStep,
    principalProfileHighlightsTourStep,
    principalProfileTabsTourStep,
  ],
);
