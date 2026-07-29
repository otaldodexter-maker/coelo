import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';

Map<String, CatalogFoundation> buildApprovedSuperadminFoundationRegistry() {
  return {
    'pattern.approved-superadmin-surfaces': CatalogFoundation(
      id: 'pattern.approved-superadmin-surfaces',
      referencedComponentIds: const [
        'core.form-text-field',
        'core.search-field',
        'admin.listing-toolbar',
        'admin.file-actions',
        'admin.dialog-shell',
        'admin.pagination',
      ],
      builder: (_) => const _ApprovedSuperadminSurfacesFoundation(),
    ),
  };
}

final class _ApprovedSuperadminSurfacesFoundation extends StatelessWidget {
  const _ApprovedSuperadminSurfacesFoundation();

  @override
  Widget build(BuildContext context) {
    const surfaces = <_ApprovedSurface>[
      _ApprovedSurface(
        keyName: 'login',
        title: 'Login',
        baseline: 'Campos default/foco, checkbox, ação principal default/hover, link e aviso.',
        golden: 'superadmin_login_light.png',
        rule: 'Foco primário sem preenchimento tonal; botão permanece laranja no hover.',
      ),
      _ApprovedSurface(
        keyName: 'institutions',
        title: 'Instituições',
        baseline: 'Toolbar, filtros, toggle, arquivos, cards, tabela, gaps e paginação.',
        golden: 'institution_directory_*_light_1440.png',
        rule: 'Card hover preserva surface; linha hover é contínua e sem raio.',
      ),
      _ApprovedSurface(
        keyName: 'home',
        title: 'Home',
        baseline: 'Conversas à esquerda, ajuda central, sugestões e compositor inferior.',
        golden: 'help_center_empty_light_1440.png',
        rule: 'Sugestões são tonais; envio preserva a hierarquia primária.',
      ),
      _ApprovedSurface(
        keyName: 'navigation',
        title: 'Menu e flyouts',
        baseline: 'Menu expandido, rail compacto, seleção por nível, Tour, Acessos e Conta.',
        golden: 'institution_directory_collapsed_flyout_hover_light_1024.png',
        rule: 'Item discreto tem hover arredondado; flyout inteiro permanece surface.',
      ),
      _ApprovedSurface(
        keyName: 'account',
        title: 'Perfil e Configurações',
        baseline: 'Cards, formulário, acesso, segurança, tema, movimento e rodapé.',
        golden: 'profile_* / settings_*',
        rule: 'Rodapé de tela usa extremos; tema segmentado tem três partes iguais.',
      ),
      _ApprovedSurface(
        keyName: 'overlays',
        title: 'Popups',
        baseline: 'Bug e ajuste de foto: superfície neutra, X vermelho e ações proporcionais.',
        golden: '*_bug_open_light_1440.png',
        rule: 'Dialog: 1 = 100%, 2 = 50/50, 3 = terços; X usa error/errorContainer.',
      ),
      _ApprovedSurface(
        keyName: 'institution-form',
        title: 'Criar e editar instituição',
        baseline: 'Stepper lateral, conteúdo especializado, campos, uploads e rodapé.',
        golden: 'institution_form_create_light_375.png / institution_form_edit_dark_1440.png',
        rule: 'Cancelar à esquerda; continuidade à direita; uma única ação preenchida.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Baselines aprovadas do Superadmin. Use o golden como evidência visual '
          'e os componentes/tokens como implementação canônica.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth
                ? 3
                : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                ? 2
                : 1;
            final gap = CoeloSpacing.space4;
            final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final surface in surfaces)
                  SizedBox(
                    width: width,
                    child: _ApprovedSurfaceCard(surface: surface),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

final class _ApprovedSurfaceCard extends StatelessWidget {
  const _ApprovedSurfaceCard({required this.surface});

  final _ApprovedSurface surface;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: Key('approved-surface-${surface.keyName}'),
      margin: EdgeInsets.zero,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(surface.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            Text(surface.baseline),
            const SizedBox(height: CoeloSpacing.space3),
            Text('Golden aprovado', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: CoeloSpacing.space1),
            SelectableText(surface.golden),
            const Divider(height: CoeloSpacing.space6),
            Text(surface.rule),
          ],
        ),
      ),
    );
  }
}

final class _ApprovedSurface {
  const _ApprovedSurface({
    required this.keyName,
    required this.title,
    required this.baseline,
    required this.golden,
    required this.rule,
  });

  final String keyName;
  final String title;
  final String baseline;
  final String golden;
  final String rule;
}
