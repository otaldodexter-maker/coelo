/// Tour da tela Suporte e implantação (`support`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const supportHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Suporte e implantação',
  text: 'Acompanhe os chamados e solicitações da operação.',
);

/// Passo 2 — directory.search.
const supportSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar chamados',
  text: 'Encontre um chamado pelo texto.',
);

/// Passo 3 — directory.filters.
const supportFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Menu, Responsável, Leitura e Tela. "Limpar filtros" volta ao início.',
);

/// Passo 4 — directory.view.
const supportViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Kanban ou tabela',
  text: 'Alterne entre o quadro por etapa e a tabela.',
);

/// Passo 5 — directory.files.
const supportFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Exportar',
  text: 'Exporte os chamados em CSV ou XLSX.',
);

/// Passo 6 — directory.create.
const supportCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar suporte',
  text: 'Abre um novo chamado.',
);

/// Passo 7 — directory.body.
const supportBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'O quadro',
  text: 'Arraste ou use "Mover para" para mudar a etapa; escolha responsáveis no card.',
);

/// Passo 8 — support.detail.
const supportDetailTourStep = CoeloTourStep(
  anchorId: 'support.detail',
  title: 'O chamado',
  text: 'Selecione um chamado para ver mensagens, anexos e responder.',
);

const supportScreenTour = SuperadminScreenTour(
  destinationId: 'support',
  steps: [
    supportHeaderTourStep,
    supportSearchTourStep,
    supportFiltersTourStep,
    supportViewTourStep,
    supportFilesTourStep,
    supportCreateTourStep,
    supportBodyTourStep,
    supportDetailTourStep,
  ],
);
