/// Tour da tela Perfis e permissões (`profiles`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const profilesHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Perfis e permissões',
  text: 'Modelos de acesso por módulo, tela e ação. Um perfil define o que cada pessoa vê e faz.',
);

/// Passo 2 — directory.leading.
const profilesLeadingTourStep = CoeloTourStep(
  anchorId: 'directory.leading',
  title: 'Perfis ou capacidades',
  text: 'Alterne entre os perfis e a lista de capacidades do Principal.',
);

/// Passo 3 — directory.search.
const profilesSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar',
  text: 'Busque um perfil pelo nome ou uma capacidade.',
);

/// Passo 4 — directory.filters.
const profilesFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Escopo',
  text: 'Filtre pelo escopo máximo do perfil.',
);

/// Passo 5 — directory.files.
const profilesFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe perfis de uma planilha ou exporte em CSV ou XLSX.',
);

/// Passo 6 — directory.tabs.
const profilesTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Domínio',
  text: 'Superadmin, instituição, unidade… cada aba mostra os perfis daquele domínio.',
);

/// Passo 7 — directory.create.
const profilesCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Criar perfil',
  text: 'Abre o formulário de um novo perfil. Em perfis existentes você pode duplicar.',
);

/// Passo 8 — directory.body.
const profilesBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Perfil, descrição, escopo máximo, vínculos e tipo. Abra para editar as permissões.',
);

const profilesScreenTour = SuperadminScreenTour(
  destinationId: 'profiles',
  steps: [
    profilesHeaderTourStep,
    profilesLeadingTourStep,
    profilesSearchTourStep,
    profilesFiltersTourStep,
    profilesFilesTourStep,
    profilesTabsTourStep,
    profilesCreateTourStep,
    profilesBodyTourStep,
  ],
);
