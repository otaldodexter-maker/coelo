import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_directory_create_banner.dart';
import '../../domain/unit_directory.dart';
import 'unit_status_presentation.dart';

final class UnitDirectoryCards extends StatelessWidget {
  const UnitDirectoryCards({required this.items, this.onCreate, this.onEdit, super.key});

  final List<UnitDirectoryItem> items;
  final VoidCallback? onCreate;
  final ValueChanged<UnitDirectoryItem>? onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          key: const Key('unit-card-grid'),
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            if (onCreate != null)
              SizedBox(
                width: cardWidth,
                child: ConstrainedBox(
                  key: const Key('create-unit-card'),
                  constraints: const BoxConstraints(minHeight: 216),
                  child: CoeloAdminCreateAction(
                    label: 'Criar unidade',
                    icon: Icons.apartment_outlined,
                    onPressed: onCreate!,
                  ),
                ),
              ),
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: _UnitCard(
                  item: item,
                  onPressed: onEdit == null ? null : () => onEdit!(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class UnitCreateBanner extends StatelessWidget {
  const UnitCreateBanner({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SuperadminDirectoryCreateBanner(
      label: 'Criar unidade',
      description: 'Adicionar nova unidade ao sistema.',
      onPressed: onPressed,
      bannerKey: const Key('create-unit-banner'),
      surfaceKey: const Key('create-unit-banner-surface'),
    );
  }
}

final class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.item, required this.onPressed});

  final UnitDirectoryItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (statusBackground, statusForeground) = unitStatusColors(context, item.status);
    final card = CoeloAdminInteractiveCard(
      key: Key('unit-card-${item.id}'),
      surfaceKey: Key('unit-card-surface-${item.id}'),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.initials,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
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
                _statusIndicator(
                  label: item.status.label,
                  backgroundColor: statusBackground,
                  foregroundColor: statusForeground,
                  semanticLabel: 'Status: ${item.status.label}',
                  surfaceKey: Key('unit-status-${item.id}'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Row(
              children: [
                Text(
                  'Instituição',
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Text(
                    item.institutionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space3),
            _DetailRow(
              first: _Detail(
                icon: Icons.category_outlined,
                label: 'Tipo',
                value: _value(item.typeName),
              ),
              second: _Detail(
                icon: Icons.sell_outlined,
                label: 'Plano',
                value: item.effectivePlan.label,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _DetailRow(
              first: _Detail(
                icon: Icons.groups_outlined,
                label: 'Turmas',
                value: '${item.groupsCount}',
              ),
              second: _Detail(
                icon: Icons.local_activity_outlined,
                label: 'Atividades',
                value: '${item.activitiesCount}',
              ),
            ),
          ],
        ),
      ),
    );
    if (onPressed != null) return card;
    return Semantics(
      key: Key('unit-card-semantics-${item.id}'),
      container: true,
      explicitChildNodes: true,
      child: card,
    );
  }

  Widget _statusIndicator({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required String semanticLabel,
    required Key surfaceKey,
  }) {
    final indicator = CoeloAdminExpandableStatusIndicator(
      label: label,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      semanticLabel: semanticLabel,
      surfaceKey: surfaceKey,
    );
    if (onPressed != null) return indicator;
    return Semantics(container: true, explicitChildNodes: true, child: indicator);
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(child: second),
    ],
  );
}

final class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
        ),
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

String _location(String district, String city, String state) {
  final municipality = [city, state].where((value) => value.isNotEmpty).join('/');
  final location = [district, municipality].where((value) => value.isNotEmpty).join(', ');
  return _value(location);
}

String _value(String value) => value.isEmpty ? 'Não informado' : value;
