/// Tour da tela Nova chamada (`attendance-create`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const attendanceCreateHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Lançar chamada',
  text: 'Selecione o contexto antes de registrar a presença.',
);

/// Passo 2 — attendance-create.context.
const attendanceCreateContextTourStep = CoeloTourStep(
  anchorId: 'attendance-create.context',
  title: 'Contexto da chamada',
  text: 'Instituição, unidade, turma e atividade na turma. A data padrão é hoje.',
);

/// Passo 3 — attendance-create.participants.
const attendanceCreateParticipantsTourStep = CoeloTourStep(
  anchorId: 'attendance-create.participants',
  title: 'Participantes esperados',
  text:
      'Quem deve estar presente segundo os vínculos ativos. Atividades sem chamada obrigatória avisam aqui.',
);

/// Passo 4 — form.footer.
const attendanceCreateFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Lançar chamada',
  text:
      '"Lançar chamada" cria a chamada e abre a lista de participantes para marcar presença. Cancelar volta sem criar.',
);

const attendanceCreateScreenTour = SuperadminScreenTour(
  destinationId: 'attendance-create',
  steps: [
    attendanceCreateHeaderTourStep,
    attendanceCreateContextTourStep,
    attendanceCreateParticipantsTourStep,
    attendanceCreateFooterTourStep,
  ],
);
