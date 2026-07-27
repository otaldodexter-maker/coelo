import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';

Map<String, CatalogFoundation> buildSurfaceInteractionFoundationRegistry() {
  return {
    'pattern.overlay-surfaces': CatalogFoundation(
      id: 'pattern.overlay-surfaces',
      referencedComponentIds: const ['admin.multi-select-filter'],
      builder: (_) => const _OverlaySurfacesFoundation(),
    ),
    'pattern.interaction-states': CatalogFoundation(
      id: 'pattern.interaction-states',
      referencedComponentIds: const ['admin.multi-select-filter'],
      builder: (_) => const _InteractionStatesFoundation(),
    ),
    'admin.resizable-table': CatalogFoundation(
      id: 'admin.resizable-table',
      referencedComponentIds: const ['admin.resizable-table', 'core.status-chip'],
      builder: (_) => const _InstitutionsTableFoundation(),
    ),
  };
}

final class _OverlaySurfacesFoundation extends StatelessWidget {
  const _OverlaySurfacesFoundation();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popups usam a superfície neutra do tema; a cor de marca pertence à ação e aos estados.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        FilledButton(
          key: const Key('surface-interaction-open-dialog'),
          onPressed: () => _openDialog(context),
          child: const Text('Abrir popup de demonstração'),
        ),
      ],
    );
  }

  void _openDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Popup Coelo', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      key: const Key('surface-interaction-close'),
                      tooltip: 'Fechar demonstração',
                      constraints: const BoxConstraints.tightFor(
                        width: CoeloSize.touchMin,
                        height: CoeloSize.touchMin,
                      ),
                      style: ButtonStyle(
                        foregroundColor: WidgetStatePropertyAll(colors.error),
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)) {
                            return colors.errorContainer;
                          }
                          return Colors.transparent;
                        }),
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        shape: const WidgetStatePropertyAll(CircleBorder()),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space3),
                const Text('O conteúdo contextual permanece legível nos temas claro e escuro.'),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _InteractionStatesFoundation extends StatefulWidget {
  const _InteractionStatesFoundation();

  @override
  State<_InteractionStatesFoundation> createState() => _InteractionStatesFoundationState();
}

