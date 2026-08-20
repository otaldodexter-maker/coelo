import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';
import 'agenda_module_shell.dart';

enum AgendaCalendarView { month, week, day, agenda }

enum _AgendaScope { all, units, groups, activities }

extension on _AgendaScope {
  String get label => switch (this) {
    _AgendaScope.all => 'Todos',
    _AgendaScope.units => 'Unidades',
    _AgendaScope.groups => 'Turmas',
    _AgendaScope.activities => 'Atividades',
  };
}

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
  _AgendaScope _scope = _AgendaScope.all;
  bool _showFullCalendar = false;
  final Set<String> _bookmarkedItemIds = {};
  String _institution = 'Todas as instituições';

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
          if (!_showFullCalendar) {
            return _AgendaTimeline(
              anchor: _anchor,
              occurrences: _timelineOccurrences(),
              scope: _scope,
              bookmarkedItemIds: _bookmarkedItemIds,
              onScopeSelected: (scope) => setState(() => _scope = scope),
              onPrevious: () => setState(() => _anchor = DateTime(_anchor.year, _anchor.month - 1)),
              onNext: () => setState(() => _anchor = DateTime(_anchor.year, _anchor.month + 1)),
              onToday: () => setState(() => _anchor = widget.store.referenceDate),
              onBookmark: (id) => setState(() {
                _bookmarkedItemIds.contains(id)
                    ? _bookmarkedItemIds.remove(id)
                    : _bookmarkedItemIds.add(id);
              }),
              onOpenFullCalendar: () => setState(() {
                _showFullCalendar = true;
                _view = AgendaCalendarView.month;
              }),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space4,
              0,
              CoeloSpacing.space4,
              CoeloSpacing.space4,
            ),
            child: CoeloAdminWorkspaceLayout(
              toolbar: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('agenda-back-to-timeline'),
                      onPressed: () => setState(() {
                        _showFullCalendar = false;
                        _selected = null;
                      }),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Próximos eventos'),
                    ),
                  ),
                  _toolbar(view, compact),
                ],
              ),
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

  List<AgendaOccurrence> _timelineOccurrences() {
    final start = DateTime(_anchor.year, _anchor.month);
    final end = DateTime(_anchor.year, _anchor.month + 1);
    return widget.store
        .occurrencesBetween(start, end)
        .where((occurrence) {
          final prominence = occurrence.item.prominence;
          return switch (_scope) {
            _AgendaScope.all => true,
            _AgendaScope.units => prominence == AgendaVisualProminence.unit,
            _AgendaScope.groups => prominence == AgendaVisualProminence.group,
            _AgendaScope.activities => prominence == AgendaVisualProminence.activity,
          };
        })
        .toList(growable: false);
  }

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
            search: const SizedBox.shrink(),
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
            'Contexto hierárquico ativo · $_institution',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<AgendaOccurrence> _visibleOccurrences(AgendaCalendarView view) {
    final range = _range(view);
    final all = widget.store.occurrencesBetween(range.$1, range.$2);
    return all
        .where((occurrence) {
          if (_institution != 'Todas as instituições' &&
              occurrence.item.audience.institutionId != _institution) {
            return false;
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

final class _AgendaTimeline extends StatelessWidget {
  const _AgendaTimeline({
    required this.anchor,
    required this.occurrences,
    required this.scope,
    required this.bookmarkedItemIds,
    required this.onScopeSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onBookmark,
    required this.onOpenFullCalendar,
  });

  final DateTime anchor;
  final List<AgendaOccurrence> occurrences;
  final _AgendaScope scope;
  final Set<String> bookmarkedItemIds;
  final ValueChanged<_AgendaScope> onScopeSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<String> onBookmark;
  final VoidCallback onOpenFullCalendar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          key: const Key('agenda-timeline'),
          padding: EdgeInsets.fromLTRB(
            compact ? CoeloSpacing.space3 : CoeloSpacing.space6,
            0,
            compact ? CoeloSpacing.space3 : CoeloSpacing.space6,
            CoeloSpacing.space6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _InstitutionHero(),
                  const SizedBox(height: CoeloSpacing.space4),
                  _ScopeSelector(selected: scope, onSelected: onScopeSelected),
                  const SizedBox(height: CoeloSpacing.space5),
                  _TimelinePeriodHeader(
                    anchor: anchor,
                    onPrevious: onPrevious,
                    onNext: onNext,
                    onToday: onToday,
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  if (occurrences.isEmpty)
                    const CoeloStatePanel(
                      icon: Icons.event_available_rounded,
                      title: 'Nenhum evento neste período',
                      message: 'Tente outro mês ou selecione Todos.',
                    )
                  else
                    for (final occurrence in occurrences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                        child: _TimelineEntry(
                          occurrence: occurrence,
                          bookmarked: bookmarkedItemIds.contains(occurrence.item.id),
                          onBookmark: () => onBookmark(occurrence.item.id),
                          compact: compact,
                        ),
                      ),
                  OutlinedButton.icon(
                    key: const Key('agenda-open-full-calendar'),
                    onPressed: onOpenFullCalendar,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Ver agenda completa'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class _InstitutionHero extends StatelessWidget {
  const _InstitutionHero();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Perfil verificado do Colégio Horizonte, Instituição de Ensino',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        child: AspectRatio(
          aspectRatio: 2.7,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/principal_profile/institution-cover.png',
                fit: BoxFit.cover,
                semanticLabel: 'Fachada do Colégio Horizonte',
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: .78)],
                  ),
                ),
              ),
              Positioned(
                left: CoeloSpacing.space4,
                right: CoeloSpacing.space4,
                bottom: CoeloSpacing.space4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(CoeloSpacing.space2),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(CoeloRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: .16),
                            blurRadius: CoeloSpacing.space3,
                            offset: const Offset(0, CoeloSpacing.space1),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/principal_profile/institution-crest.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Brasão do Colégio Horizonte',
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Colégio Horizonte',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: CoeloSpacing.space1),
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                            ],
                          ),
                          const SizedBox(height: CoeloSpacing.space1),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70),
                              borderRadius: BorderRadius.circular(CoeloRadius.full),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CoeloSpacing.space2,
                                vertical: CoeloSpacing.spaceHalf,
                              ),
                              child: Text(
                                'Instituição de Ensino',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelMedium?.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

final class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.selected, required this.onSelected});
  final _AgendaScope selected;
  final ValueChanged<_AgendaScope> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final scope in _AgendaScope.values)
              Semantics(
                selected: selected == scope,
                button: true,
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space1),
                  child: TextButton(
                    key: Key('agenda-scope-${scope.name}'),
                    onPressed: () => onSelected(scope),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(132, CoeloSize.touchMin)),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => selected == scope
                            ? colors.onPrimary
                            : states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                            ? colors.primary
                            : colors.onSurface,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => selected == scope
                            ? colors.primary
                            : states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                            ? colors.primaryContainer
                            : Colors.transparent,
                      ),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
                      ),
                    ),
                    child: Text(scope.label),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _TimelinePeriodHeader extends StatelessWidget {
  const _TimelinePeriodHeader({
    required this.anchor,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });
  final DateTime anchor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: CoeloSize.touchMin,
        height: CoeloSize.touchMin,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Icon(Icons.calendar_today_rounded),
      ),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_monthName(anchor.month)} de ${anchor.year}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton(onPressed: onToday, child: const Text('Próximos eventos · Hoje')),
          ],
        ),
      ),
      IconButton.outlined(
        tooltip: 'Mês anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      const SizedBox(width: CoeloSpacing.space2),
      IconButton.filledTonal(
        tooltip: 'Próximo mês',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

final class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.occurrence,
    required this.bookmarked,
    required this.onBookmark,
    required this.compact,
  });
  final AgendaOccurrence occurrence;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final date = occurrence.startsAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 58 : 76,
          child: Padding(
            padding: const EdgeInsets.only(top: CoeloSpacing.space3),
            child: Column(
              children: [
                Text(_weekday(date), style: Theme.of(context).textTheme.labelMedium),
                Text('${date.day}', style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  _shortMonth(date.month),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _TimelineCard(
            occurrence: occurrence,
            bookmarked: bookmarked,
            onBookmark: onBookmark,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

final class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.occurrence,
    required this.bookmarked,
    required this.onBookmark,
    required this.compact,
  });
  final AgendaOccurrence occurrence;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = occurrence.item;
    final colors = Theme.of(context).colorScheme;
    final prominence = item.prominence;
    final tone = _prominenceColor(colors, prominence);
    final textScaled = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final contextBadge = DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space2,
          vertical: CoeloSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_prominenceIcon(prominence), size: 18, color: tone),
            const SizedBox(width: CoeloSpacing.space1),
            Flexible(
              child: Text(
                _prominenceLabel(prominence),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone),
              ),
            ),
          ],
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textScaled) ...[
          Text(
            item.allDay
                ? 'Dia inteiro'
                : '${_time(occurrence.startsAt)} – ${_time(occurrence.endsAt)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Align(alignment: Alignment.centerLeft, child: contextBadge),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.allDay
                      ? 'Dia inteiro'
                      : '${_time(occurrence.startsAt)} – ${_time(occurrence.endsAt)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
              ),
              Flexible(child: contextBadge),
            ],
          ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: tone),
            const SizedBox(width: CoeloSpacing.space1),
            Expanded(
              child: Text(
                item.location.isEmpty ? _prominenceLabel(prominence) : item.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tone),
              ),
            ),
            Semantics(
              key: Key('agenda-bookmark-${item.id}'),
              button: true,
              toggled: bookmarked,
              label: bookmarked ? 'Remover evento dos salvos' : 'Salvar evento',
              child: IconButton(
                tooltip: bookmarked ? 'Remover dos salvos' : 'Salvar evento',
                onPressed: onBookmark,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? colors.primaryContainer
                        : Colors.transparent,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                icon: Icon(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              ),
            ),
          ],
        ),
      ],
    );
    return KeyedSubtree(
      key: Key('agenda-event-card-${item.id}'),
      child: CoeloAdminInteractiveCard(
        surfaceKey: Key('agenda-event-card-surface-${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: compact && textScaled
              ? content
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                      child: SizedBox(
                        width: compact ? 88 : 156,
                        height: compact ? 112 : 124,
                        child: Image.asset(
                          'assets/agenda/event-thumbnails.png',
                          fit: BoxFit.cover,
                          alignment: _thumbnailAlignment(item.id),
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: colors.primaryContainer,
                            child: Icon(
                              _agendaItemIcon(item.type),
                              color: colors.primary,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }
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
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final selectedDay = _selectedDay ?? widget.anchor;
    return Column(
      children: [
        Row(
          children: [
            for (final day in const ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    key: const Key('agenda-calendar-weekday-label'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
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
          Text('Origem do evento', style: Theme.of(context).textTheme.titleSmall),
          Text(_originLabel(occurrence.item.origin)),
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
DateTime _startOfWeek(DateTime value) => _day(value).subtract(Duration(days: value.weekday % 7));
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
String _longDate(DateTime value) => '${value.day} de ${_monthName(value.month)} de ${value.year}';
String _weekday(DateTime value) =>
    const ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'][value.weekday - 1];
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
  AgendaItemOrigin.fixture => 'Agenda institucional',
};
String _prominenceLabel(AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => 'Instituição',
  AgendaVisualProminence.unit => 'Unidade',
  AgendaVisualProminence.group => 'Turma',
  AgendaVisualProminence.activity => 'Atividade',
  AgendaVisualProminence.personal => 'Pessoal',
};

IconData _prominenceIcon(AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => Icons.account_balance_outlined,
  AgendaVisualProminence.unit => Icons.home_work_outlined,
  AgendaVisualProminence.group => Icons.groups_2_outlined,
  AgendaVisualProminence.activity => Icons.directions_run_rounded,
  AgendaVisualProminence.personal => Icons.person_outline_rounded,
};

Color _prominenceColor(ColorScheme colors, AgendaVisualProminence value) => switch (value) {
  AgendaVisualProminence.institutional => colors.primary,
  AgendaVisualProminence.unit => colors.tertiary,
  AgendaVisualProminence.group => colors.secondary,
  AgendaVisualProminence.activity => colors.primary,
  AgendaVisualProminence.personal => colors.tertiary,
};

IconData _agendaItemIcon(AgendaItemType value) => switch (value) {
  AgendaItemType.event => Icons.celebration_outlined,
  AgendaItemType.appointment => Icons.event_available_outlined,
  AgendaItemType.recurringRoutine => Icons.repeat_rounded,
  AgendaItemType.birthday => Icons.cake_outlined,
  AgendaItemType.holidayOrBreak => Icons.beach_access_outlined,
  AgendaItemType.deadline => Icons.timer_outlined,
  AgendaItemType.operationalChange => Icons.update_rounded,
  AgendaItemType.resourceReservation => Icons.meeting_room_outlined,
  AgendaItemType.other => Icons.event_note_outlined,
};

Alignment _thumbnailAlignment(String id) {
  final index = id.codeUnits.fold<int>(0, (sum, value) => sum + value) % 5;
  return Alignment(-1 + (index * .5), 0);
}
