/// Tour da tela Chat (`principal-chat`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — chat.search.
const principalChatSearchTourStep = CoeloTourStep(
  anchorId: 'chat.search',
  title: 'Buscar conversas',
  text: 'Encontre uma conversa.',
);

/// Passo 2 — chat.list.
const principalChatListTourStep = CoeloTourStep(
  anchorId: 'chat.list',
  title: 'Lista',
  text: 'As conversas da família, com não lidas.',
);

/// Passo 3 — chat.thread.
const principalChatThreadTourStep = CoeloTourStep(
  anchorId: 'chat.thread',
  title: 'A conversa',
  text: 'Mensagens e anexos. Role para carregar as anteriores.',
);

/// Passo 4 — chat.composer.
const principalChatComposerTourStep = CoeloTourStep(
  anchorId: 'chat.composer',
  title: 'Escrever',
  text: 'Digite e envie.',
);

const principalChatScreenTour = SuperadminScreenTour(
  destinationId: 'principal-chat',
  steps: [
    principalChatSearchTourStep,
    principalChatListTourStep,
    principalChatThreadTourStep,
    principalChatComposerTourStep,
  ],
);
