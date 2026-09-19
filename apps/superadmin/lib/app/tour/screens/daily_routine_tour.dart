/// Tour da tela Rotina diária (`daily-routine`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const dailyRoutineHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Rotina diária',
  text:
      'Modelos, versões e alcances do registro cotidiano (sono, alimentação, higiene).',
);

/// Passo 2 — daily-routine.tabs.
const dailyRoutineTabsTourStep = CoeloTourStep(
  anchorId: 'daily-routine.tabs',
  title: 'Modelos ou rotinas',
  text:
      '"Modelos" são a base; "Rotinas" são as versões aplicadas a cada unidade ou turma.',
);

/// Passo 3 — directory.search.
const dailyRoutineSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text:
      'Encontre um modelo ou rotina pelo nome.',
);

/// Passo 4 — directory.filters.
const dailyRoutineFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Status e tabela',
  text:
      'Filtre por status e alterne para a tabela com nome, origem, versão e ações.',
);

/// Passo 5 — directory.files.
const dailyRoutineFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Configuração',
  text:
      'Importe ou exporte a configuração completa da rotina.',
);

/// Passo 6 — directory.create.
const dailyRoutineCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar',
  text:
      'Abre o editor de um novo modelo ou rotina.',
);

/// Passo 7 — directory.body.
const dailyRoutineBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Cada item mostra versão, origem e vigência. Nas ações: editar, arquivar, restaurar ou publicar.',
);

const dailyRoutineScreenTour = SuperadminScreenTour(
  destinationId: 'daily-routine',
  steps: [
    dailyRoutineHeaderTourStep,
    dailyRoutineTabsTourStep,
    dailyRoutineSearchTourStep,
    dailyRoutineFiltersTourStep,
    dailyRoutineFilesTourStep,
    dailyRoutineCreateTourStep,
    dailyRoutineBodyTourStep,
  ],
);
