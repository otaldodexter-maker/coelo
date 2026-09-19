/// Tour da tela Conversas (`conversations`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const conversationsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Conversas',
  text: 'Comunicação institucional privada e contextual.',
);

/// Passo 2 — chat.search.
const conversationsSearchTourStep = CoeloTourStep(
  anchorId: 'chat.search',
  title: 'Buscar conversas',
  text: 'Encontre uma conversa pelo nome ou contexto.',
);

/// Passo 3 — chat.create.
const conversationsCreateTourStep = CoeloTourStep(
  anchorId: 'chat.create',
  title: 'Criar grupo',
  text: 'Abra um grupo com pessoas do seu escopo.',
);

/// Passo 4 — chat.list.
const conversationsListTourStep = CoeloTourStep(
  anchorId: 'chat.list',
  title: 'Lista',
  text: 'Cada conversa mostra tipo, contexto e não lidas. Clique para abrir.',
);

/// Passo 5 — chat.thread.
const conversationsThreadTourStep = CoeloTourStep(
  anchorId: 'chat.thread',
  title: 'A conversa',
  text: 'Mensagens, anexos e ações (editar, revogar). Role para carregar as anteriores.',
);

/// Passo 6 — chat.composer.
const conversationsComposerTourStep = CoeloTourStep(
  anchorId: 'chat.composer',
  title: 'Escrever',
  text: 'Digite a mensagem, anexe arquivos e envie.',
);

const conversationsScreenTour = SuperadminScreenTour(
  destinationId: 'conversations',
  steps: [
    conversationsHeaderTourStep,
    conversationsSearchTourStep,
    conversationsCreateTourStep,
    conversationsListTourStep,
    conversationsThreadTourStep,
    conversationsComposerTourStep,
  ],
);
