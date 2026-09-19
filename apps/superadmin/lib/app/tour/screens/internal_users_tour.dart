/// Tour da tela Usuários internos (`internal-users`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const internalUsersHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Usuários internos',
  text:
      'A equipe do Coelo que opera este painel.',
);

/// Passo 2 — directory.search.
const internalUsersSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text:
      'Nome, e-mail, CPF, celular ou cargo.',
);

/// Passo 3 — directory.filters.
const internalUsersFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text:
      'Perfil, Vínculo e Alcance. "Limpar filtros" volta ao início.',
);

/// Passo 4 — directory.create.
const internalUsersCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar usuário interno',
  text:
      'Abre o formulário de um novo acesso interno.',
);

/// Passo 5 — directory.body.
const internalUsersBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Perfil, escopo, situação do convite e última revisão de cada usuário.',
);

const internalUsersScreenTour = SuperadminScreenTour(
  destinationId: 'internal-users',
  steps: [
    internalUsersHeaderTourStep,
    internalUsersSearchTourStep,
    internalUsersFiltersTourStep,
    internalUsersCreateTourStep,
    internalUsersBodyTourStep,
  ],
);
