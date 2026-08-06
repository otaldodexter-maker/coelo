import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';
import 'agenda_module_shell.dart';

enum AgendaCalendarView { month, week, day, agenda }

extension on AgendaCalendarView {
  String get label => switch (this) {
    AgendaCalendarView.month => 'Mês',
    AgendaCalendarView.week => 'Semana',
    AgendaCalendarView.day => 'Dia',
    AgendaCalendarView.agenda => 'Agenda',
  };
}

final class AgendaCalendarPage extends StatefulWidget {
  const AgendaCalendarPage({
    required this.store,
    required this.logout,
    required this.onAreaSelected,
    required this.onCreateItem,
    this.onDestinationSelected,
    super.key,
  });

  final AgendaPrototypeStore store;
  final LogoutAction logout;
  final ValueChanged<AgendaModuleArea> onAreaSelected;
  final VoidCallback onCreateItem;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<AgendaCalendarPage> createState() => _AgendaCalendarPageState();
}

class _AgendaCalendarPageState extends State<AgendaCalendarPage> {
  late DateTime _anchor;
  AgendaCalendarView? _view;
  AgendaOccurrence? _selected;
  String _institution = 'Todas as instituições';
  String _perspective = 'Superadmin · todos os contextos';

  @override
  void initState() {
    super.initState();
    _anchor = widget.store.referenceDate;
  }

