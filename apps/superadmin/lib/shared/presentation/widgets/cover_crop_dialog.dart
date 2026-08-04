import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

final class CoverCropResult {
  const CoverCropResult({required this.bytes, required this.scale, required this.offset});

  final Uint8List bytes;
  final double scale;
  final Offset offset;
}

/// Rectangular counterpart to [AvatarCropDialog]'s approved interaction.
final class CoverCropDialog extends StatefulWidget {
  const CoverCropDialog({required this.bytes, super.key});

  final Uint8List bytes;

  /// Approved Coelo cover ratio. New ratios require a design-system decision.
  static const aspectRatio = 16 / 9;

  @override
  State<CoverCropDialog> createState() => _CoverCropDialogState();
}

final class _CoverCropDialogState extends State<CoverCropDialog> {
  final _transformation = TransformationController();
  var _zoom = 1.0;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _reset() {
    _transformation.value = Matrix4.identity();
    setState(() => _zoom = 1);
  }

  void _setZoom(double value) {
    setState(() => _zoom = value);
    _transformation.value = Matrix4.diagonal3Values(value, value, 1);
  }

  void _apply() {
    final matrix = _transformation.value;
    Navigator.of(context).pop(
      CoverCropResult(
        bytes: widget.bytes,
        scale: matrix.entry(0, 0),
        offset: Offset(matrix.entry(0, 3), matrix.entry(1, 3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Ajustar capa',
    maxWidth: 640,
    secondaryAction: OutlinedButton(
      onPressed: Navigator.of(context).pop,
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(onPressed: _apply, child: const Text('Aplicar')),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(520.0, constraints.maxWidth);
        final height = width / CoverCropDialog.aspectRatio;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Arraste e ajuste o zoom. A área dentro do retângulo será exibida.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Redefinir recorte',
                  onPressed: _reset,
                  style:
                      IconButton.styleFrom(
                        minimumSize: const Size.square(CoeloSize.touchMin),
                        maximumSize: const Size.square(CoeloSize.touchMin),
                        shape: const CircleBorder(),
                      ).copyWith(
                        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            ClipRRect(
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              child: SizedBox(
                width: width,
                height: height,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.scrim,
                  child: InteractiveViewer(
                    key: const Key('coelo-cover-crop-view'),
                    transformationController: _transformation,
                    minScale: 1,
                    maxScale: 4,
                    boundaryMargin: EdgeInsets.zero,
                    constrained: true,
                    child: Image.memory(widget.bytes, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            Slider(
              value: _zoom,
              min: 1,
              max: 4,
              divisions: 30,
              label: '${_zoom.toStringAsFixed(1)}×',
              onChanged: _setZoom,
            ),
          ],
        );
      },
    ),
  );
}
