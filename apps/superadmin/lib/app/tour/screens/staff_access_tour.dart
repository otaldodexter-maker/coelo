/// Tour da tela Acesso de funcionários (`staff-access`). Etapa 3 F7 (ADR
/// 0035); proposta da sessão ACESSO-CONTEXTUAL de 19/09/2026 para o Owner
/// revisar olhando a tela. Uma constante por passo, na ordem.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const staffAccessHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Acesso de funcionários',
  text:
      'Uma linha por vínculo profissional. A regra vale só para aquele vínculo: a pessoa segue usando a família e os outros vínculos.',
);

/// Passo 2 — directory.search.
const staffAccessSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por nome',
  text: 'Encontre o funcionário pelo nome.',
);

/// Passo 3 — directory.filters.
const staffAccessFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Instituição, unidade e estado: livre, com horário, com vigência, afastado ou bloqueado agora.',
);

/// Passo 3b — staff-access.source-filter (origem do horário, lote 86).
const staffAccessSourceTourStep = CoeloTourStep(
  anchorId: 'staff-access.source-filter',
  title: 'Origem do horário',
  text:
      'O vínculo herda o horário do perfil de funcionário. Regra própria diferente fica "fora do padrão do perfil" e pode voltar ao padrão.',
);

/// Passo 4 — directory.view.
const staffAccessViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text: 'Na tabela você vê papel, vínculo, estado, regra e afastamentos lado a lado.',
);

/// Passo 5 — directory.body.
const staffAccessBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'O estado de cada vínculo',
  text:
      'O servidor calcula o estado agora. Abra um vínculo para definir superfícies, dias e horários, vigência e popup.',
);

/// Passo 6 — directory.pagination.
const staffAccessPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const staffAccessScreenTour = SuperadminScreenTour(
  destinationId: 'staff-access',
  steps: [
    staffAccessHeaderTourStep,
    staffAccessSearchTourStep,
    staffAccessFiltersTourStep,
    staffAccessSourceTourStep,
    staffAccessViewTourStep,
    staffAccessBodyTourStep,
    staffAccessPaginationTourStep,
  ],
);
