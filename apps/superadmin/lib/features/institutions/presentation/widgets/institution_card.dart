import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';
import 'institution_status_presentation.dart';

Duration _interactionDuration(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Card de domínio de Instituições, baseline dos cards administrativos.
/// Largura, grade e o card Criar vêm do `CoeloAdminDirectory`.
class InstitutionCard extends StatefulWidget {
  const InstitutionCard({required this.item, required this.onPressed, super.key});

  final InstitutionDirectoryItem item;
  final VoidCallback? onPressed;

  @override
  State<InstitutionCard> createState() => _InstitutionCardState();
}

class _InstitutionCardState extends State<InstitutionCard> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = widget.item;
    return ConstrainedBox(
      key: Key('institution-card-${item.id}'),
      constraints: const BoxConstraints(minHeight: 216),
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _highlighted = value),
          child: TweenAnimationBuilder<double>(
            key: Key('institution-card-surface-${item.id}'),
            tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
            duration: _interactionDuration(context, CoeloMotion.standard),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                border: Border.all(
                  color: Color.lerp(
                    colors.outlineVariant,
                    colors.primary.withValues(alpha: 0.5),
                    progress,
                  )!,
                  width: 1 + 0.5 * progress,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      colors.shadow.withValues(alpha: 0.03),
                      colors.primary.withValues(alpha: 0.15),
                      progress,
                    )!,
                    blurRadius: 8 + 4 * progress,
                    spreadRadius: 2 * progress,
                    offset: Offset(0, 2 + 2 * progress),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
                              child: Container(
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
                            const SizedBox(width: CoeloSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.publicName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _location(item.district, item.city, item.state),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: CoeloSpacing.space2),
                            ExpandableInstitutionStatusIndicator(
                              itemId: item.id,
                              status: item.status,
                            ),
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
                ),
              ),
            ),
          ),
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
