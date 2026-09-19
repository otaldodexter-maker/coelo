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
  text: 'Registre resultados e acompanhe as pendências da turma.',
);

/// Passo 2 — form.navigation.
const assessmentEntryNavigationTourStep = CoeloTourStep(
  anchorId: 'form.navigation',
  title: 'Etapas do lançamento',
  text:
      'Contexto, Notas e competências, Comentários e Revisão e envio. Cada etapa libera a seguinte.',
);

/// Passo 3 — assessment.context.
const assessmentEntryContextTourStep = CoeloTourStep(
  anchorId: 'assessment.context',
  title: 'Contexto do lançamento',
  text:
      'Escolha instituição, unidade, turma e Atividade. O diário só abre com o contexto completo.',
);

/// Passo 4 — assessment.period.
const assessmentEntryPeriodTourStep = CoeloTourStep(
  anchorId: 'assessment.period',
  title: 'Período avaliativo',
  text: 'O período vigente da configuração da Atividade. Período fechado não aceita lançamento.',
);

/// Passo 5 — assessment.toolbar.
const assessmentEntryToolbarTourStep = CoeloTourStep(
  anchorId: 'assessment.toolbar',
  title: 'Aluno, situação e modo',
  text:
      'Busque um aluno, filtre por situação e escolha o modo de lançamento (tabela ou aluno a aluno).',
);

/// Passo 6 — assessment.gradebook.
const assessmentEntryGradebookTourStep = CoeloTourStep(
  anchorId: 'assessment.gradebook',
  title: 'O diário',
  text:
      'Uma linha por aluno, uma coluna por instrumento com seu peso. A média sugerida é calculada na hora.',
);

/// Passo 7 — form.footer.
const assessmentEntryFooterTourStep = CoeloTourStep(
  anchorId: 'form.footer',
  title: 'Salvar e avançar',
  text:
      '"Salvar rascunho" guarda sem publicar; o botão de avançar leva à próxima etapa até a revisão e o envio.',
);

const assessmentEntryScreenTour = SuperadminScreenTour(
  destinationId: 'assessment-entry',
  steps: [
    assessmentEntryHeaderTourStep,
    assessmentEntryNavigationTourStep,
    assessmentEntryContextTourStep,
    assessmentEntryPeriodTourStep,
    assessmentEntryToolbarTourStep,
    assessmentEntryGradebookTourStep,
    assessmentEntryFooterTourStep,
  ],
);
