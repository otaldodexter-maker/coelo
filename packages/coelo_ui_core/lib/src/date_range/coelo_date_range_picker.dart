import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';

typedef CoeloSelectableDayPredicate = bool Function(DateTime day);

enum CoeloDateSelectionMode { range, single }

class CoeloDateRangeField extends StatefulWidget {
  const CoeloDateRangeField({
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.selectableDayPredicate,
    this.currentDate,
    this.enabled = true,
    this.errorText,
    this.showQuickRanges = true,
    this.labelText = 'Período',
    this.selectionMode = CoeloDateSelectionMode.range,
    super.key,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final CoeloSelectableDayPredicate? selectableDayPredicate;
  final DateTime? currentDate;
  final bool enabled;
  final String? errorText;
  final bool showQuickRanges;
  final String labelText;
  final CoeloDateSelectionMode selectionMode;

  @override
  State<CoeloDateRangeField> createState() => _CoeloDateRangeFieldState();
}

class _CoeloDateRangeFieldState extends State<CoeloDateRangeField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'coelo-date-range-field');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!widget.enabled) return;
    final result = await showCoeloDateRangePicker(
      context: context,
      value: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      selectableDayPredicate: widget.selectableDayPredicate,
      currentDate: widget.currentDate,
      showQuickRanges: widget.showQuickRanges,
      selectionMode: widget.selectionMode,
    );
    if (!mounted) return;
    if (result != widget.value) widget.onChanged(result);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.labelText,
      value: value == null
          ? widget.selectionMode == CoeloDateSelectionMode.single
                ? 'Nenhuma data selecionada'
                : 'Nenhum período selecionado'
          : widget.selectionMode == CoeloDateSelectionMode.single
          ? _full(value.start)
          : '${_full(value.start)} até ${_full(value.end)}',
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
        child: InkWell(
          onTap: widget.enabled ? _open : null,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              labelText: widget.labelText,
              errorText: widget.errorText,
              enabled: widget.enabled,
              prefixIcon: const Icon(Icons.date_range_rounded),
              suffixIcon: const Icon(Icons.expand_more_rounded),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            child: Text(
              value == null
                  ? widget.selectionMode == CoeloDateSelectionMode.single
                        ? 'Selecione uma data'
                        : 'Selecione um período'
                  : widget.selectionMode == CoeloDateSelectionMode.single
                  ? _numeric(value.start)
                  : '${_numeric(value.start)} – ${_numeric(value.end)}',
            ),
          ),
        ),
      ),
    );
  }
}

