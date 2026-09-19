/// Tour da tela Home (`home`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const homeHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Home',
  text:
      'Sua página inicial. Tire dúvidas e encontre orientações sobre o Coelo sem sair do painel.',
);

/// Passo 2 — home.question.
const homeQuestionTourStep = CoeloTourStep(
  anchorId: 'home.question',
  title: 'Pergunte sobre o Coelo',
  text:
      'Escreva uma pergunta sobre recursos, rotinas ou navegação e envie. A resposta aparece aqui mesmo.',
);

/// Passo 3 — home.history.
const homeHistoryTourStep = CoeloTourStep(
  anchorId: 'home.history',
  title: 'Conversas desta sessão',
  text:
      'Suas perguntas ficam listadas aqui enquanto você usa o painel. "Nova conversa" começa do zero; o painel pode ser recolhido.',
);

const homeScreenTour = SuperadminScreenTour(
  destinationId: 'home',
  steps: [
    homeHeaderTourStep,
    homeQuestionTourStep,
    homeHistoryTourStep,
  ],
);
