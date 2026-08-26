import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return CoeloAdminDialogShell(
      dialogKey: const Key('advanced-color-picker-dialog'),
      closeButtonKey: const Key('advanced-color-picker-close'),
      closeTooltip: 'Fechar seletor de cor',
      title: widget.title,
      maxWidth: 680,
      primaryAction: FilledButton(
        key: const Key('advanced-color-picker-apply'),
        onPressed: () => Navigator.of(context).pop(selectedColor),
        child: const Text('Usar cor'),
      ),
      secondaryAction: OutlinedButton(
        key: const Key('advanced-color-picker-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      body: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final picker = _ColorVisualPicker(
                color: color,
                onSelect: _select,
                onSaturationValueAdjusted: (saturationDelta, valueDelta) => setState(() {
                  color = color
                      .withSaturation((color.saturation + saturationDelta).clamp(0, 1))
                      .withValue((color.value + valueDelta).clamp(0, 1));
                  hexController.text = _colorHex(color.toColor());
                }),
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
    );
  }
}

final class _ColorVisualPicker extends StatefulWidget {
  const _ColorVisualPicker({
    required this.color,
    required this.onSelect,
    required this.onSaturationValueAdjusted,
    required this.onHueChanged,
  });

  final HSVColor color;
  final void Function(Offset position, Size size) onSelect;
  final void Function(double saturationDelta, double valueDelta) onSaturationValueAdjusted;
  final ValueChanged<double> onHueChanged;

  @override
  State<_ColorVisualPicker> createState() => _ColorVisualPickerState();
}

final class _ColorVisualPickerState extends State<_ColorVisualPicker> {
  static const _keyboardStep = 0.05;
  static const _hueKeyboardStep = 5.0;
  late final FocusNode _areaFocusNode;
  late final FocusNode _hueFocusNode;

  @override
  void initState() {
    super.initState();
    _areaFocusNode = FocusNode(debugLabel: 'Saturação e valor');
    _hueFocusNode = FocusNode(debugLabel: 'Matiz');
  }

  @override
  void dispose() {
    _areaFocusNode.dispose();
    _hueFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleAreaKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        widget.onSaturationValueAdjusted(-_keyboardStep, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.onSaturationValueAdjusted(_keyboardStep, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.onSaturationValueAdjusted(0, -_keyboardStep);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        widget.onSaturationValueAdjusted(0, _keyboardStep);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleHueKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowDown:
        widget.onHueChanged((widget.color.hue - _hueKeyboardStep).clamp(0, 360));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowUp:
        widget.onHueChanged((widget.color.hue + _hueKeyboardStep).clamp(0, 360));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Widget _focusRing({required Key key, required FocusNode focusNode, required Widget child}) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) => DecoratedBox(
        key: key,
        decoration: BoxDecoration(
          border: Border.all(
            color: focusNode.hasFocus ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Focus(
            key: const Key('advanced-color-picker-area'),
            focusNode: _areaFocusNode,
            onKeyEvent: _handleAreaKey,
            child: _focusRing(
              key: const Key('advanced-color-picker-area-focus-ring'),
              focusNode: _areaFocusNode,
              child: Semantics(
                label: 'Saturação e valor',
                value:
                    'Saturação ${(widget.color.saturation * 100).round()}%, valor ${(widget.color.value * 100).round()}%',
                increasedValue:
                    'Saturação ${(widget.color.saturation * 100).round()}%, valor ${((widget.color.value + _keyboardStep).clamp(0, 1) * 100).round()}%',
                decreasedValue:
                    'Saturação ${(widget.color.saturation * 100).round()}%, valor ${((widget.color.value - _keyboardStep).clamp(0, 1) * 100).round()}%',
                slider: true,
                enabled: true,
                onIncrease: () => widget.onSaturationValueAdjusted(0, _keyboardStep),
                onDecrease: () => widget.onSaturationValueAdjusted(0, -_keyboardStep),
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) {
                      _areaFocusNode.requestFocus();
                      widget.onSelect(details.localPosition, constraints.biggest);
                    },
                    onPanUpdate: (details) =>
                        widget.onSelect(details.localPosition, constraints.biggest),
                    child: CustomPaint(
                      painter: _ColorAreaPainter(hue: widget.color.hue, color: widget.color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        SizedBox(
          height: CoeloSize.touchMin,
          child: Focus(
            key: const Key('advanced-color-picker-hue'),
            focusNode: _hueFocusNode,
            onKeyEvent: _handleHueKey,
            child: _focusRing(
              key: const Key('advanced-color-picker-hue-focus-ring'),
              focusNode: _hueFocusNode,
              child: Semantics(
                label: 'Matiz',
                value: '${widget.color.hue.round()} graus',
                increasedValue:
                    '${(widget.color.hue + _hueKeyboardStep).clamp(0, 360).round()} graus',
                decreasedValue:
                    '${(widget.color.hue - _hueKeyboardStep).clamp(0, 360).round()} graus',
                slider: true,
                enabled: true,
                onIncrease: () =>
                    widget.onHueChanged((widget.color.hue + _hueKeyboardStep).clamp(0, 360)),
                onDecrease: () =>
                    widget.onHueChanged((widget.color.hue - _hueKeyboardStep).clamp(0, 360)),
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _hueFocusNode.requestFocus();
                      widget.onHueChanged(
                        (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
                      );
                    },
                    onHorizontalDragUpdate: (details) => widget.onHueChanged(
                      (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
                    ),
                    child: Center(
                      child: SizedBox(
                        height: CoeloSpacing.space6,
                        width: double.infinity,
                        child: CustomPaint(painter: _HueBarPainter(hue: widget.color.hue)),
                      ),
                    ),
                  ),
                ),
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