Future<DateTimeRange?> showCoeloDateRangePicker({
  required BuildContext context,
  required DateTimeRange? value,
  required DateTime firstDate,
  required DateTime lastDate,
  CoeloSelectableDayPredicate? selectableDayPredicate,
  DateTime? currentDate,
  bool showQuickRanges = true,
  CoeloDateSelectionMode selectionMode = CoeloDateSelectionMode.range,
}) async {
  final initial = _normalize(value);
  final result = await showDialog<Object?>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(CoeloSpacing.space4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: CoeloDateRangePicker(
          value: initial,
          onChanged: (next) =>
              Navigator.of(dialogContext).pop(next ?? const _ClearResult()),
          firstDate: firstDate,
          lastDate: lastDate,
          selectableDayPredicate: selectableDayPredicate,
          currentDate: currentDate,
          showQuickRanges: showQuickRanges,
          selectionMode: selectionMode,
          onDismiss: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
  return switch (result) {
    DateTimeRange range => _normalize(range),
    _ClearResult() => null,
    _ => initial,
  };
}

class CoeloDateRangePicker extends StatefulWidget {
  const CoeloDateRangePicker({
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.selectableDayPredicate,
    this.currentDate,
    this.enabled = true,
    this.errorText,
    this.showQuickRanges = true,
    this.onDismiss,
    this.selectionMode = CoeloDateSelectionMode.range,
    super.key,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final CoeloSelectableDayPredicate? selectableDayPredicate;
  final DateTime? currentDate;
  final bool enabled;
  final String? errorText;
  final bool showQuickRanges;
  final VoidCallback? onDismiss;
  final CoeloDateSelectionMode selectionMode;

  @override
  State<CoeloDateRangePicker> createState() => _CoeloDateRangePickerState();
}

class _CoeloDateRangePickerState extends State<CoeloDateRangePicker> {
  late DateTime _month;
  _CalendarView _view = _CalendarView.days;
  DateTime? _start;
  DateTime? _end;
  String? _selectionError;

  DateTime get _first => _day(widget.firstDate);
  DateTime get _last => _day(widget.lastDate);
  DateTime get _today => _day(widget.currentDate ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    final value = _normalize(widget.value);
    _start = value?.start;
    _end = value?.end;
    final anchor = value?.start ?? _today;
    _month = DateTime(anchor.year, anchor.month);
  }

  bool _selectable(DateTime value) =>
      !value.isBefore(_first) &&
      !value.isAfter(_last) &&
      (widget.selectableDayPredicate?.call(value) ?? true);

  bool _rangeAllowed(DateTime start, DateTime end) {
    for (
      var cursor = start;
      !cursor.isAfter(end);
      cursor = cursor.add(const Duration(days: 1))
    ) {
      if (!_selectable(cursor)) return false;
    }
    return true;
  }

  void _select(DateTime value) {
    if (!widget.enabled || !_selectable(value)) return;
    setState(() {
      _selectionError = null;
      if (widget.selectionMode == CoeloDateSelectionMode.single) {
        _start = value;
        _end = value;
        return;
      }
      if (_start == null || _end != null) {
        _start = value;
        _end = null;
      } else {
        final start = value.isBefore(_start!) ? value : _start!;
        final end = value.isBefore(_start!) ? _start! : value;
        _start = start;
        _end = end;
        if (!_rangeAllowed(start, end)) {
          _selectionError = 'O intervalo inclui uma data indisponível.';
        }
      }
    });
  }

  void _quick(DateTime start, DateTime end) {
    setState(() {
      _start = _day(start);
      _end = _day(end);
      _month = DateTime(start.year, start.month);
      _selectionError = _rangeAllowed(_start!, _end!)
          ? null
          : 'O intervalo inclui uma data indisponível.';
    });
  }

  void _move(int delta) {
    final next = switch (_view) {
      _CalendarView.days => DateTime(_month.year, _month.month + delta),
      _CalendarView.months => DateTime(_month.year + delta, _month.month),
      _CalendarView.years => DateTime(_month.year + (delta * 10), _month.month),
    };
    if (next.isBefore(DateTime(_first.year, _first.month)) ||
        next.isAfter(DateTime(_last.year, _last.month))) {
      return;
    }
    setState(() => _month = next);
  }

  void _advanceView() {
    setState(() {
      _view = switch (_view) {
        _CalendarView.days => _CalendarView.months,
        _CalendarView.months => _CalendarView.years,
        _CalendarView.years => _CalendarView.years,
      };
    });
  }

  String get _headerTitle => switch (_view) {
    _CalendarView.days => _title(_month),
    _CalendarView.months => '${_month.year}',
    _CalendarView.years =>
      '${(_month.year ~/ 10) * 10}–${((_month.year ~/ 10) * 10) + 9}',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = widget.errorText ?? _selectionError;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onDismiss?.call();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Material(
            color: colors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoMonths = constraints.maxWidth >= 720;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _move(-1),
                            tooltip: 'Mês anterior',
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: TextButton(
                              key: const ValueKey('coelo-date-range-title'),
                              onPressed: _view == _CalendarView.years
                                  ? null
                                  : _advanceView,
                              child: Text(
                                _headerTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _move(1),
                            tooltip: 'Próximo mês',
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                          if (widget.onDismiss != null)
                            IconButton(
                              onPressed: widget.onDismiss,
                              tooltip: 'Fechar seletor de período',
                              color: colors.error,
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      if (widget.showQuickRanges) ...[
                        const SizedBox(height: CoeloSpacing.space3),
                        _quickRanges(),
                      ],
                      const SizedBox(height: CoeloSpacing.space4),
                      switch (_view) {
                        _CalendarView.days when twoMonths => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _calendar(_month)),
                            const SizedBox(width: CoeloSpacing.space6),
                            Expanded(
                              child: _calendar(
                                DateTime(_month.year, _month.month + 1),
                              ),
                            ),
                          ],
                        ),
                        _CalendarView.days => _calendar(_month),
                        _CalendarView.months => _monthGrid(),
                        _CalendarView.years => _yearGrid(),
                      },
                      if (error != null) ...[
                        const SizedBox(height: CoeloSpacing.space3),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: CoeloSpacing.space4),
                      _actionFooter(context),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickRanges() {
    final sunday = _today.subtract(Duration(days: _today.weekday % 7));
    return Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        OutlinedButton(
          onPressed: () => _quick(_today, _today),
          child: const Text('Hoje'),
        ),
        OutlinedButton(
          onPressed: () => _quick(sunday, sunday.add(const Duration(days: 6))),
          child: const Text('Esta semana'),
        ),
        OutlinedButton(
          onPressed: () => _quick(
            DateTime(_today.year, _today.month),
            DateTime(_today.year, _today.month + 1, 0),
          ),
          child: const Text('Este mês'),
        ),
      ],
    );
  }

  Widget _actionFooter(BuildContext context) {
    final clear = TextButton(
      key: const ValueKey('coelo-date-range-clear'),
      onPressed: widget.enabled ? () => widget.onChanged(null) : null,
      child: const Text('Limpar'),
    );
    final apply = FilledButton(
      key: const ValueKey('coelo-date-range-apply'),
      onPressed:
          widget.enabled &&
              _start != null &&
              _end != null &&
              _selectionError == null
          ? () => widget.onChanged(DateTimeRange(start: _start!, end: _end!))
          : null,
      child: const Text('Aplicar'),
    );
    final compactScaled = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    if (compactScaled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          apply,
          const SizedBox(height: CoeloSpacing.space2),
          clear,
        ],
      );
    }
    return Row(children: [clear, const Spacer(), apply]);
  }

  Widget _calendar(DateTime month) => _CalendarMonth(
    key: const ValueKey('coelo-date-range-month'),
    month: month,
    today: _today,
    start: _start,
    end: _end,
    selectable: _selectable,
    onSelected: _select,
  );

  Widget _monthGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisExtent: CoeloSize.touchMin,
      crossAxisSpacing: CoeloSpacing.space2,
      mainAxisSpacing: CoeloSpacing.space2,
    ),
    itemCount: 12,
    itemBuilder: (context, index) {
      final monthNumber = index + 1;
      final enabled =
          !DateTime(_month.year, monthNumber + 1, 0).isBefore(_first) &&
          !DateTime(_month.year, monthNumber).isAfter(_last);
      return TextButton(
        key: ValueKey(
          'coelo-month-${_month.year}-${monthNumber.toString().padLeft(2, '0')}',
        ),
        onPressed: enabled
            ? () => setState(() {
                _month = DateTime(_month.year, monthNumber);
                _view = _CalendarView.days;
              })
            : null,
        child: Text(_shortMonths[index]),
      );
    },
  );

  Widget _yearGrid() {
    final decade = (_month.year ~/ 10) * 10;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: CoeloSize.touchMin,
        crossAxisSpacing: CoeloSpacing.space2,
        mainAxisSpacing: CoeloSpacing.space2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final year = decade - 1 + index;
        final enabled = year >= _first.year && year <= _last.year;
        return TextButton(
          key: ValueKey('coelo-year-$year'),
          onPressed: enabled
              ? () => setState(() {
                  _month = DateTime(year, _month.month);
                  _view = _CalendarView.months;
                })
              : null,
          child: Text('$year'),
        );
      },
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  const _CalendarMonth({
    required this.month,
    required this.today,
    required this.start,
    required this.end,
    required this.selectable,
    required this.onSelected,
    super.key,
  });
  final DateTime month;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final bool Function(DateTime) selectable;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final firstCell = first.subtract(Duration(days: first.weekday % 7));
    return Column(
      children: [
        Text(_title(month), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            for (final value in const [
              'Dom',
              'Seg',
              'Ter',
              'Qua',
              'Qui',
              'Sex',
              'Sáb',
            ])
              Expanded(child: Center(child: Text(value))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: CoeloSize.touchMin,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final value = firstCell.add(Duration(days: index));
            final selected =
                start != null &&
                (end == null
                    ? _same(value, start!)
                    : !value.isBefore(start!) && !value.isAfter(end!));
            final colors = Theme.of(context).colorScheme;
            return Semantics(
              label: _full(value),
              selected: selected,
              enabled: selectable(value),
              button: true,
              child: TextButton(
                key: ValueKey('coelo-date-${_key(value)}'),
                onPressed: selectable(value) ? () => onSelected(value) : null,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.square(CoeloSize.touchMin),
                  ),
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (selected) return colors.onPrimary;
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)) {
                      return colors.primary;
                    }
                    return value.month == month.month
                        ? colors.onSurface
                        : colors.onSurfaceVariant;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (selected) return colors.primary;
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)) {
                      return colors.primaryContainer;
                    }
                    return Colors.transparent;
                  }),
                  side: WidgetStatePropertyAll(
                    _same(value, today) && !selected
                        ? BorderSide(color: colors.primary)
                        : BorderSide.none,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CoeloRadius.full),
                    ),
                  ),
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
                child: Text('${value.day}'),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ClearResult {
  const _ClearResult();
}

