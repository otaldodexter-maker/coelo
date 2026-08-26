import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import 'crop_rasterizer.dart';

final class AvatarCropResult {
  const AvatarCropResult({required this.bytes, required this.scale, required this.offset});

  final Uint8List bytes;
  final double scale;
  final Offset offset;
}

final class AvatarCropDialog extends StatefulWidget {
  const AvatarCropDialog({required this.bytes, this.rasterizer = rasterizeCoeloCrop, super.key});

  final Uint8List bytes;
  final CoeloCropRasterizer rasterizer;

  static const outputSize = 320;

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

final class _AvatarCropDialogState extends State<AvatarCropDialog> {
  final _previewKey = GlobalKey();
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

  Future<void> _apply() async {
    final matrix = _transformation.value;
    final viewportSize = _previewKey.currentContext?.size;
    if (viewportSize == null || viewportSize.isEmpty) return;

    final data = await widget.rasterizer(
      bytes: widget.bytes,
      viewportSize: viewportSize,
      transform: matrix,
      outputWidth: AvatarCropDialog.outputSize,
      outputHeight: AvatarCropDialog.outputSize,
    );
    if (!mounted || data == null) return;

    Navigator.of(context).pop(
      AvatarCropResult(
        bytes: data,
        scale: matrix.entry(0, 0),
        offset: Offset(matrix.entry(0, 3), matrix.entry(1, 3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Ajustar foto',
    maxWidth: 560,
    secondaryAction: OutlinedButton(
      onPressed: Navigator.of(context).pop,
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(onPressed: _apply, child: const Text('Aplicar')),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final dimension = math.min(300.0, constraints.maxWidth);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Arraste e ajuste o zoom. A área dentro do círculo será exibida.',
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
            ClipOval(
              child: RepaintBoundary(
                key: _previewKey,
                child: SizedBox.square(
                  dimension: dimension,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.scrim,
                    child: InteractiveViewer(
                      key: const Key('coelo-avatar-crop-view'),
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
