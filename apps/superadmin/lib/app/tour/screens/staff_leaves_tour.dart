/// Tour da tela Afastamentos (`staff-leaves`). Etapa 3 F7 (ADR 0035);
/// proposta da sessão ACESSO-CONTEXTUAL de 19/09/2026 para o Owner revisar
/// olhando a tela. Uma constante por passo, na ordem.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const staffLeavesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Afastamentos',
  text:
      'Períodos em que o funcionário não acessa o app por aquele vínculo. O afastamento prevalece sobre horário e vigência.',
);

/// Passo 2 — directory.search.
const staffLeavesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text: 'Encontre o afastamento pelo nome do funcionário.',
);

/// Passo 3 — directory.filters.
const staffLeavesFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Filtre por instituição e unidade.',
);

/// Passo 4 — directory.tabs.
const staffLeavesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Em curso, futuros, encerrados',
  text: 'Abas por período, contadas no fuso da unidade.',
);

/// Passo 5 — directory.create.
const staffLeavesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Registrar afastamento',
  text: 'Escolha o vínculo, o período e se o funcionário vê um popup explicando.',
);

/// Passo 6 — directory.body.
const staffLeavesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Abra um afastamento para ajustar as datas, o popup ou removê-lo. Remover libera o acesso na hora.',
);

/// Passo 7 — directory.pagination.
const staffLeavesPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const staffLeavesScreenTour = SuperadminScreenTour(
  destinationId: 'staff-leaves',
  steps: [
    staffLeavesHeaderTourStep,
    staffLeavesSearchTourStep,
    staffLeavesFiltersTourStep,
    staffLeavesTabsTourStep,
    staffLeavesCreateTourStep,
    staffLeavesBodyTourStep,
    staffLeavesPaginationTourStep,
  ],
);
