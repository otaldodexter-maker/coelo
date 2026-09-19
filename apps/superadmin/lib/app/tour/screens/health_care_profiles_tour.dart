/// Tour da tela Perfis de cuidado (`health-care-profiles`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const healthCareProfilesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Perfis de cuidado',
  text:
      'Alergias, restrições e o que fazer em caso de contato, por criança.',
);

/// Passo 2 — directory.search.
const healthCareProfilesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar criança',
  text:
      'Encontre o perfil pelo nome da criança.',
);

/// Passo 3 — directory.view.
const healthCareProfilesViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text:
      'A tabela agrupa por unidade.',
);

/// Passo 4 — directory.files.
const healthCareProfilesFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Importe perfis ou exporte em CSV ou XLSX.',
);

/// Passo 5 — directory.tabs.
const healthCareProfilesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text:
      'Todos, Ativos, Em implantação ou Inativos.',
);

/// Passo 6 — directory.create.
const healthCareProfilesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar perfil de cuidado',
  text:
      'Abre o formulário: criança, alimentos, restrições e orientações.',
);

/// Passo 7 — directory.body.
const healthCareProfilesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Criança, alergias e restrições. Só quem cuida da criança vê o perfil.',
);

/// Passo 8 — directory.pagination.
const healthCareProfilesPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const healthCareProfilesScreenTour = SuperadminScreenTour(
  destinationId: 'health-care-profiles',
  steps: [
    healthCareProfilesHeaderTourStep,
    healthCareProfilesSearchTourStep,
    healthCareProfilesViewTourStep,
    healthCareProfilesFilesTourStep,
    healthCareProfilesTabsTourStep,
    healthCareProfilesCreateTourStep,
    healthCareProfilesBodyTourStep,
    healthCareProfilesPaginationTourStep,
  ],
);
