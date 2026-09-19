/// Tour da tela Formulários (`forms`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const formsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Formulários',
  text: 'Crie perguntas, escolha quem responde e acompanhe as respostas.',
);

/// Passo 2 — directory.search.
const formsSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar formulários',
  text: 'Encontre um formulário pelo nome.',
);

/// Passo 3 — directory.filters.
const formsFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Situação',
  text: 'Rascunho, publicado, encerrado.',
);

/// Passo 4 — directory.files.
const formsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe ou exporte formulários.',
);

/// Passo 5 — directory.create.
const formsCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar formulário',
  text: 'Abre o editor: perguntas, público, agendamento e teste.',
);

/// Passo 6 — directory.body.
const formsBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Situação, contexto, público, respostas e agendamentos. Nas ações: editar, testar, monitorar e ver respostas.',
);

/// Passo 7 — directory.pagination.
const formsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const formsScreenTour = SuperadminScreenTour(
  destinationId: 'forms',
  steps: [
    formsHeaderTourStep,
    formsSearchTourStep,
    formsFiltersTourStep,
    formsFilesTourStep,
    formsCreateTourStep,
    formsBodyTourStep,
    formsPaginationTourStep,
  ],
);
