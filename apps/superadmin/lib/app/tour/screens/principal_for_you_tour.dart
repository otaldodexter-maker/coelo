/// Tour da tela Para você (`principal-for-you`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — principal.nav.
const principalForYouNavTourStep = CoeloTourStep(
  anchorId: 'principal.nav',
  title: 'Para você',
  text: 'A página da família com o resumo do dia dos filhos.',
);

/// Passo 2 — for-you.shortcuts.
const principalForYouShortcutsTourStep = CoeloTourStep(
  anchorId: 'for-you.shortcuts',
  title: 'Atalhos essenciais',
  text: 'Os acessos mais usados pela família.',
);

/// Passo 3 — for-you.summary.
const principalForYouSummaryTourStep = CoeloTourStep(
  anchorId: 'for-you.summary',
  title: 'Resumo do dia',
  text: 'Presença, rotina e recados de hoje.',
);

/// Passo 4 — for-you.context.
const principalForYouContextTourStep = CoeloTourStep(
  anchorId: 'for-you.context',
  title: 'Seu contexto atual',
  text: 'A visão geral ou por criança e vínculo. "Trocar contexto" muda.',
);

const principalForYouScreenTour = SuperadminScreenTour(
  destinationId: 'principal-for-you',
  steps: [
    principalForYouNavTourStep,
    principalForYouShortcutsTourStep,
    principalForYouSummaryTourStep,
    principalForYouContextTourStep,
  ],
);
