import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';
import 'agenda_module_shell.dart';

enum AgendaInstitutionalView { calendar, list }

extension on AgendaInstitutionalView {
  String get label => switch (this) {
    AgendaInstitutionalView.calendar => 'Calendário',
    AgendaInstitutionalView.list => 'Lista',
  };
}

final class AgendaCalendarPage extends StatefulWidget {
  const AgendaCalendarPage({
    required AgendaPrototypeStore this.store,
    required this.logout,
    required this.onAreaSelected,
    required this.onCreateItem,
    this.onDestinationSelected,
    this.onOpenItem,
    super.key,
  }) : unavailable = false;

  const AgendaCalendarPage.unavailable({
    required this.logout,
    required this.onAreaSelected,
    required this.onCreateItem,
    this.onDestinationSelected,
    this.onOpenItem,
    super.key,
  }) : store = null,
       unavailable = true;

  final AgendaPrototypeStore? store;
  final bool unavailable;
  final LogoutAction logout;
  final ValueChanged<AgendaModuleArea> onAreaSelected;
  final VoidCallback onCreateItem;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<String>? onOpenItem;

  @override
  State<AgendaCalendarPage> createState() => _AgendaCalendarPageState();
}

final class _AgendaCalendarPageState extends State<AgendaCalendarPage> {
  final _search = TextEditingController();
  AgendaInstitutionalView _view = AgendaInstitutionalView.calendar;
  late DateTime _month;
  DateTime? _selectedDay;
  String _context = 'Todos os contextos';
  bool _expandedDay = false;

  @override
  void initState() {
    super.initState();
    _month = widget.store?.referenceDate ?? DateTime(2026, 8, 3);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AgendaModuleShell(
    logout: widget.logout,
    selectedArea: AgendaModuleArea.calendar,
    onAreaSelected: widget.onAreaSelected,
    onDestinationSelected: widget.onDestinationSelected,
    child: widget.unavailable
        ? const _AgendaUnavailable()
        : AnimatedBuilder(
            animation: widget.store!,
            builder: (context, _) => _buildAvailable(context),
          ),
  );

  Widget _buildAvailable(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth < 600;
      final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      final occurrences = _occurrences();
      final toolbar = _AgendaToolbar(
        month: _month,
        view: _view,
        contextValue: _context,
        search: _search,
        onSearchChanged: (_) => setState(() {}),
        onContextChanged: (value) => setState(() => _context = value),
        onViewChanged: (value) => setState(() {
          _view = value;
          _selectedDay = null;
          _expandedDay = false;
        }),
        onToday: () => setState(() => _month = widget.store!.referenceDate),
        onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
        onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
      );

      if ((mobile && _selectedDay != null) || _expandedDay) {
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, CoeloSpacing.space4),
          child: _AgendaDayDetail(
            key: const Key('agenda-day-fullscreen'),
            day: _selectedDay!,
            occurrences: _forDay(occurrences, _selectedDay!),
            fullscreen: true,
            onClose: () => setState(() {
              _selectedDay = null;
              _expandedDay = false;
            }),
            onOpenItem: widget.onOpenItem,
          ),
        );
      }

      final body = _view == AgendaInstitutionalView.calendar
          ? _AgendaMonth(
              month: _month,
              occurrences: occurrences,
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
            )
          : _AgendaTimeline(occurrences: occurrences, onOpenItem: widget.onOpenItem);

      return Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, CoeloSpacing.space4),
        child: CoeloAdminWorkspaceLayout(
          toolbar: toolbar,
          body: body,
          detail: _selectedDay == null
              ? null
              : _AgendaDayDetail(
                  key: const Key('agenda-day-detail-panel'),
                  day: _selectedDay!,
                  occurrences: _forDay(occurrences, _selectedDay!),
                  fullscreen: false,
                  onExpand: () => setState(() => _expandedDay = true),
                  onClose: () => setState(() => _selectedDay = null),
                  onOpenItem: widget.onOpenItem,
                ),
          detailVisible: !mobile && _selectedDay != null,
        ),
      );
    },
  );

  List<AgendaOccurrence> _occurrences() {
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1);
    final query = _search.text.trim().toLowerCase();
    final values = widget.store!
        .occurrencesBetween(start, end)
        .where((occurrence) {
          if (query.isNotEmpty &&
              !occurrence.item.title.toLowerCase().contains(query) &&
              !occurrence.item.description.toLowerCase().contains(query)) {
            return false;
          }
          return switch (_context) {
            'Instituição' => occurrence.item.prominence == AgendaVisualProminence.institutional,
            'Unidades' => occurrence.item.prominence == AgendaVisualProminence.unit,
            'Turmas' => occurrence.item.prominence == AgendaVisualProminence.group,
            'Atividades' => occurrence.item.prominence == AgendaVisualProminence.activity,
            _ => true,
          };
        })
        .toList(growable: false);
    values.sort(AgendaOccurrence.compareChronologically);
    return values;
  }
}

