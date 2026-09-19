/// Tour da tela Fechamento de avaliações (`assessment-closing`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const assessmentClosingHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Fechamento de avaliações',
  text:
      'Revise pendências e publique resultados autorizados.',
);

/// Passo 2 — directory.search.
const assessmentClosingSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar turma ou Atividade',
  text:
      'Encontre o envio pelo nome da turma ou da Atividade.',
);

/// Passo 3 — directory.files.
const assessmentClosingFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Exporte os fechamentos em CSV ou XLSX.',
);

/// Passo 4 — directory.body.
const assessmentClosingBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'Envios pendentes',
  text:
      'Cada linha é um envio: turma, período e quantas pendências restam. Clique para abrir.',
);

/// Passo 5 — assessment-closing.detail.
const assessmentClosingDetailTourStep = CoeloTourStep(
  anchorId: 'assessment-closing.detail',
  title: 'Completar pendências',
  text:
      'No detalhe você completa o que falta com justificativa, publica e vê o histórico de eventos.',
);

const assessmentClosingScreenTour = SuperadminScreenTour(
  destinationId: 'assessment-closing',
  steps: [
    assessmentClosingHeaderTourStep,
    assessmentClosingSearchTourStep,
    assessmentClosingFilesTourStep,
    assessmentClosingBodyTourStep,
    assessmentClosingDetailTourStep,
  ],
);
