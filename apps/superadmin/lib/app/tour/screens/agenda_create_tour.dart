/// Tour da tela Criar evento (`agenda-create`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const agendaCreateHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Criar evento',
  text:
      'Um evento novo na Agenda institucional.',
);

/// Passo 2 — form.navigation.
const agendaCreateNavigationTourStep = CoeloTourStep(
  anchorId: 'form.navigation',
  title: 'Seções',
  text:
      'Navegue entre as seções do formulário.',
);

/// Passo 3 — agenda-create.basics.
const agendaCreateBasicsTourStep = CoeloTourStep(
  anchorId: 'agenda-create.basics',
  title: 'Título, período e local',
  text:
      'Nome do evento, data e horário de início e fim, dia inteiro e local.',
);

/// Passo 4 — agenda-create.context.
const agendaCreateContextTourStep = CoeloTourStep(
  anchorId: 'agenda-create.context',
  title: 'Contexto principal',
  text:
      'Quem vê o evento: instituição, unidade ou turma.',
);

/// Passo 5 — agenda-create.recurrence.
const agendaCreateRecurrenceTourStep = CoeloTourStep(
  anchorId: 'agenda-create.recurrence',
  title: 'Recorrência e prioridade',
  text:
      'Repita o evento, defina o término da série e a prioridade.',
);

/// Passo 6 — agenda-create.response.
const agendaCreateResponseTourStep = CoeloTourStep(
  anchorId: 'agenda-create.response',
  title: 'Resposta e lembretes',
  text:
      'Modo de resposta (ciência, presença, autorização), política de responsáveis e lembretes.',
);

/// Passo 7 — agenda-create.questions.
const agendaCreateQuestionsTourStep = CoeloTourStep(
  anchorId: 'agenda-create.questions',
  title: 'Perguntas do evento',
  text:
      'Adicione perguntas que a família responde ao confirmar.',
);

/// Passo 8 — agenda-create.preview.
const agendaCreatePreviewTourStep = CoeloTourStep(
  anchorId: 'agenda-create.preview',
  title: 'Prévia na Agenda',
  text:
      'Como o evento aparece no calendário do público escolhido.',
);

/// Passo 9 — form.footer.
const agendaCreateFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Salvar',
  text:
      '"Salvar rascunho" guarda sem publicar. Cancelar descarta.',
);

const agendaCreateScreenTour = SuperadminScreenTour(
  destinationId: 'agenda-create',
  steps: [
    agendaCreateHeaderTourStep,
    agendaCreateNavigationTourStep,
    agendaCreateBasicsTourStep,
    agendaCreateContextTourStep,
    agendaCreateRecurrenceTourStep,
    agendaCreateResponseTourStep,
    agendaCreateQuestionsTourStep,
    agendaCreatePreviewTourStep,
    agendaCreateFooterTourStep,
  ],
);
