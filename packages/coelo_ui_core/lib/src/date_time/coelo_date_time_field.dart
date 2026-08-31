import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../date_range/coelo_date_range_picker.dart';
import 'coelo_time_picker.dart';

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
    final time = await showCoeloTimePicker(
      context: context,
      initialValue: TimeOfDay(hour: widget.value?.hour ?? 8, minute: widget.value?.minute ?? 0),
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
