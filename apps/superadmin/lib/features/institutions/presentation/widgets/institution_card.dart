import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';
import 'institution_status_presentation.dart';
import '../../../../shared/data/entity_image_repository.dart';
import '../../../../shared/presentation/widgets/entity_image_view.dart';

/// Card de domínio de Instituições, baseline dos cards administrativos.
/// Largura, grade e o card Criar vêm do `CoeloAdminDirectory`; a superfície
/// (hover, foco, borda, sombra) é a `CoeloAdminInteractiveCard` compartilhada.
class InstitutionCard extends StatelessWidget {
  const InstitutionCard({required this.item, required this.onPressed, this.menu, super.key});

  /// Menu ⋯ de ciclo de vida (spec 066); nulo quando não há comando disponível.
  final Widget? menu;

  final InstitutionDirectoryItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CoeloAdminInteractiveCard(
      key: Key('institution-card-${item.id}'),
      surfaceKey: Key('institution-card-surface-${item.id}'),
      minHeight: 216,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  key: Key('institution-avatar-${item.id}'),
                  dimension: 44,
                  child: EntityImageView(
                    entity: EntityKind.institution,
                    entityId: item.id,
                    semanticLabel: 'Foto de ${item.publicName}',
                    fallback: Container(
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.initials,
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(color: colors.onSecondaryContainer),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.publicName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _location(item.district, item.city, item.state),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                ExpandableInstitutionStatusIndicator(itemId: item.id, status: item.status),
                if (menu case final menu?) ...[const SizedBox(width: CoeloSpacing.space1), menu],
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            _CardDetailRow(
              first: _CardDetail(
                key: Key('institution-card-detail-type-${item.id}'),
                icon: Icons.category_outlined,
                label: 'Tipo',
                value: item.typeName ?? 'Não informado',
              ),
              second: _CardDetail(
                key: Key('institution-card-detail-plan-${item.id}'),
                icon: Icons.sell_outlined,
                label: 'Plano',
                value: item.planName ?? 'Sem plano',
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _CardDetailRow(
              first: _CardDetail(
                key: Key('institution-card-detail-units-${item.id}'),
                icon: Icons.apartment_outlined,
                label: 'Unidades',
                value: '${item.unitsCount}',
              ),
              second: _CardDetail(
                key: Key('institution-card-detail-groups-${item.id}'),
                icon: Icons.groups_outlined,
                label: 'Turmas',
                value: '${item.groupsCount}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  const _CardDetailRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(child: second),
      ],
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.label, required this.value, super.key});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DetailIcon(icon: icon, colors: colors),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: CoeloSpacing.spaceHalf),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailIcon extends StatelessWidget {
  const _DetailIcon({required this.icon, required this.colors});

  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CoeloSpacing.space8,
      height: CoeloSpacing.space8,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
    );
  }
}

String _location(String? district, String? city, String? state) {
  if (district == null && city == null && state == null) {
    return 'Não informado';
  }
  final municipality = [city, state].whereType<String>().join('/');
  return [district, if (municipality.isNotEmpty) municipality].whereType<String>().join(', ');
}
