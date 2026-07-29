import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';

Map<String, CatalogFoundation> buildAdminDirectoryFoundationRegistry() {
  return {
    'pattern.admin-directory': CatalogFoundation(
      id: 'pattern.admin-directory',
      referencedComponentIds: const [
        'admin.listing-toolbar',
        'admin.file-actions',
        'admin.create-action',
        'admin.resizable-table',
        'admin.pagination',
      ],
      builder: (_) => const _AdminDirectoryFoundation(),
    ),
    'pattern.flyout-actions': CatalogFoundation(
      id: 'pattern.flyout-actions',
      referencedComponentIds: const ['admin.file-actions'],
      builder: (_) => const _FlyoutActionsFoundation(),
    ),
    'pattern.negative-actions': CatalogFoundation(
      id: 'pattern.negative-actions',
      builder: (_) => const _NegativeActionsFoundation(),
    ),
    'pattern.dialog-actions': CatalogFoundation(
      id: 'pattern.dialog-actions',
      referencedComponentIds: const ['admin.dialog-shell'],
      builder: (_) => const _DialogActionsFoundation(),
    ),
  };
}

final class _AdminDirectoryFoundation extends StatefulWidget {
  const _AdminDirectoryFoundation();

  @override
  State<_AdminDirectoryFoundation> createState() => _AdminDirectoryFoundationState();
}

final class _AdminDirectoryFoundationState extends State<_AdminDirectoryFoundation> {
  final _searchController = TextEditingController();
  var _showTable = true;
  var _page = 1;
  var _pageSize = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Instituições é a referência: toolbar, filtros, toggle, arquivos, '
          'cards ou tabela, espaçamento e paginação formam uma composição.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminListingToolbar(
          search: SizedBox(
            width: 300,
            child: CoeloSearchField(
              controller: _searchController,
              onChanged: (_) {},
              semanticLabel: 'Buscar instituições',
              hintText: 'Buscar por nome',
            ),
          ),
          filters: [OutlinedButton(onPressed: () {}, child: const Text('Todos os status'))],
          actions: [
            SegmentedButton<bool>(
              key: const Key('admin-directory-view-toggle'),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.selected) ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.selected) ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.grid_view_rounded),
                  tooltip: 'Visualizar em cards',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.view_list_rounded),
                  tooltip: 'Visualizar em tabela',
                ),
              ],
              selected: {_showTable},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  _showTable = selection.single;
                  _pageSize = _showTable ? 8 : 11;
                  _page = 1;
                });
              },
            ),
            CoeloAdminFileActions(
              actions: [
                CoeloAdminFileAction(
                  label: 'Importar',
                  icon: Icons.upload_file_rounded,
                  onPressed: () {},
                ),
                CoeloAdminFileAction(
                  label: 'Exportar CSV',
                  icon: Icons.table_rows_rounded,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (_showTable) ...[
          CoeloAdminCreateAction(
            variant: CoeloAdminCreateActionVariant.banner,
            label: 'Criar instituição',
            description: 'Adicionar nova instituição ao sistema.',
            onPressed: () {},
          ),
          const SizedBox(key: Key('admin-directory-create-table-gap'), height: CoeloSpacing.space4),
          CoeloAdminResizableTable<_DirectoryInstitution>(
            items: const [
              _DirectoryInstitution('CN', 'Casa Nuvem', 'Escola', 'Ativa'),
              _DirectoryInstitution('CB', 'Centro Bem-Te-Vi', 'Centro', 'Em implantação'),
            ],
            rowKey: (institution) => institution.name,
            pinnedColumn: CoeloAdminTableColumn(
              id: 'institution',
              label: 'Instituição',
              initialWidth: 240,
              minWidth: 180,
              maxWidth: 320,
              cellBuilder: (_, institution) =>
                  Text(institution.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            columns: [
              CoeloAdminTableColumn(
                id: 'type',
                label: 'Tipo',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 260,
                cellBuilder: (_, institution) => Text(institution.type),
              ),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Status',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 240,
                cellBuilder: (_, institution) => Text(institution.status),
              ),
            ],
            headerHeight: 56,
            rowHeight: 64,
            onRowPressed: (_) {},
          ),
        ] else
          Wrap(
            spacing: CoeloSpacing.space6,
            runSpacing: CoeloSpacing.space6,
            children: const [
              SizedBox(
                width: 340,
                height: 216,
                child: CoeloAdminCreateAction(label: 'Criar instituição', onPressed: _noop),
              ),
              _DirectoryCardPreview(),
            ],
          ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminPagination(
          currentPage: _page,
          totalPages: 4,
          pageSize: _pageSize,
          pageSizeOptions: _showTable ? const [8, 20, 50, 100] : const [11, 20, 50, 100],
          onPageSelected: (page) => setState(() => _page = page),
          onPrevious: _page == 1 ? null : () => setState(() => _page--),
          onNext: _page == 4 ? null : () => setState(() => _page++),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _page = 1;
          }),
        ),
      ],
    );
  }
}

