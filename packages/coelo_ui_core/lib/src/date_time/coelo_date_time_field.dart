import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../date_range/coelo_date_range_picker.dart';
import '../input/coelo_form_text_field.dart';

final class CoeloDateTimeField extends StatefulWidget {
  const CoeloDateTimeField({
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.labelText = 'Data e hora',
    this.currentDate,
    this.enabled = true,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final String labelText;
  final bool enabled;

  @override
  State<CoeloDateTimeField> createState() => _CoeloDateTimeFieldState();
}

final class _CoeloDateTimeFieldState extends State<CoeloDateTimeField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'coelo-date-time-field');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!widget.enabled) return;
    final anchor = widget.value ?? widget.currentDate ?? DateTime.now();
    final selected = await showCoeloDateRangePicker(
      context: context,
      value: DateTimeRange(start: anchor, end: anchor),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      currentDate: widget.currentDate,
      showQuickRanges: false,
      selectionMode: CoeloDateSelectionMode.single,
    );
    if (!mounted || selected == null) {
      _focusNode.requestFocus();
      return;
    }
    final time = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => _CoeloTimeDialog(
        initialValue: TimeOfDay(hour: widget.value?.hour ?? 8, minute: widget.value?.minute ?? 0),
      ),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (time == null) return;
    widget.onChanged(
      DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.labelText,
      value: widget.value == null ? 'Publicar agora' : _full(widget.value!),
      child: FocusableActionDetector(
        focusNode: _focusNode,
        enabled: widget.enabled,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: TextButton(
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
              const Icon(Icons.calendar_today_outlined),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Text(widget.value == null ? 'Publicar agora' : _numeric(widget.value!)),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CoeloTimeDialog extends StatefulWidget {
  const _CoeloTimeDialog({required this.initialValue});
  final TimeOfDay initialValue;
  @override
  State<_CoeloTimeDialog> createState() => _CoeloTimeDialogState();
}

final class _CoeloTimeDialogState extends State<_CoeloTimeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _formatTime(widget.initialValue),
  );
  String? error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_controller.text.trim());
    final hour = match == null ? 24 : int.parse(match.group(1)!);
    final minute = match == null ? 60 : int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      setState(() => error = 'Informe um horário válido no formato HH:mm.');
      return;
    }
    Navigator.pop(context, TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Defina o horário', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Fechar seletor de horário',
                    color: colors.error,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: _controller,
                labelText: 'Horário',
                hintText: '08:00',
                prefixIcon: Icons.schedule_outlined,
                keyboardType: TextInputType.datetime,
                errorText: error,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onFieldSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: FilledButton(onPressed: _apply, child: const Text('Aplicar')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
String _numeric(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _full(DateTime value) =>
    '${value.day} de ${_months[value.month - 1]} de ${value.year}, às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
