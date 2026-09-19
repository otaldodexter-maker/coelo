/// Tour da tela Comunicações (`notices`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const noticesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Comunicações',
  text:
      'Avisos e comunicados enviados às famílias e à equipe.',
);

/// Passo 2 — directory.search.
const noticesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar comunicação',
  text:
      'Encontre pelo título.',
);

/// Passo 3 — directory.filters.
const noticesFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Estado',
  text:
      'Rascunho, publicado, pausado ou inativo.',
);

/// Passo 4 — directory.files.
const noticesFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Importe ou exporte comunicações.',
);

/// Passo 5 — directory.tabs.
const noticesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Tipo',
  text:
      'Cada aba é um tipo de comunicação.',
);

/// Passo 6 — directory.create.
const noticesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Nova comunicação',
  text:
      'Abre o formulário: conteúdo, público e agendamento.',
);

/// Passo 7 — directory.body.
const noticesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Nas ações: Editar, Publicar, Pausar, Reativar ou Inativar (com motivo para a auditoria).',
);

/// Passo 8 — directory.pagination.
const noticesPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const noticesScreenTour = SuperadminScreenTour(
  destinationId: 'notices',
  steps: [
    noticesHeaderTourStep,
    noticesSearchTourStep,
    noticesFiltersTourStep,
    noticesFilesTourStep,
    noticesTabsTourStep,
    noticesCreateTourStep,
    noticesBodyTourStep,
    noticesPaginationTourStep,
  ],
);
