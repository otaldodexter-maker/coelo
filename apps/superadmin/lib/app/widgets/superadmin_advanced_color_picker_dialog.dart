import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

Future<Color?> showSuperadminAdvancedColorPicker(
  BuildContext context, {
  required Color initialColor,
  required String title,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) =>
        _SuperadminAdvancedColorPickerDialog(initialColor: initialColor, title: title),
  );
}

final class _SuperadminAdvancedColorPickerDialog extends StatefulWidget {
  const _SuperadminAdvancedColorPickerDialog({required this.initialColor, required this.title});

  final Color initialColor;
  final String title;

  @override
  State<_SuperadminAdvancedColorPickerDialog> createState() =>
      _SuperadminAdvancedColorPickerDialogState();
}

final class _SuperadminAdvancedColorPickerDialogState
    extends State<_SuperadminAdvancedColorPickerDialog> {
  late HSVColor color;
  late final TextEditingController hexController;

  @override
  void initState() {
    super.initState();
    color = HSVColor.fromColor(widget.initialColor);
    hexController = TextEditingController(text: _colorHex(color.toColor()));
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _select(Offset position, Size size) {
    setState(() {
      color = color
          .withSaturation((position.dx / size.width).clamp(0, 1))
          .withValue((1 - position.dy / size.height).clamp(0, 1));
      hexController.text = _colorHex(color.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = color.toColor();
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('advanced-color-picker-dialog'),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final picker = _ColorVisualPicker(
                color: color,
                onSelect: _select,
                onHueChanged: (hue) => setState(() {
                  color = color.withHue(hue);
                  hexController.text = _colorHex(color.toColor());
                }),
              );
              final values = _ColorValues(
                color: color,
                original: widget.initialColor,
                hexController: hexController,
                onHexChanged: (value) {
                  final parsed = _hexColor(value, fallback: color.toColor());
                  if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                    setState(() => color = HSVColor.fromColor(parsed));
                  }
                },
              );
              return compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        picker,
                        const SizedBox(height: CoeloSpacing.space4),
                        values,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: picker),
                        const SizedBox(width: CoeloSpacing.space5),
                        SizedBox(width: 180, child: values),
                      ],
                    );
            },
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('advanced-color-picker-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: FilledButton(
                key: const Key('advanced-color-picker-apply'),
                onPressed: () => Navigator.of(context).pop(selectedColor),
                child: const Text('Usar cor'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _ColorVisualPicker extends StatelessWidget {
  const _ColorVisualPicker({
    required this.color,
    required this.onSelect,
    required this.onHueChanged,
  });

  final HSVColor color;
  final void Function(Offset position, Size size) onSelect;
  final ValueChanged<double> onHueChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onPanDown: (details) => onSelect(details.localPosition, constraints.biggest),
              onPanUpdate: (details) => onSelect(details.localPosition, constraints.biggest),
              child: CustomPaint(
                key: const Key('advanced-color-picker-area'),
                painter: _ColorAreaPainter(hue: color.hue, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        SizedBox(
          height: CoeloSpacing.space6,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapDown: (details) => onHueChanged(
                (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
              ),
              onHorizontalDragUpdate: (details) => onHueChanged(
                (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
              ),
              child: CustomPaint(
                key: const Key('advanced-color-picker-hue'),
                painter: _HueBarPainter(hue: color.hue),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ColorValues extends StatelessWidget {
  const _ColorValues({
    required this.color,
    required this.original,
    required this.hexController,
    required this.onHexChanged,
  });

  final HSVColor color;
  final Color original;
  final TextEditingController hexController;
  final ValueChanged<String> onHexChanged;

  @override
  Widget build(BuildContext context) {
    final selected = color.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ColorPreview(label: 'Nova', color: selected),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: _ColorPreview(label: 'Atual', color: original),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ColorValue(label: 'H', value: '${color.hue.round()}°'),
        _ColorValue(label: 'S', value: '${(color.saturation * 100).round()}%'),
        _ColorValue(label: 'V', value: '${(color.value * 100).round()}%'),
        const Divider(height: CoeloSpacing.space5),
        _ColorValue(label: 'R', value: '${(selected.r * 255).round()}'),
        _ColorValue(label: 'G', value: '${(selected.g * 255).round()}'),
        _ColorValue(label: 'B', value: '${(selected.b * 255).round()}'),
        const SizedBox(height: CoeloSpacing.space3),
        TextField(
          key: const Key('advanced-color-picker-hex'),
          controller: hexController,
          decoration: const InputDecoration(
            labelText: 'Hexadecimal',
            prefixIcon: Icon(Icons.tag_rounded),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: onHexChanged,
        ),
      ],
    );
  }
}

final class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: CoeloSize.touchMin,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(CoeloRadius.sm),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space1),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

final class _ColorValue extends StatelessWidget {
  const _ColorValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
    child: Row(
      children: [
        SizedBox(width: CoeloSpacing.space6, child: Text(label)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.space1,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.xs),
            ),
            child: Text(value),
          ),
        ),
      ],
    ),
  );
}

String _colorHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color _hexColor(String value, {required Color fallback}) {
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return fallback;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}

final class _HueBarPainter extends CustomPainter {
  const _HueBarPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(CoeloRadius.full)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    final x = hue / 360 * size.width;
    canvas.drawCircle(
      Offset(x, size.height / 2),
      size.height / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HueBarPainter oldDelegate) => oldDelegate.hue != hue;
}

final class _ColorAreaPainter extends CustomPainter {
  const _ColorAreaPainter({required this.hue, required this.color});

  final double hue;
  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final marker = Offset(color.saturation * size.width, (1 - color.value) * size.height);
    canvas.drawCircle(marker, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_ColorAreaPainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.color != color;
}
