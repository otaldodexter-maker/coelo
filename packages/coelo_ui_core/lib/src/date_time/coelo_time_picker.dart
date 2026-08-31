import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input/coelo_form_text_field.dart';

final class CoeloTimeField extends StatefulWidget {
  const CoeloTimeField({
    required this.value,
    required this.onChanged,
    this.labelText = 'Horário',
    this.enabled = true,
    super.key,
  });

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final String labelText;
  final bool enabled;

  @override
  State<CoeloTimeField> createState() => _CoeloTimeFieldState();
}

final class _CoeloTimeFieldState extends State<CoeloTimeField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'coelo-time-field');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!widget.enabled) return;
    final selected = await showCoeloTimePicker(
      context: context,
      initialValue: widget.value ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueLabel = widget.value == null ? 'Selecionar hora' : formatCoeloTime(widget.value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.labelText, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.labelText,
          value: widget.value == null ? 'Não informado' : valueLabel,
          child: TextButton(
            focusNode: _focusNode,
            onPressed: widget.enabled ? _open : null,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              backgroundColor: colors.surface,
              minimumSize: const Size.fromHeight(CoeloSize.touchMin),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space4,
                vertical: CoeloSpacing.space3,
              ),
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: Text(valueLabel)),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<TimeOfDay?> showCoeloTimePicker({
  required BuildContext context,
  required TimeOfDay initialValue,
  String title = 'Defina o horário',
}) => showDialog<TimeOfDay>(
  context: context,
  barrierColor: Colors.black54,
  builder: (context) => _CoeloTimePickerDialog(initialValue: initialValue, title: title),
);

final class _CoeloTimePickerDialog extends StatefulWidget {
  const _CoeloTimePickerDialog({required this.initialValue, required this.title});

  final TimeOfDay initialValue;
  final String title;

  @override
  State<_CoeloTimePickerDialog> createState() => _CoeloTimePickerDialogState();
}

final class _CoeloTimePickerDialogState extends State<_CoeloTimePickerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: formatCoeloTime(widget.initialValue),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  void _apply() {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_controller.text.trim());
    final hour = match == null ? 24 : int.parse(match.group(1)!);
    final minute = match == null ? 60 : int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      setState(() => _error = 'Informe um horário válido no formato HH:mm.');
      return;
    }
    Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stackActions = MediaQuery.textScalerOf(context).scale(14) >= 22;
    final cancel = TextButton(onPressed: _dismiss, child: const Text('Cancelar'));
    final apply = FilledButton(
      key: const ValueKey('coelo-time-picker-apply'),
      onPressed: _apply,
      child: const Text('Aplicar'),
    );
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _dismiss();
              return null;
            },
          ),
        },
        child: Dialog(
          key: const ValueKey('coelo-time-picker-dialog'),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(CoeloSpacing.space4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        tooltip: 'Fechar seletor de horário',
                        color: colors.error,
                        onPressed: _dismiss,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  Semantics(
                    liveRegion: _error != null,
                    child: CoeloFormTextField(
                      fieldKey: const ValueKey('coelo-time-picker-input'),
                      controller: _controller,
                      labelText: 'Horário',
                      hintText: '08:00',
                      prefixIcon: Icons.schedule_outlined,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.done,
                      errorText: _error,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onFieldSubmitted: (_) => _apply(),
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (stackActions)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        apply,
                        const SizedBox(height: CoeloSpacing.space3),
                        cancel,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: apply),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatCoeloTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
