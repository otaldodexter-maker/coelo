/// Tour da tela Segurança da criança (`safety`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const safetyHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Segurança da criança',
  text: 'Quem está autorizado a buscar cada criança, com revisão auditada pela unidade.',
);

/// Passo 2 — directory.search.
const safetySearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text: 'Nome ou identificação interna da criança.',
);

/// Passo 3 — directory.view.
const safetyViewTourStep = CoeloTourStep(
  anchorId: 'directory.view',
  title: 'Cards ou tabela',
  text: 'Escolha ver cards por criança ou a tabela agrupada.',
);

/// Passo 4 — directory.files.
const safetyFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe autorizações ou exporte em CSV.',
);

/// Passo 5 — directory.tabs.
const safetyTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Segmentos',
  text: 'Cada aba mostra a contagem: com autorização, em análise, sem autorização.',
);

/// Passo 6 — directory.create.
const safetyCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar segurança',
  text:
      'Abre o assistente de nova autorização: criança, pessoa autorizada, relação, capacidades e validade.',
);

/// Passo 7 — directory.body.
const safetyBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Cada card mostra autorizações ativas e solicitações em análise. Clique para gerenciar.',
);

/// Passo 8 — directory.pagination.
const safetyPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const safetyScreenTour = SuperadminScreenTour(
  destinationId: 'safety',
  steps: [
    safetyHeaderTourStep,
    safetySearchTourStep,
    safetyViewTourStep,
    safetyFilesTourStep,
    safetyTabsTourStep,
    safetyCreateTourStep,
    safetyBodyTourStep,
    safetyPaginationTourStep,
  ],
);
