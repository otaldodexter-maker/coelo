import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloCalendarEventMarker {
  const CoeloCalendarEventMarker({
    required this.id,
    required this.date,
    required this.semanticLabel,
  });

  final String id;
  final DateTime date;
  final String semanticLabel;
}

final class CoeloCalendarMonth extends StatelessWidget {
  const CoeloCalendarMonth({
    required this.displayedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    this.onPreviousMonth,
    this.onNextMonth,
    this.compact = false,
    super.key,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final List<CoeloCalendarEventMarker> events;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final bool compact;

  static const _months = <String>[
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
  static const _weekdays = <String>['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(displayedMonth.year, displayedMonth.month);
    final lastDay = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    final totalCells = ((leading + lastDay + 6) ~/ 7) * 7;
    final byDay = <int, List<CoeloCalendarEventMarker>>{};
    for (final event in events) {
      if (event.date.year == displayedMonth.year && event.date.month == displayedMonth.month) {
        byDay.putIfAbsent(event.date.day, () => []).add(event);
      }
    }
    return Semantics(
      container: true,
      label: 'Calendário de ${_months[displayedMonth.month - 1]} de ${displayedMonth.year}',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('coelo-calendar-previous-month'),
                    tooltip: 'Mês anterior',
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[displayedMonth.month - 1]} de ${displayedMonth.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    key: const Key('coelo-calendar-next-month'),
                    tooltip: 'Próximo mês',
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space2),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                childAspectRatio: compact ? .85 : 1,
                children: [
                  for (final weekday in _weekdays)
                    Center(child: Text(weekday, style: Theme.of(context).textTheme.labelMedium)),
                  for (var index = 0; index < totalCells; index++)
                    if (index < leading || index >= leading + lastDay)
                      const SizedBox.shrink()
                    else
                      _CalendarDay(
                        date: DateTime(
                          displayedMonth.year,
                          displayedMonth.month,
                          index - leading + 1,
                        ),
                        selected: _sameDay(
                          selectedDate,
                          DateTime(displayedMonth.year, displayedMonth.month, index - leading + 1),
                        ),
                        events: byDay[index - leading + 1] ?? const [],
                        onSelected: onDateSelected,
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

final class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.selected,
    required this.events,
    required this.onSelected,
  });

  final DateTime date;
  final bool selected;
  final List<CoeloCalendarEventMarker> events;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final eventLabels = events.map((event) => event.semanticLabel).join(', ');
    return Semantics(
      label:
          '${date.day} de ${CoeloCalendarMonth._months[date.month - 1]} de ${date.year}${eventLabels.isEmpty ? '' : ', $eventLabels'}',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey(
          'coelo-calendar-day-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        ),
        borderRadius: BorderRadius.circular(CoeloRadius.full),
        onTap: () => onSelected(date),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoeloSize.touchMin,
              minHeight: CoeloSize.touchMin,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.primary : colors.surface.withValues(alpha: 0),
              border: events.isEmpty ? null : Border.all(color: colors.primary, width: 2),
            ),
            child: Text(
              '${date.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontWeight: selected || events.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;
