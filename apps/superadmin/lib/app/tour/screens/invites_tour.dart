/// Tour da tela Convites (`invites`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const invitesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Convites',
  text: 'Convites de acesso enviados a responsáveis e equipe.',
);

/// Passo 2 — directory.search.
const invitesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar destinatário',
  text: 'Encontre pelo nome ou contato do destinatário.',
);

/// Passo 3 — directory.filters.
const invitesFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Canal',
  text: 'E-mail, WhatsApp ou link. "Limpar filtros" volta ao início.',
);

/// Passo 4 — directory.files.
const invitesFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe destinatários ou exporte a lista.',
);

/// Passo 5 — directory.tabs.
const invitesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Todos os convites',
  text: 'Filtre por situação do convite.',
);

/// Passo 6 — directory.create.
const invitesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Novo convite',
  text: 'Abre o formulário: destinatário, perfil, contexto e canal.',
);

/// Passo 7 — directory.body.
const invitesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Situação de cada convite; "Copiar link" copia o link de acesso.',
);

/// Passo 8 — directory.pagination.
const invitesPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const invitesScreenTour = SuperadminScreenTour(
  destinationId: 'invites',
  steps: [
    invitesHeaderTourStep,
    invitesSearchTourStep,
    invitesFiltersTourStep,
    invitesFilesTourStep,
    invitesTabsTourStep,
    invitesCreateTourStep,
    invitesBodyTourStep,
    invitesPaginationTourStep,
  ],
);