final class _InteractionStatesFoundationState extends State<_InteractionStatesFoundation> {
  final MenuController _singleSelectController = MenuController();
  var _singleSelection = 'Estrutura';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ações de marca — primária, tonal e envio antecipado'),
        const SizedBox(height: CoeloSpacing.space2),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('surface-interaction-primary-action'),
              style: _primaryActionStyle(colors),
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova conversa'),
            ),
            ActionChip(
              key: const Key('surface-interaction-tonal-action'),
              avatar: const Icon(Icons.arrow_outward_rounded, size: 18),
              label: const Text('Como cadastro uma instituição?'),
              color: WidgetStatePropertyAll(colors.primaryContainer),
              backgroundColor: colors.primaryContainer,
              labelStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer),
              iconTheme: IconThemeData(color: colors.primary),
              side: BorderSide(color: colors.outlineVariant),
              surfaceTintColor: Colors.transparent,
              onPressed: () {},
            ),
            IconButton.filled(
              key: const Key('surface-interaction-send-action'),
              tooltip: 'Escreva uma mensagem para enviar',
              onPressed: null,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(CoeloSize.touchMin),
                fixedSize: const Size.square(CoeloSize.touchMin),
                padding: EdgeInsets.zero,
                disabledBackgroundColor: colors.primaryContainer,
                disabledForegroundColor: colors.onPrimaryContainer,
                overlayColor: Colors.transparent,
              ),
              icon: const SizedBox.square(
                key: Key('surface-interaction-send-icon-box'),
                dimension: CoeloSize.iconMd,
                child: Center(child: Icon(Icons.send_rounded)),
              ),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space5),
        const Text('Item discreto — navegação, menu ou lista de ações'),
        const SizedBox(height: CoeloSpacing.space2),
        TextButton(
          key: const Key('surface-interaction-discrete-item'),
          style: _discreteItemStyle(colors),
          onPressed: () {},
          child: const Align(alignment: Alignment.centerLeft, child: Text('Configurações')),
        ),
        const SizedBox(
          key: Key('surface-interaction-discrete-gap'),
          height: CoeloSpacing.spaceHalf,
        ),
        TextButton(
          style: _discreteItemStyle(colors),
          onPressed: () {},
          child: const Align(alignment: Alignment.centerLeft, child: Text('Permissões')),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        const Text('Linhas contínuas — filtro e tabela densa'),
        const SizedBox(height: CoeloSpacing.space2),
        TextButton(
          key: const Key('surface-interaction-continuous-filter-row'),
          style: _continuousRowStyle(colors),
          onPressed: () {},
          child: const Align(alignment: Alignment.centerLeft, child: Text('Ativa')),
        ),
        TextButton(
          key: const Key('surface-interaction-continuous-table-row'),
          style: _continuousRowStyle(colors),
          onPressed: () {},
          child: const Align(alignment: Alignment.centerLeft, child: Text('Centro Horizonte')),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        const Text('Single-select — popup de Bug'),
        const SizedBox(height: CoeloSpacing.space2),
        MenuAnchor(
          controller: _singleSelectController,
          alignmentOffset: const Offset(0, CoeloSpacing.space1),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surface),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          menuChildren: [
            for (final option in const ['Estrutura', 'Instituições', 'Unidades', 'Grupos'])
              MenuItemButton(
                onPressed: () {
                  setState(() => _singleSelection = option);
                  _singleSelectController.close();
                },
                style: _singleSelectOptionStyle(colors, selected: option == _singleSelection),
                child: Text(option),
              ),
          ],
          builder: (context, controller, child) => OutlinedButton(
            key: const Key('surface-interaction-single-select-trigger'),
            style:
                OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                  shape: const StadiumBorder(),
                ).copyWith(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.onSurfaceVariant;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return controller.isOpen ? colors.primaryContainer : Colors.transparent;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    final active =
                        controller.isOpen ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused);
                    return BorderSide(color: active ? colors.primary : colors.outlineVariant);
                  }),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              children: [
                Expanded(child: Text(_singleSelection)),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _InstitutionsTableFoundation extends StatelessWidget {
  const _InstitutionsTableFoundation();

  @override
  Widget build(BuildContext context) {
    const institutions = [
      _ExampleInstitution(
        initials: 'CH',
        name: 'Centro Horizonte',
        type: 'Terapia Ocupacional',
        units: '1',
        groups: '6',
        plan: 'Profissional',
        status: _InstitutionStatus.implementation,
        email: 'contato@horizonte.coelo.me',
      ),
      _ExampleInstitution(
        initials: 'CA',
        name: 'Colégio Maré Alta',
        type: 'Colégio',
        units: '4',
        groups: '36',
        plan: 'Completo',
        status: _InstitutionStatus.active,
        email: 'contato@mare-alta.coelo.me',
      ),
      _ExampleInstitution(
        initials: 'CR',
        name: 'Colégio Raízes',
        type: 'Colégio',
        units: '2',
        groups: '35',
        plan: 'Completo',
        status: _InstitutionStatus.archived,
        email: 'contato@raizes.coelo.me',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tabela de Instituições: coluna visual fixa, dados truncados, status semântico e ação compacta.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminResizableTable<_ExampleInstitution>(
          items: institutions,
          rowKey: (institution) => institution.name,
          pinnedColumn: CoeloAdminTableColumn(
            id: 'institution',
            label: 'Instituição',
            initialWidth: 220,
            minWidth: 160,
            maxWidth: 320,
            cellBuilder: (context, institution) => Row(
              children: [
                CircleAvatar(
                  radius: CoeloSpacing.space2,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(institution.initials, style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(child: _ellipsis(institution.name)),
              ],
            ),
          ),
          columns: [
            _textColumn('type', 'Tipo', 190, (institution) => institution.type),
            _textColumn('units', 'Unidades', 100, (institution) => institution.units),
            _textColumn('groups', 'Grupos', 100, (institution) => institution.groups),
            _textColumn('plan', 'Plano', 150, (institution) => institution.plan),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 155,
              minWidth: 130,
              maxWidth: 220,
              cellBuilder: (_, institution) => _InstitutionStatusChip(status: institution.status),
            ),
            CoeloAdminTableColumn(
              id: 'email',
              label: 'E-mail',
              initialWidth: 250,
              minWidth: 180,
              maxWidth: 360,
              cellBuilder: (_, institution) => Row(
                children: [
                  Expanded(child: _ellipsis(institution.email)),
                  const SizedBox(width: CoeloSpacing.space1),
                  Tooltip(
                    message: 'Copiar e-mail',
                    child: IconButton(
                      tooltip: 'Copiar e-mail',
                      onPressed: () {},
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
          headerHeight: CoeloSize.touchMin,
          rowHeight: 64,
          onRowPressed: (_) {},
          isSelected: (institution) => institution.status == _InstitutionStatus.implementation,
        ),
      ],
    );
  }
}

CoeloAdminTableColumn<_ExampleInstitution> _textColumn(
  String id,
  String label,
  double width,
  String Function(_ExampleInstitution institution) value,
) {
  return CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: width - CoeloSpacing.space8,
    maxWidth: width + CoeloBreakpoints.compact.minWidth,
    cellBuilder: (_, institution) => _ellipsis(value(institution)),
  );
}

Widget _ellipsis(String value) =>
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);

ButtonStyle _primaryActionStyle(ColorScheme colors) {
  return FilledButton.styleFrom(
    backgroundColor: colors.primary,
    foregroundColor: colors.onPrimary,
    disabledBackgroundColor: colors.surfaceContainer,
    disabledForegroundColor: colors.onSurfaceVariant,
    overlayColor: Colors.transparent,
  );
}

ButtonStyle _discreteItemStyle(ColorScheme colors) {
  return TextButton.styleFrom(
    minimumSize: const Size.fromHeight(CoeloSize.touchMin),
    alignment: Alignment.centerLeft,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primary
          : colors.onSurface;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primaryContainer
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

ButtonStyle _continuousRowStyle(ColorScheme colors) {
  return TextButton.styleFrom(
    minimumSize: const Size.fromHeight(CoeloSize.touchMin),
    alignment: Alignment.centerLeft,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primary
          : colors.onSurface;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primaryContainer
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

ButtonStyle _singleSelectOptionStyle(ColorScheme colors, {required bool selected}) {
  return MenuItemButton.styleFrom(minimumSize: const Size.fromHeight(CoeloSize.touchMin)).copyWith(
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final active =
          selected || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return active ? colors.primary : colors.onSurface;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final active =
          selected || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return active ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

final class _InstitutionStatusChip extends StatelessWidget {
  const _InstitutionStatusChip({required this.status});

  final _InstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CoeloStatusColors>()!;
    final statusColors = switch (status) {
      _InstitutionStatus.active => (colors.successContainer, colors.onSuccessContainer),
      _InstitutionStatus.implementation => (colors.infoContainer, colors.onInfoContainer),
      _InstitutionStatus.archived => (
        Theme.of(context).colorScheme.surfaceContainer,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return CoeloStatusChip(
      label: status.label,
      backgroundColor: statusColors.$1,
      foregroundColor: statusColors.$2,
      icon: status.icon,
    );
  }
}

enum _InstitutionStatus {
  active('Ativa', Icons.check_circle_outline),
  implementation('Em implantação', Icons.timelapse_rounded),
  archived('Arquivada', Icons.archive_outlined);

  const _InstitutionStatus(this.label, this.icon);

  final String label;
  final IconData icon;
}

final class _ExampleInstitution {
  const _ExampleInstitution({
    required this.initials,
    required this.name,
    required this.type,
    required this.units,
    required this.groups,
    required this.plan,
    required this.status,
    required this.email,
  });

  final String initials;
  final String name;
  final String type;
  final String units;
  final String groups;
  final String plan;
  final _InstitutionStatus status;
  final String email;
}