  @override
  Widget build(BuildContext context) => AgendaModuleShell(
    logout: widget.logout,
    selectedArea: AgendaModuleArea.calendar,
    onAreaSelected: widget.onAreaSelected,
    onDestinationSelected: widget.onDestinationSelected,
    actions: [
      FilledButton.icon(
        key: const Key('agenda-create-item'),
        onPressed: widget.onCreateItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Criar item'),
      ),
    ],
    compactActions: [
      IconButton.filled(
        tooltip: 'Criar item',
        onPressed: widget.onCreateItem,
        icon: const Icon(Icons.add_rounded),
      ),
    ],
    child: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final view = _view ?? (compact ? AgendaCalendarView.agenda : AgendaCalendarView.month);
          final occurrences = _visibleOccurrences(view);
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space4,
              0,
              CoeloSpacing.space4,
              CoeloSpacing.space4,
            ),
            child: CoeloAdminWorkspaceLayout(
              toolbar: _toolbar(view, compact),
              body: _calendarBody(view, occurrences, compact),
              detail: _selected == null
                  ? null
                  : _AgendaDetail(
                      occurrence: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
              detailVisible: !compact && _selected != null,
            ),
          );
        },
      ),
    ),
  );

  Widget _toolbar(AgendaCalendarView view, bool compact) {
    final institutions = <String>{
      'Todas as instituições',
      ...widget.store.items.map((item) => item.audience.institutionId),
    }.toList(growable: false);
    if (!institutions.contains(_institution)) _institution = institutions.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodHeader(
            label: _periodLabel(view),
            onToday: () => setState(() => _anchor = widget.store.referenceDate),
            onPrevious: () => _movePeriod(view, -1),
            onNext: () => _movePeriod(view, 1),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          SegmentedButton<AgendaCalendarView>(
            key: const Key('agenda-view-selector'),
            showSelectedIcon: false,
            segments: [
              for (final option in AgendaCalendarView.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {view},
            onSelectionChanged: (selection) => setState(() {
              _view = selection.single;
              _selected = null;
            }),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminListingToolbar(
            search: SizedBox(
              width: compact ? double.infinity : 250,
              child: CoeloAdminSingleSelectField<String>(
                label: 'Perspectiva',
                value: _perspective,
                options: const [
                  'Superadmin · todos os contextos',
                  'Responsável · Ana Martins',
                  'Criança · Lia',
                  'Criança · Caio',
                ],
                optionLabel: (value) => value,
                onChanged: (value) => setState(() => _perspective = value),
                prefixIcon: Icons.visibility_outlined,
              ),
            ),
            filters: [
              SizedBox(
                width: compact ? double.infinity : 230,
                child: CoeloAdminSingleSelectField<String>(
                  label: 'Instituição',
                  value: _institution,
                  options: institutions,
                  optionLabel: (value) => value,
                  onChanged: (value) => setState(() {
                    _institution = value;
                    _selected = null;
                  }),
                  prefixIcon: Icons.apartment_rounded,
                ),
              ),
            ],
            actions: const [],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            _contextSummary,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String get _contextSummary => _perspective.startsWith('Responsável')
      ? 'Todos os filhos · Lia (Colégio Horizonte) e Caio (Instituto Caminhos)'
      : _perspective.startsWith('Criança')
      ? 'Privacidade simulada · aniversários autorizados da turma'
      : 'Contexto hierárquico ativo · $_institution';

  List<AgendaOccurrence> _visibleOccurrences(AgendaCalendarView view) {
    final range = _range(view);
    final all = widget.store.occurrencesBetween(range.$1, range.$2);
    return all
        .where((occurrence) {
          if (_institution != 'Todas as instituições' &&
              occurrence.item.audience.institutionId != _institution) {
            return false;
          }
          if (_perspective.endsWith('Lia')) {
            return occurrence.item.audience.personIds.contains('person-lia') ||
                occurrence.item.audience.personIds.isEmpty;
          }
          if (_perspective.endsWith('Caio')) {
            return occurrence.item.audience.personIds.contains('person-caio') ||
                occurrence.item.audience.personIds.isEmpty;
          }
          return true;
        })
        .toList(growable: false)
      ..sort(AgendaOccurrence.compareChronologically);
  }

  (DateTime, DateTime) _range(AgendaCalendarView view) => switch (view) {
    AgendaCalendarView.month => (
      DateTime(_anchor.year, _anchor.month, 1),
      DateTime(_anchor.year, _anchor.month + 1, 1),
    ),
    AgendaCalendarView.week => (
      _startOfWeek(_anchor),
      _startOfWeek(_anchor).add(const Duration(days: 7)),
    ),
    AgendaCalendarView.day => (_day(_anchor), _day(_anchor).add(const Duration(days: 1))),
    AgendaCalendarView.agenda => (_day(_anchor), _day(_anchor).add(const Duration(days: 31))),
  };

  Widget _calendarBody(AgendaCalendarView view, List<AgendaOccurrence> occurrences, bool compact) =>
      switch (view) {
        AgendaCalendarView.month => _MonthView(
          anchor: _anchor,
          occurrences: occurrences,
          compact: compact,
          selected: _selected,
          onSelected: _select,
        ),
        AgendaCalendarView.week => _WeekView(
          anchor: _anchor,
          occurrences: occurrences,
          compact: compact,
          onSelected: _select,
        ),
        AgendaCalendarView.day => _OccurrenceList(
          occurrences: occurrences,
          emptyLabel: 'Nenhum item neste dia.',
          onSelected: _select,
          showDate: false,
        ),
        AgendaCalendarView.agenda => _OccurrenceList(
          occurrences: occurrences,
          emptyLabel: 'Nenhum item nos próximos 31 dias.',
          onSelected: _select,
          showDate: true,
        ),
      };

  void _select(AgendaOccurrence occurrence) => setState(() => _selected = occurrence);

  void _movePeriod(AgendaCalendarView view, int direction) => setState(() {
    _selected = null;
    _anchor = switch (view) {
      AgendaCalendarView.month => DateTime(_anchor.year, _anchor.month + direction, _anchor.day),
      AgendaCalendarView.week => _anchor.add(Duration(days: 7 * direction)),
      AgendaCalendarView.day => _anchor.add(Duration(days: direction)),
      AgendaCalendarView.agenda => _anchor.add(Duration(days: 31 * direction)),
    };
  });

  String _periodLabel(AgendaCalendarView view) => switch (view) {
    AgendaCalendarView.month => '${_monthName(_anchor.month)} de ${_anchor.year}',
    AgendaCalendarView.week =>
      '${_shortDate(_startOfWeek(_anchor))} – ${_shortDate(_startOfWeek(_anchor).add(const Duration(days: 6)))}',
    AgendaCalendarView.day => _longDate(_anchor),
    AgendaCalendarView.agenda => 'Próximos 31 dias',
  };
}

final class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.label,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });
  final String label;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: Theme.of(context).textTheme.titleLarge)),
      TextButton(onPressed: onToday, child: const Text('Hoje')),
      IconButton(
        tooltip: 'Período anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Próximo período',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

final class _MonthView extends StatefulWidget {
  const _MonthView({
    required this.anchor,
    required this.occurrences,
    required this.compact,
    required this.selected,
    required this.onSelected,
  });
  final DateTime anchor;
  final List<AgendaOccurrence> occurrences;
  final bool compact;
  final AgendaOccurrence? selected;
  final ValueChanged<AgendaOccurrence> onSelected;

  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(widget.anchor.year, widget.anchor.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final selectedDay = _selectedDay ?? widget.anchor;
    return Column(
      children: [
        Row(
          children: [
            for (final day in const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'])
              Expanded(
                child: Center(child: Text(day, style: Theme.of(context).textTheme.labelMedium)),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Expanded(
          child: GridView.builder(
            key: const Key('agenda-month-grid'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: widget.compact ? .76 : 1.05,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = gridStart.add(Duration(days: index));
              final items = widget.occurrences
                  .where((item) => _sameDay(item.startsAt, day))
                  .toList();
              return _DayCell(
                day: day,
                inMonth: day.month == widget.anchor.month,
                items: items,
                compact: widget.compact,
                selected: _sameDay(day, selectedDay),
                onTap: () => setState(() => _selectedDay = day),
                onItemTap: widget.onSelected,
              );
            },
          ),
        ),
        if (widget.compact) ...[
          const SizedBox(height: CoeloSpacing.space3),
          SizedBox(
            height: 190,
            child: _OccurrenceList(
              occurrences: widget.occurrences
                  .where((item) => _sameDay(item.startsAt, selectedDay))
                  .toList(),
              emptyLabel: 'Nenhum item em ${_shortDate(selectedDay)}.',
              onSelected: widget.onSelected,
              showDate: false,
            ),
          ),
        ],
      ],
    );
  }
}

final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.items,
    required this.compact,
    required this.selected,
    required this.onTap,
    required this.onItemTap,
  });
  final DateTime day;
  final bool inMonth;
  final List<AgendaOccurrence> items;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<AgendaOccurrence> onItemTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = compact ? items.take(3) : items.take(2);
    final hidden = items.length - visible.length;
    return Semantics(
      label: '${_longDate(day)}; ${items.length} itens',
      selected: selected,
      button: true,
      child: TextButton(
        onPressed: items.isEmpty ? onTap : () => onItemTap(items.first),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          foregroundColor: colors.onSurface,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer.withValues(alpha: .42) : colors.surface,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${day.day}${_sameDay(day, DateTime(2026, 8, 3)) ? ' · Hoje' : ''}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: inMonth ? colors.onSurface : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: CoeloSpacing.space1),
                for (final item in visible)
                  if (compact)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(CoeloRadius.full),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        item.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                if (hidden > 0)
                  Text(
                    '+$hidden',
                    key: Key('agenda-more-${day.year}-${day.month}-${day.day}'),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.occurrences,
    required this.compact,
    required this.onSelected,
  });
  final DateTime anchor;
  final List<AgendaOccurrence> occurrences;
  final bool compact;
  final ValueChanged<AgendaOccurrence> onSelected;

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(anchor);
    if (compact) {
      return _OccurrenceList(
        occurrences: occurrences,
        emptyLabel: 'Nenhum item nesta semana.',
        onSelected: onSelected,
        showDate: true,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: _WeekDay(
              day: start.add(Duration(days: index)),
              occurrences: occurrences
                  .where((item) => _sameDay(item.startsAt, start.add(Duration(days: index))))
                  .toList(),
              onSelected: onSelected,
            ),
          ),
      ],
    );
  }
}

final class _WeekDay extends StatelessWidget {
  const _WeekDay({required this.day, required this.occurrences, required this.onSelected});
  final DateTime day;
  final List<AgendaOccurrence> occurrences;
  final ValueChanged<AgendaOccurrence> onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space2),
          child: Text(_shortDate(day), style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: _OccurrenceList(
            occurrences: occurrences,
            emptyLabel: 'Livre',
            onSelected: onSelected,
            showDate: false,
            dense: true,
          ),
        ),
      ],
    ),
  );
}

