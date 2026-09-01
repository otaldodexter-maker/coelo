import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Lightweight map preview for address forms. It deliberately has no API key
/// and grants no location authority; the persisted address remains canonical.
final class SuperadminLocationMapPreview extends StatelessWidget {
  const SuperadminLocationMapPreview({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = address.trim().isEmpty ? 'Preencha o endereço para localizar no mapa.' : address;
    return Semantics(
      label: 'Mapa da localização. $label',
      child: Container(
        key: const Key('superadmin-location-map'),
        height: 180,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapGridPainter(colors.outlineVariant)),
            Center(
              child: Container(
                padding: const EdgeInsets.all(CoeloSpacing.space2),
                decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                child: Icon(Icons.location_on_rounded, color: colors.onPrimary),
              ),
            ),
            PositionedDirectional(
              start: CoeloSpacing.space3,
              end: CoeloSpacing.space3,
              bottom: CoeloSpacing.space3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space3,
                  vertical: CoeloSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MapGridPainter extends CustomPainter {
  const _MapGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var x = -size.height; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    for (var y = 28.0; y < size.height; y += 42) {
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => oldDelegate.color != color;
}
