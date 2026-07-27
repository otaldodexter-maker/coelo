import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';
import 'institution_status_presentation.dart';

Duration _interactionDuration(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

final class InstitutionDirectoryCards extends StatelessWidget {
  const InstitutionDirectoryCards({
    required this.items,
    required this.onCreate,
    required this.onEdit,
    super.key,
  });

  final List<InstitutionDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<InstitutionDirectoryItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          key: const Key('institution-card-grid'),
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            SizedBox(
              width: cardWidth,
              child: _CreateInstitutionCard(onPressed: onCreate),
            ),
            ...items.map(
              (item) => SizedBox(
                width: cardWidth,
                child: _InstitutionCard(item: item, onPressed: () => onEdit(item)),
              ),
            ),
          ],
        );
      },
    );
  }
}

final class InstitutionCreateBanner extends StatelessWidget {
  const InstitutionCreateBanner({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('create-institution-banner'),
      width: double.infinity,
      height: CoeloSpacing.space20,
      child: _DashedAction(
        surfaceKey: const Key('create-institution-banner-surface'),
        onPressed: onPressed,
        builder: (highlighted) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CreateIcon(compact: true, highlighted: highlighted),
            const SizedBox(width: CoeloSpacing.space3),
            const Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Criar instituição'),
                  Text(
                    'Adicionar nova instituição ao sistema.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateInstitutionCard extends StatelessWidget {
  const _CreateInstitutionCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('create-institution-card'),
      constraints: const BoxConstraints(minHeight: 216),
      child: KeyedSubtree(
        key: const Key('create-institution-surface'),
        child: CoeloAdminCreateAction(
          label: 'Criar instituição',
          onPressed: onPressed,
          icon: Icons.add_business_outlined,
        ),
      ),
    );
  }
}

class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.highlighted, this.compact = false});

  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = compact ? CoeloSize.avatarMd : 56.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: _interactionDuration(context, CoeloMotion.standard),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.lerp(colors.surface, colors.primary, progress),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                colors.shadow.withValues(alpha: 0.08),
                colors.primary.withValues(alpha: 0.15),
                progress,
              )!,
              blurRadius: 8 + 4 * progress,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Color.lerp(colors.primary, colors.onPrimary, progress),
          size: compact ? CoeloSize.iconSm : CoeloSize.iconMd,
        ),
      ),
    );
  }
}

class _DashedAction extends StatefulWidget {
  const _DashedAction({required this.onPressed, required this.builder, required this.surfaceKey});

  final VoidCallback onPressed;
  final Widget Function(bool highlighted) builder;
  final Key surfaceKey;

  @override
  State<_DashedAction> createState() => _DashedActionState();
}

class _DashedActionState extends State<_DashedAction> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _highlighted = true),
      onExit: (_) => setState(() => _highlighted = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlighted = value),
        child: TweenAnimationBuilder<double>(
          key: widget.surfaceKey,
          tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
          duration: _interactionDuration(context, CoeloMotion.standard),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) => Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              boxShadow: progress == 0
                  ? const []
                  : [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.15 * progress),
                        blurRadius: 12 * progress,
                        spreadRadius: 2 * progress,
                        offset: Offset(0, 4 * progress),
                      ),
                    ],
            ),
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: Color.lerp(colors.outlineVariant, colors.primary, progress)!,
              ),
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: Center(child: widget.builder(_highlighted)),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(CoeloRadius.lg)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + CoeloSpacing.space2, metric.length)),
          paint,
        );
        distance += CoeloSpacing.space3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

class _InstitutionCard extends StatefulWidget {
  const _InstitutionCard({required this.item, required this.onPressed});

  final InstitutionDirectoryItem item;
  final VoidCallback onPressed;

  @override
  State<_InstitutionCard> createState() => _InstitutionCardState();
}

class _InstitutionCardState extends State<_InstitutionCard> {
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
                            label: 'Grupos (Turmas)',
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
