import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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
        'admin.interactive-card',
        'admin.expandable-status-indicator',
        'admin.flyout',
        'admin.pagination',
        'admin.single-select-field',
        'admin.toggle-field',
        'superadmin.form-action-footer',
        'superadmin.form-step-navigation',
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
        rule:
            'Instituições é a baseline obrigatória: card preserva surface sem '
            'hover cinza; status inicia como ponto e revela o texto por hover, foco ou toque.',
      ),
      _ApprovedSurface(
        keyName: 'people-directory-tabs',
        title: 'Acessos › Pessoas',
        baseline: 'Toolbar em faixa própria, tabs lineares e conteúdo com gaps tokenizados.',
        golden: 'people-segment-selector + person_directory_page_test.dart',
        rule:
            'Categorias irmãs usam tabs lineares: label e underline laranja na seleção, '
            'hover tonal sutil sem cinza e sem cápsula; não confundir com Cards/Tabela.',
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
        title: 'Criar e editar qualquer entidade',
        baseline:
            'Criar/Editar instituição é a baseline automática: stepper, conteúdo '
            'especializado, campos, uploads, responsividade e rodapé.',
        golden: 'institution_form_create_light_375.png / institution_form_edit_dark_1440.png',
        rule:
            'Etapas ficam laterais em medium/wide e viram resumo acessível no compact. '
            'Cancelar à esquerda; continuidade à direita; uma única ação preenchida. '
            'Divergência exige proposta e aprovação antes do código.',
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
        const _CanonicalInteractionPreview(),
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

final class _CanonicalInteractionPreview extends StatelessWidget {
  const _CanonicalInteractionPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    return Wrap(
      spacing: CoeloSpacing.space4,
      runSpacing: CoeloSpacing.space4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: CoeloAdminInteractiveCard(
            semanticLabel: 'Exemplo canônico de card administrativo',
            onPressed: () {},
            child: const Padding(
              padding: EdgeInsets.all(CoeloSpacing.space4),
              child: Text('Card real: surface preservada; hover/foco apenas na borda e sombra.'),
            ),
          ),
        ),
        CoeloAdminExpandableStatusIndicator(
          label: 'Ativa',
          semanticLabel: 'Status de exemplo: Ativa',
          backgroundColor: statusColors.successContainer,
          foregroundColor: statusColors.onSuccessContainer,
          surfaceKey: const Key('approved-institution-expandable-status'),
        ),
        CoeloAdminFlyout<String>(
          items: const [
            CoeloAdminFlyoutItem(
              value: 'profile',
              label: 'Perfil',
              icon: Icons.person_outline_rounded,
            ),
            CoeloAdminFlyoutItem(
              value: 'settings',
              label: 'Configurações',
              icon: Icons.settings_outlined,
            ),
            CoeloAdminFlyoutItem(
              value: 'logout',
              label: 'Sair',
              icon: Icons.logout_rounded,
              startsGroup: true,
              tone: CoeloAdminFlyoutTone.negative,
            ),
          ],
          onSelected: (_) {},
          builder: (context, controller) => OutlinedButton.icon(
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.more_horiz_rounded),
            label: const Text('Abrir flyout real'),
          ),
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
