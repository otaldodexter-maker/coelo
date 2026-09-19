/// Tour da tela Acompanhamento de alunos (`students`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const studentsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Acompanhamento',
  text:
      'A visão da família por aluno, contexto e período, como o responsável vê.',
);

/// Passo 2 — students.selectors.
const studentsSelectorsTourStep = CoeloTourStep(
  anchorId: 'students.selectors',
  title: 'Aluno, contexto e período',
  text:
      'Escolha o aluno, o vínculo escolar e o período que quer ver.',
);

/// Passo 3 — students.tabs.
const studentsTabsTourStep = CoeloTourStep(
  anchorId: 'students.tabs',
  title: 'Abas',
  text:
      'Visão geral, Assiduidade, Avaliações, Competências, Boletins, Agenda, Participação e Comportamento.',
);

/// Passo 4 — students.body.
const studentsBodyTourStep = CoeloTourStep(
  anchorId: 'students.body',
  title: 'O conteúdo',
  text:
      'Só o que já foi publicado aparece aqui. Presenças, faltas, notas e recomendações da professora.',
);

const studentsScreenTour = SuperadminScreenTour(
  destinationId: 'students',
  steps: [
    studentsHeaderTourStep,
    studentsSelectorsTourStep,
    studentsTabsTourStep,
    studentsBodyTourStep,
  ],
);
