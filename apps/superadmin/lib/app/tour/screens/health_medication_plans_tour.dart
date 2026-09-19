/// Tour da tela Planos de medicação (`health-medication-plans`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const healthMedicationPlansHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Planos de medicação',
  text: 'Medicamentos autorizados, horários e o registro de cada dose aplicada.',
);

/// Passo 2 — directory.search.
const healthMedicationPlansSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text: 'Nome da criança ou do medicamento.',
);

/// Passo 3 — directory.filters.
const healthMedicationPlansFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Status do plano e situação da dose.',
);

/// Passo 4 — directory.view.
const healthMedicationPlansViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text: 'A tabela agrupa por criança ou por horário.',
);

/// Passo 5 — directory.files.
const healthMedicationPlansFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe planos ou exporte em CSV ou XLSX.',
);

/// Passo 6 — directory.create.
const healthMedicationPlansCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar plano de medicação',
  text: 'Abre o formulário: criança, medicamento, vigência e horários.',
);

/// Passo 7 — directory.body.
const healthMedicationPlansBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Criança, medicamento, vigência, horários e contexto responsável.',
);

/// Passo 8 — directory.pagination.
const healthMedicationPlansPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const healthMedicationPlansScreenTour = SuperadminScreenTour(
  destinationId: 'health-medication-plans',
  steps: [
    healthMedicationPlansHeaderTourStep,
    healthMedicationPlansSearchTourStep,
    healthMedicationPlansFiltersTourStep,
    healthMedicationPlansViewTourStep,
    healthMedicationPlansFilesTourStep,
    healthMedicationPlansCreateTourStep,
    healthMedicationPlansBodyTourStep,
    healthMedicationPlansPaginationTourStep,
  ],
);
