/// Tour da tela Auditoria (`audit`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const auditHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Auditoria',
  text: 'Tudo o que foi feito no painel: quem, quando e o quê.',
);

/// Passo 2 — directory.search.
const auditSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar na auditoria',
  text: 'Filtre os eventos por texto.',
);

/// Passo 3 — directory.files.
const auditFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Exportar',
  text: 'Exporte os eventos em CSV ou XLSX.',
);

/// Passo 4 — directory.body.
const auditBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'Eventos',
  text: 'Cada linha é um evento; clique para ver o detalhe.',
);

/// Passo 5 — directory.pagination.
const auditPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const auditScreenTour = SuperadminScreenTour(
  destinationId: 'audit',
  steps: [
    auditHeaderTourStep,
    auditSearchTourStep,
    auditFilesTourStep,
    auditBodyTourStep,
    auditPaginationTourStep,
  ],
);
