/// Tour da tela Lançar avaliações (`assessment-entry`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const assessmentEntryHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Lançar avaliações',
  text:
      'Registre resultados e acompanhe as pendências da turma.',
);

/// Passo 2 — assessment.context.
const assessmentEntryContextTourStep = CoeloTourStep(
  anchorId: 'assessment.context',
  title: 'Contexto do lançamento',
  text:
      'Escolha instituição, unidade, turma e Atividade. O diário só abre com o contexto completo.',
);

/// Passo 3 — assessment.period.
const assessmentEntryPeriodTourStep = CoeloTourStep(
  anchorId: 'assessment.period',
  title: 'Período avaliativo',
  text:
      'O período vigente da configuração da Atividade. Período fechado não aceita lançamento.',
);

/// Passo 4 — assessment.toolbar.
const assessmentEntryToolbarTourStep = CoeloTourStep(
  anchorId: 'assessment.toolbar',
  title: 'Aluno, situação e modo',
  text:
      'Busque um aluno, filtre por situação e escolha o modo de lançamento (tabela ou aluno a aluno).',
);

/// Passo 5 — assessment.gradebook.
const assessmentEntryGradebookTourStep = CoeloTourStep(
  anchorId: 'assessment.gradebook',
  title: 'O diário',
  text:
      'Uma linha por aluno, uma coluna por instrumento com seu peso. A média sugerida é calculada na hora.',
);

/// Passo 6 — assessment.footer.
const assessmentEntryFooterTourStep = CoeloTourStep(
  anchorId: 'assessment.footer',
  title: 'Salvar e enviar',
  text:
      '"Salvar rascunho" guarda sem publicar; "Revisão e envio" confere pendências e envia para fechamento.',
);

const assessmentEntryScreenTour = SuperadminScreenTour(
  destinationId: 'assessment-entry',
  steps: [
    assessmentEntryHeaderTourStep,
    assessmentEntryContextTourStep,
    assessmentEntryPeriodTourStep,
    assessmentEntryToolbarTourStep,
    assessmentEntryGradebookTourStep,
    assessmentEntryFooterTourStep,
  ],
);