final class _AgendaUnavailable extends StatelessWidget {
  const _AgendaUnavailable();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('agenda-production-unavailable'),
    padding: const EdgeInsets.all(CoeloSpacing.space6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _UnavailableViewHeader(),
        const SizedBox(height: CoeloSpacing.space6),
        CoeloStatePanel(
          icon: Icons.event_busy_outlined,
          title: 'Agenda indisponível',
          message:
              'A composição está pronta, mas a leitura e as ações produtivas permanecem bloqueadas até existir integração autorizada.',
        ),
      ],
    ),
  );
}

final class _UnavailableViewHeader extends StatelessWidget {
  const _UnavailableViewHeader();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CoeloSpacing.space2,
    runSpacing: CoeloSpacing.space2,
    children: [
      for (final value in AgendaInstitutionalView.values)
        OutlinedButton(onPressed: null, child: Text(value.label)),
    ],
  );
}

final class _AgendaToolbar extends StatelessWidget {
  const _AgendaToolbar({
    required this.month,
    required this.view,
    required this.contextValue,
    required this.search,
    required this.onSearchChanged,
    required this.onContextChanged,
    required this.onViewChanged,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final AgendaInstitutionalView view;
  final String contextValue;
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onContextChanged;
  final ValueChanged<AgendaInstitutionalView> onViewChanged;
  final VoidCallback onToday, onPrevious, onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        children: [
          Text(_monthYear(month), style: Theme.of(context).textTheme.titleLarge),
          Wrap(
            spacing: CoeloSpacing.space1,
            children: [
              TextButton(onPressed: onToday, child: const Text('Hoje')),
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminListingToolbar(
        search: SizedBox(
          width: 280,
          child: CoeloSearchField(
            controller: search,
            semanticLabel: 'Buscar eventos da Agenda',
            hintText: 'Buscar eventos',
            onChanged: onSearchChanged,
          ),
        ),
        filters: [
          SizedBox(
            width: 220,
            child: CoeloAdminSingleSelectField<String>(
              label: 'Contexto',
              value: contextValue,
              options: const [
                'Todos os contextos',
                'Instituição',
                'Unidades',
                'Turmas',
                'Atividades',
              ],
              optionLabel: (value) => value,
              onChanged: onContextChanged,
              prefixIcon: Icons.account_tree_outlined,
            ),
          ),
        ],
        actions: [_AgendaViewToggle(selected: view, onSelected: onViewChanged)],
      ),
      const SizedBox(height: CoeloSpacing.space3),
    ],
  );
}

final class _AgendaViewToggle extends StatelessWidget {
  const _AgendaViewToggle({required this.selected, required this.onSelected});

  final AgendaInstitutionalView selected;
  final ValueChanged<AgendaInstitutionalView> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Alternar visualização da Agenda',
    child: Wrap(
      spacing: CoeloSpacing.space1,
      runSpacing: CoeloSpacing.space1,
      children: [
        for (final value in AgendaInstitutionalView.values)
          OutlinedButton(
            key: Key('agenda-view-${value.name}'),
            onPressed: () => onSelected(value),
            style: OutlinedButton.styleFrom(
              foregroundColor: selected == value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: selected == value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              minimumSize: const Size(88, CoeloSize.touchMin),
            ),
            child: Text(value.label),
          ),
      ],
    ),
  );
}

final class _AgendaMonth extends StatelessWidget {
  const _AgendaMonth({
    required this.month,
    required this.occurrences,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime month;
  final List<AgendaOccurrence> occurrences;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final visibleStart = first.subtract(Duration(days: first.weekday % 7));
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      key: const Key('agenda-month-scroll'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final label in const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                Expanded(child: Center(child: Text(label))),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          GridView.builder(
            key: const Key('agenda-month-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: compact ? .42 : .95,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = visibleStart.add(Duration(days: index));
              final dayOccurrences = _forDay(occurrences, day);
              return _AgendaDayCell(
                day: day,
                inMonth: day.month == month.month,
                selected: selectedDay != null && _sameDay(day, selectedDay!),
                occurrences: dayOccurrences,
                onPressed: () => onDaySelected(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _AgendaDayCell extends StatelessWidget {
  const _AgendaDayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.occurrences,
    required this.onPressed,
  });

  final DateTime day;
  final bool inMonth, selected;
  final List<AgendaOccurrence> occurrences;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.day} de ${_monthName(day.month)}, ${occurrences.length} eventos',
      child: InkWell(
        key: Key('agenda-day-${_isoDate(day)}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        child: Container(
          margin: const EdgeInsets.all(CoeloSpacing.spaceHalf),
          padding: const EdgeInsets.all(CoeloSpacing.space1),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: inMonth ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: CoeloSpacing.spaceHalf),
              for (final occurrence in occurrences.take(largeText ? 1 : 2))
                Padding(
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.spaceHalf),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _eventColor(colors, occurrence.item.prominence),
                      borderRadius: BorderRadius.circular(CoeloRadius.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: largeText
                          ? SizedBox.square(
                              dimension: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : Text(
                              occurrence.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                    ),
                  ),
                ),
              if (!largeText && occurrences.length > 2)
                Text('+${occurrences.length - 2}', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AgendaTimeline extends StatelessWidget {
  const _AgendaTimeline({required this.occurrences, this.onOpenItem});

  final List<AgendaOccurrence> occurrences;
  final ValueChanged<String>? onOpenItem;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return const CoeloStatePanel(
        icon: Icons.event_available_outlined,
        title: 'Nenhum evento encontrado',
        message: 'Ajuste o mês, a busca ou o contexto selecionado.',
      );
    }
    return SingleChildScrollView(
      key: const Key('agenda-list-timeline'),
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
      child: Column(
        children: [
          for (final occurrence in occurrences) ...[
            _AgendaTimelineEntry(occurrence: occurrence, onOpenItem: onOpenItem),
            const SizedBox(height: CoeloSpacing.space2),
          ],
        ],
      ),
    );
  }
}

final class _AgendaTimelineEntry extends StatelessWidget {
  const _AgendaTimelineEntry({required this.occurrence, this.onOpenItem});

  final AgendaOccurrence occurrence;
  final ValueChanged<String>? onOpenItem;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 48 : 72,
            child: Column(
              children: [
                Text(_weekday(occurrence.startsAt), style: Theme.of(context).textTheme.labelSmall),
                Text(
                  '${occurrence.startsAt.day}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(_shortMonth(occurrence.startsAt.month)),
              ],
            ),
          ),
          Expanded(
            child: CoeloAdminInteractiveCard(
              semanticLabel: '${occurrence.item.title}, ${_timeRange(occurrence)}',
              onPressed: onOpenItem == null ? null : () => onOpenItem!(occurrence.item.id),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: compact ? _compactContent(context) : _wideContent(context),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _compactContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _illustration(context, 64, 64),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeLabel(context),
                Text(occurrence.item.title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(occurrence.item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: CoeloSpacing.space2),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space1,
        children: [
          if (occurrence.item.location.isNotEmpty) Text(occurrence.item.location),
          _prominenceChip(context),
          Text(_statusLabel(occurrence.item.status)),
          IconButton(
            tooltip: 'Mais ações de ${occurrence.item.title}',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    ],
  );

  Widget _wideContent(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _illustration(context, 96, 84),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeLabel(context),
            Text(occurrence.item.title, style: Theme.of(context).textTheme.titleMedium),
            Text(occurrence.item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (occurrence.item.location.isNotEmpty)
              Text(occurrence.item.location, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
      const SizedBox(width: CoeloSpacing.space2),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _prominenceChip(context),
          const SizedBox(height: CoeloSpacing.space2),
          Text(_statusLabel(occurrence.item.status)),
          IconButton(
            tooltip: 'Mais ações de ${occurrence.item.title}',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    ],
  );

  Widget _illustration(BuildContext context, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: _eventColor(Theme.of(context).colorScheme, occurrence.item.prominence),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Icon(_eventIcon(occurrence.item.type), size: 32),
  );

  Widget _timeLabel(BuildContext context) => Text(
    _timeRange(occurrence),
    style: Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
  );

  Widget _prominenceChip(BuildContext context) => CoeloStatusChip(
    label: _prominenceLabel(occurrence.item.prominence),
    backgroundColor: _eventColor(Theme.of(context).colorScheme, occurrence.item.prominence),
    foregroundColor: Theme.of(context).colorScheme.onSurface,
  );
}

final class _AgendaDayDetail extends StatelessWidget {
  const _AgendaDayDetail({
    required super.key,
    required this.day,
    required this.occurrences,
    required this.fullscreen,
    required this.onClose,
    this.onExpand,
    this.onOpenItem,
  });

  final DateTime day;
  final List<AgendaOccurrence> occurrences;
  final bool fullscreen;
  final VoidCallback onClose;
  final VoidCallback? onExpand;
  final ValueChanged<String>? onOpenItem;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: fullscreen ? 'Voltar ao mês' : 'Fechar detalhes',
              onPressed: onClose,
              icon: Icon(fullscreen ? Icons.arrow_back_rounded : Icons.close_rounded),
            ),
            Expanded(child: Text(_longDay(day), style: Theme.of(context).textTheme.titleLarge)),
            if (onExpand != null)
              IconButton(
                key: const Key('agenda-day-panel-expand'),
                tooltip: 'Expandir detalhe do dia',
                onPressed: onExpand,
                icon: const Icon(Icons.open_in_full_rounded),
              ),
          ],
        ),
        const Divider(),
        Expanded(
          child: occurrences.isEmpty
              ? const CoeloStatePanel(
                  icon: Icons.event_available_outlined,
                  title: 'Nenhum evento neste dia',
                  message: 'Selecione outro dia para ver a programação.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  itemCount: occurrences.length,
                  itemBuilder: (context, index) {
                    final occurrence = occurrences[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 52, child: Text(_time(occurrence.startsAt))),
                          const SizedBox(width: CoeloSpacing.space2),
                          Expanded(
                            child: CoeloAdminInteractiveCard(
                              semanticLabel: occurrence.item.title,
                              onPressed: onOpenItem == null
                                  ? null
                                  : () => onOpenItem!(occurrence.item.id),
                              child: Padding(
                                padding: const EdgeInsets.all(CoeloSpacing.space3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      occurrence.item.title,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(_timeRange(occurrence)),
                                    if (occurrence.item.location.isNotEmpty)
                                      Text(occurrence.item.location),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

List<AgendaOccurrence> _forDay(List<AgendaOccurrence> values, DateTime day) =>
    values.where((occurrence) => _sameDay(occurrence.startsAt, day)).toList(growable: false);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _monthYear(DateTime value) => '${_monthName(value.month)} de ${value.year}';

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

String _shortMonth(int month) => const [
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
][month - 1];

String _weekday(DateTime value) =>
    const ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'][value.weekday - 1];

String _longDay(DateTime value) {
  final weekday = const [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ][value.weekday - 1];
  return '$weekday, ${value.day} de ${_monthName(value.month)}';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _timeRange(AgendaOccurrence value) =>
    value.item.allDay ? 'Dia inteiro' : '${_time(value.startsAt)} – ${_time(value.endsAt)}';

String _statusLabel(AgendaItemStatus value) => switch (value) {
  AgendaItemStatus.draft => 'Rascunho',
  AgendaItemStatus.scheduled => 'Agendado',
  AgendaItemStatus.published => 'Publicado',
  AgendaItemStatus.canceled => 'Cancelado',
};

String _prominenceLabel(AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => 'Instituição',
  AgendaVisualProminence.unit => 'Unidade',
  AgendaVisualProminence.group => 'Turma',
  AgendaVisualProminence.activity => 'Atividade',
  AgendaVisualProminence.personal => 'Pessoa',
};

Color _eventColor(ColorScheme colors, AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => colors.primaryContainer,
  AgendaVisualProminence.unit => colors.secondaryContainer,
  AgendaVisualProminence.group => colors.tertiaryContainer,
  AgendaVisualProminence.activity => colors.surfaceContainerHighest,
  AgendaVisualProminence.personal => colors.errorContainer,
};

IconData _eventIcon(AgendaItemType value) => switch (value) {
  AgendaItemType.event => Icons.celebration_outlined,
  AgendaItemType.recurringRoutine => Icons.repeat_rounded,
  AgendaItemType.birthday => Icons.cake_outlined,
  AgendaItemType.holidayOrBreak => Icons.beach_access_outlined,
  AgendaItemType.appointment => Icons.event_available_outlined,
  AgendaItemType.deadline => Icons.timer_outlined,
  AgendaItemType.operationalChange => Icons.update_rounded,
  AgendaItemType.resourceReservation => Icons.meeting_room_outlined,
  AgendaItemType.other => Icons.event_note_outlined,
};