enum _CalendarView { days, months, years }

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
DateTimeRange? _normalize(DateTimeRange? value) => value == null
    ? null
    : DateTimeRange(start: _day(value.start), end: _day(value.end));
bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _key(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _numeric(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _title(DateTime value) => '${_months[value.month - 1]} de ${value.year}';
String _full(DateTime value) =>
    '${value.day} de ${_months[value.month - 1].toLowerCase()} de ${value.year}';
const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
const _shortMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

@Preview(name: 'Intervalo de datas · aberto · light', size: Size(1024, 680))
Widget coeloDateRangePickerLightPreview() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: CoeloDateRangePicker(
      value: DateTimeRange(
        start: DateTime(2026, 8, 13),
        end: DateTime(2026, 8, 18),
      ),
      onChanged: (_) {},
      firstDate: DateTime(2025),
      lastDate: DateTime(2027, 12, 31),
      currentDate: DateTime(2026, 8, 13),
    ),
  ),
);

@Preview(name: 'Intervalo de datas · compacto · light', size: Size(375, 720))
Widget coeloDateRangePickerCompactPreview() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: CoeloDateRangePicker(
      value: DateTimeRange(
        start: DateTime(2026, 8, 13),
        end: DateTime(2026, 8, 18),
      ),
      onChanged: (_) {},
      firstDate: DateTime(2025),
      lastDate: DateTime(2027, 12, 31),
      currentDate: DateTime(2026, 8, 13),
    ),
  ),
);

@Preview(name: 'Intervalo de datas · aberto · dark', size: Size(1024, 680))
Widget coeloDateRangePickerDarkPreview() => MaterialApp(
  theme: CoeloTheme.dark,
  home: Scaffold(
    body: CoeloDateRangePicker(
      value: DateTimeRange(
        start: DateTime(2026, 8, 13),
        end: DateTime(2026, 8, 18),
      ),
      onChanged: (_) {},
      firstDate: DateTime(2025),
      lastDate: DateTime(2027, 12, 31),
      currentDate: DateTime(2026, 8, 13),
    ),
  ),
);

@Preview(name: 'Campo de intervalo · erro', size: Size(768, 180))
Widget coeloDateRangeFieldErrorPreview() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: CoeloDateRangeField(
        value: null,
        onChanged: (_) {},
        firstDate: DateTime(2025),
        lastDate: DateTime(2027, 12, 31),
        currentDate: DateTime(2026, 8, 13),
        errorText: 'Selecione o período do formulário.',
      ),
    ),
  ),
);
