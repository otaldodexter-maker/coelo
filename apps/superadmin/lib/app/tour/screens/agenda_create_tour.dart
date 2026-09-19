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
  text: 'Um evento novo na Agenda institucional, como uma publicação numa única tela.',
);

/// Passo 2 — agenda-create.basics.
const agendaCreateBasicsTourStep = CoeloTourStep(
  anchorId: 'agenda-create.basics',
  title: 'Título, data, local e público',
  text:
      'Nome do evento, data e horário, local, descrição, categoria e quem vê: instituição, unidade ou turma.',
);

/// Passo 3 — agenda-create.options.
const agendaCreateOptionsTourStep = CoeloTourStep(
  anchorId: 'agenda-create.options',
  title: 'Mais opções',
  text:
      'Dia inteiro, fuso, recorrência, prioridade, modo de resposta (ciência, presença, autorização) e lembretes.',
);

/// Passo 4 — agenda-create.questions.
const agendaCreateQuestionsTourStep = CoeloTourStep(
  anchorId: 'agenda-create.questions',
  title: 'Perguntas do evento',
  text: 'Adicione perguntas que a família responde ao confirmar.',
);

/// Passo 5 — publish.preview.
const agendaCreatePreviewTourStep = CoeloTourStep(
  anchorId: 'publish.preview',
  title: 'Prévia na Agenda',
  text: 'Como o evento aparece no calendário do público escolhido.',
);

/// Passo 6 — form.footer.
const agendaCreateFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Salvar ou publicar',
  text:
      '"Salvar rascunho" guarda sem publicar; "Publicar evento" (ou "Solicitar publicação") envia. Cancelar descarta.',
);

const agendaCreateScreenTour = SuperadminScreenTour(
  destinationId: 'agenda-create',
  steps: [
    agendaCreateHeaderTourStep,
    agendaCreateBasicsTourStep,
    agendaCreateOptionsTourStep,
    agendaCreateQuestionsTourStep,
    agendaCreatePreviewTourStep,
    agendaCreateFooterTourStep,
  ],
);
