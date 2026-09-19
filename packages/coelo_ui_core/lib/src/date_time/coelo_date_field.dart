import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../date_range/coelo_date_range_picker.dart';

/// Campo "só data" com rótulo e erro do formulário; abre o seletor Coelo de
/// data única. Para data e hora use `CoeloDateTimeField`.
final class CoeloDateField extends StatelessWidget {
  const CoeloDateField({
    required this.labelText,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.emptyLabel = 'Selecionar data',
    this.enabled = true,
    this.prefixIcon = Icons.calendar_today_outlined,
    super.key,
  });

  final String labelText;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final String emptyLabel;
  final bool enabled;
  final IconData? prefixIcon;

  static String format(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _open(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showCoeloDateRangePicker(
      context: context,
      value: value == null ? null : DateTimeRange(start: value!, end: value!),
      firstDate: firstDate ?? DateTime(today.year - 5),
      lastDate: lastDate ?? DateTime(today.year + 10, 12, 31),
      currentDate: today,
      showQuickRanges: false,
      selectionMode: CoeloDateSelectionMode.single,
    );
    if (!context.mounted || selected == null) return;
    final date = DateUtils.dateOnly(selected.start);
    if (value == null || !DateUtils.isSameDay(value, date)) onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null ? emptyLabel : format(value!);
    return Semantics(
      button: true,
      enabled: enabled,
      label: labelText,
      value: text,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            errorText: errorText,
            enabled: enabled,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