final class _OccurrenceList extends StatelessWidget {
  const _OccurrenceList({
    required this.occurrences,
    required this.emptyLabel,
    required this.onSelected,
    required this.showDate,
    this.dense = false,
  });
  final List<AgendaOccurrence> occurrences;
  final String emptyLabel;
  final ValueChanged<AgendaOccurrence> onSelected;
  final bool showDate;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return CoeloStatePanel(
        title: 'Agenda livre',
        message: emptyLabel,
        icon: Icons.event_available_outlined,
      );
    }
    return ListView.separated(
      key: const Key('agenda-occurrence-list'),
      padding: EdgeInsets.zero,
      itemCount: occurrences.length,
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space2),
      itemBuilder: (context, index) {
        final occurrence = occurrences[index];
        final conflicts = occurrences
            .where(
              (other) =>
                  other != occurrence &&
                  other.startsAt.isBefore(occurrence.endsAt) &&
                  other.endsAt.isAfter(occurrence.startsAt),
            )
            .length;
        return _OccurrenceCard(
          occurrence: occurrence,
          showDate: showDate,
          dense: dense,
          conflicts: conflicts,
          onTap: () => onSelected(occurrence),
        );
      },
    );
  }
}

final class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.showDate,
    required this.dense,
    required this.conflicts,
    required this.onTap,
  });
  final AgendaOccurrence occurrence;
  final bool showDate;
  final bool dense;
  final int conflicts;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${occurrence.item.title}; ${occurrence.item.type.label}; ${_time(occurrence.startsAt)} até ${_time(occurrence.endsAt)}; prioridade ${_priorityLabel(occurrence.item.priority)}',
    child: CoeloAdminInteractiveCard(
      onPressed: onTap,
      semanticLabel:
          '${occurrence.item.title}; ${occurrence.item.type.label}; ${_time(occurrence.startsAt)} até ${_time(occurrence.endsAt)}',
      child: Padding(
        padding: EdgeInsets.all(dense ? CoeloSpacing.space2 : CoeloSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: occurrence.item.recurrence == null ? 5 : 3,
              height: dense ? 42 : 54,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(CoeloRadius.full),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDate)
                    Text(
                      _longDate(occurrence.startsAt),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Text(
                    occurrence.item.title,
                    maxLines: dense ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${_time(occurrence.startsAt)}–${_time(occurrence.endsAt)} · ${occurrence.item.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!dense)
                    Text(
                      '${occurrence.item.type.label} · ${_priorityLabel(occurrence.item.priority)} · ${_statusLabel(occurrence.item.status)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (conflicts > 0)
                    Text(
                      'Conflito com $conflicts item(ns)',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _AgendaDetail extends StatelessWidget {
  const _AgendaDetail({required this.occurrence, required this.onClose});
  final AgendaOccurrence occurrence;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Detalhes do item', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Fechar detalhes',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text(occurrence.item.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: CoeloSpacing.space2),
          Text('${occurrence.item.type.label} · ${_statusLabel(occurrence.item.status)}'),
          const Divider(height: CoeloSpacing.space6),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text:
                '${_longDate(occurrence.startsAt)}, ${_time(occurrence.startsAt)}–${_time(occurrence.endsAt)}',
          ),
          _DetailLine(icon: Icons.place_outlined, text: occurrence.item.location),
          _DetailLine(
            icon: Icons.account_tree_outlined,
            text: occurrence.item.audience.institutionId,
          ),
          _DetailLine(
            icon: Icons.flag_outlined,
            text:
                'Prioridade ${_priorityLabel(occurrence.item.priority)} · alcance ${_prominenceLabel(occurrence.item.prominence)}',
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(occurrence.item.description),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Origem e histórico local', style: Theme.of(context).textTheme.titleSmall),
          Text(
            '${_originLabel(occurrence.item.origin)} · fixture fictício, sem notificações reais.',
          ),
        ],
      ),
    ),
  );
}

final class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: CoeloSize.iconSm),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
DateTime _startOfWeek(DateTime value) => _day(value).subtract(Duration(days: value.weekday - 1));
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
String _longDate(DateTime value) => '${value.day} de ${_monthName(value.month)} de ${value.year}';
String _monthName(int month) => const [
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
][month - 1];

String _priorityLabel(AgendaPriority value) => switch (value) {
  AgendaPriority.normal => 'normal',
  AgendaPriority.important => 'importante',
  AgendaPriority.urgent => 'urgente',
};
String _statusLabel(AgendaItemStatus value) => switch (value) {
  AgendaItemStatus.draft => 'Rascunho',
  AgendaItemStatus.scheduled => 'Agendado',
  AgendaItemStatus.published => 'Publicado',
  AgendaItemStatus.canceled => 'Cancelado',
};
String _originLabel(AgendaItemOrigin value) => switch (value) {
  AgendaItemOrigin.institution => 'Instituição',
  AgendaItemOrigin.guardianRequest => 'Solicitação do responsável',
  AgendaItemOrigin.fixture => 'Fixture local',
};
String _prominenceLabel(AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => 'institucional',
  AgendaVisualProminence.unit => 'unidade',
  AgendaVisualProminence.group => 'turma',
  AgendaVisualProminence.activity => 'atividade',
  AgendaVisualProminence.personal => 'pessoal',
};