void _noop() {}

final class _DirectoryCardPreview extends StatefulWidget {
  const _DirectoryCardPreview();

  @override
  State<_DirectoryCardPreview> createState() => _DirectoryCardPreviewState();
}

final class _DirectoryCardPreviewState extends State<_DirectoryCardPreview> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      key: const Key('admin-directory-hover-card'),
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        key: const Key('admin-directory-hover-card-container'),
        duration: CoeloMotion.standard,
        width: 340,
        height: 216,
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(
            color: _hovered ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.shadow.withValues(alpha: 0.03),
              blurRadius: _hovered ? 12 : 8,
              spreadRadius: _hovered ? 2 : 0,
              offset: Offset(0, _hovered ? 4 : 2),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CN  Casa Nuvem'),
            SizedBox(height: CoeloSpacing.space4),
            Divider(),
            SizedBox(height: CoeloSpacing.space4),
            Text('Tipo  Educação infantil'),
            Text('Plano  Essencial'),
          ],
        ),
      ),
    );
  }
}

final class _FlyoutActionsFoundation extends StatelessWidget {
  const _FlyoutActionsFoundation();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _flyoutButton(context, icon: Icons.person_outline_rounded, label: 'Perfil'),
                const SizedBox(height: CoeloSpacing.spaceHalf),
                _flyoutButton(context, icon: Icons.settings_outlined, label: 'Configurações'),
                const SizedBox(height: CoeloSpacing.space1),
                const Divider(),
                const SizedBox(height: CoeloSpacing.space1),
                _negativeButton(
                  context,
                  key: const Key('flyout-destructive-action'),
                  icon: Icons.logout_rounded,
                  label: 'Sair',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _NegativeActionsFoundation extends StatelessWidget {
  const _NegativeActionsFoundation();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      children: [
        _negativeButton(
          context,
          key: const Key('negative-close-action'),
          icon: Icons.close_rounded,
          label: 'Fechar',
        ),
        _negativeButton(
          context,
          key: const Key('negative-exit-action'),
          icon: Icons.power_settings_new_rounded,
          label: 'Encerrar',
        ),
        _negativeButton(
          context,
          key: const Key('negative-delete-action'),
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
        ),
      ],
    );
  }
}

final class _DialogActionsFoundation extends StatelessWidget {
  const _DialogActionsFoundation();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Duas ações: 50/50; a hierarquia vem do estilo.'),
          const SizedBox(height: CoeloSpacing.space2),
          _EqualDialogActions(
            actions: [
              OutlinedButton(
                key: const Key('dialog-two-cancel'),
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('dialog-two-confirm'),
                onPressed: () {},
                child: const Text('Confirmar'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space6),
          const Text('Três ações: terços iguais; nunca quebrar em 2+1.'),
          const SizedBox(height: CoeloSpacing.space2),
          _EqualDialogActions(
            actions: [
              OutlinedButton(
                key: const Key('dialog-three-cancel'),
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
              TextButton(
                key: const Key('dialog-three-save'),
                onPressed: () {},
                child: const Text('Salvar rascunho'),
              ),
              _negativeButton(
                context,
                key: const Key('dialog-three-delete'),
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _EqualDialogActions extends StatelessWidget {
  const _EqualDialogActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 560;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                SizedBox(width: double.infinity, child: actions[index]),
                if (index != actions.length - 1) const SizedBox(height: CoeloSpacing.space2),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              Expanded(child: actions[index]),
              if (index != actions.length - 1) const SizedBox(width: CoeloSpacing.space3),
            ],
          ],
        );
      },
    );
  }
}

Widget _flyoutButton(BuildContext context, {required IconData icon, required String label}) {
  final colors = Theme.of(context).colorScheme;
  return SizedBox(
    width: double.infinity,
    child: TextButton.icon(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
        alignment: Alignment.centerLeft,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
              ? colors.primary
              : colors.onSurface,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
              ? colors.primaryContainer
              : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
        ),
      ),
      onPressed: () {},
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

Widget _negativeButton(
  BuildContext context, {
  required Key key,
  required IconData icon,
  required String label,
}) {
  final colors = Theme.of(context).colorScheme;
  return TextButton.icon(
    key: key,
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
      foregroundColor: WidgetStatePropertyAll(colors.error),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
            ? colors.errorContainer
            : Colors.transparent,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
      ),
    ),
    onPressed: () {},
    icon: Icon(icon),
    label: Text(label),
  );
}

final class _DirectoryInstitution {
  const _DirectoryInstitution(this.initials, this.name, this.type, this.status);

  final String initials;
  final String name;
  final String type;
  final String status;
}
