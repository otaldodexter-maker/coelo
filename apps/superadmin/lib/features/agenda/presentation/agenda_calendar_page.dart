import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../domain/agenda_models.dart';
import '../domain/agenda_repository.dart';
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
    required AgendaRepository this.store,
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

  final AgendaRepository? store;
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
    if (!widget.unavailable) unawaited(_loadMonth());
  }

  Future<void> _loadMonth() => widget.store!.loadEvents(
    from: DateTime(_month.year, _month.month),
    to: DateTime(_month.year, _month.month + 1),
  );

  void _changeMonth(DateTime value) {
    setState(() => _month = value);
    unawaited(_loadMonth());
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
      final readStatus = widget.store!.eventsRead;
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
        onPrevious: () => _changeMonth(DateTime(_month.year, _month.month - 1)),
        onNext: () => _changeMonth(DateTime(_month.year, _month.month + 1)),
        enabled:
            readStatus != AgendaReadStatus.loading && readStatus != AgendaReadStatus.unauthorized,
      );

      if (readStatus != AgendaReadStatus.ready) {
        // Keep at least the state panel padding and a touch target visible.
        // A scaled toolbar may scroll, but never consumes the whole workspace.
        final minimumPanelHeight =
            CoeloSpacing.space1 * 2 +
            CoeloSpacing.space8 * 2 +
            MediaQuery.textScalerOf(context).scale(CoeloSize.touchMin);
        final maximumToolbarHeight =
            (constraints.maxHeight - CoeloSpacing.space4 - minimumPanelHeight).clamp(
              0.0,
              constraints.maxHeight,
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, CoeloSpacing.space4),
          child: CoeloAdminWorkspaceLayout(
            toolbar: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maximumToolbarHeight),
              child: SingleChildScrollView(child: toolbar),
            ),
            body: _readPanel(readStatus),
          ),
        );
      }
      final occurrences = _occurrences();
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
              today: widget.store!.referenceDate,
              compact: mobile,
              occurrences: occurrences,
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
            )
          : _AgendaTimeline(occurrences: occurrences, onOpenItem: widget.onOpenItem);

      return Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, CoeloSpacing.space4),
        child: CoeloAdminWorkspaceLayout(
          toolbar: toolbar,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              _AgendaFooter(
                onToday: () => _changeMonth(widget.store!.referenceDate),
                enabled: true,
              ),
            ],
          ),
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

  Widget _readPanel(AgendaReadStatus status) => switch (status) {
    AgendaReadStatus.loading => Semantics(
      key: const Key('agenda-calendar-loading'),
      label: 'Carregando Agenda',
      liveRegion: true,
      child: const CoeloStatePanel(
        title: 'Carregando Agenda',
        message: '',
        icon: Icons.event_outlined,
        loading: true,
      ),
    ),
    AgendaReadStatus.unauthorized => const CoeloStatePanel(
      key: Key('agenda-calendar-unauthorized'),
      title: 'Acesso à Agenda negado',
      message: 'Você não tem permissão para consultar a Agenda.',
      icon: Icons.lock_outline,
    ),
    AgendaReadStatus.failure => CoeloStatePanel(
      key: const Key('agenda-calendar-failure'),
      title: 'Não foi possível carregar a Agenda',
      message: 'Tente novamente para consultar os eventos deste período.',
      icon: Icons.error_outline,
      actionLabel: 'Tentar novamente',
      onAction: () => unawaited(_loadMonth()),
    ),
    _ => CoeloStatePanel(
      key: const Key('agenda-calendar-idle'),
      title: 'Atualize a Agenda',
      message: 'Consulte novamente os eventos deste período.',
      icon: Icons.event_outlined,
      actionLabel: 'Atualizar Agenda',
      onAction: () => unawaited(_loadMonth()),
    ),
  };

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

final class _AgendaUnavailable extends StatefulWidget {
  const _AgendaUnavailable();

  @override
  State<_AgendaUnavailable> createState() => _AgendaUnavailableState();
}

final class _AgendaUnavailableState extends State<_AgendaUnavailable> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      return Padding(
        key: const Key('agenda-production-unavailable'),
        padding: EdgeInsets.fromLTRB(inset, 0, inset, CoeloSpacing.space4),
        child: CoeloAdminWorkspaceLayout(
          toolbar: _AgendaToolbar(
            month: DateTime(2026, 8),
            view: AgendaInstitutionalView.calendar,
            contextValue: 'Todos os contextos',
            search: _search,
            onSearchChanged: (_) {},
            onContextChanged: (_) {},
            onViewChanged: (_) {},
            onPrevious: () {},
            onNext: () {},
            enabled: false,
          ),
          body: const CoeloStatePanel(
            icon: Icons.event_busy_outlined,
            title: 'Agenda indisponível',
            message:
                'A composição está pronta, mas a leitura e as ações produtivas permanecem bloqueadas até existir integração autorizada.',
          ),
        ),
      );
    },
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
    required this.onPrevious,
    required this.onNext,
    this.enabled = true,
  });

  final DateTime month;
  final AgendaInstitutionalView view;
  final String contextValue;
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onContextChanged;
  final ValueChanged<AgendaInstitutionalView> onViewChanged;
  final VoidCallback onPrevious, onNext;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _monthYear(month),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: enabled ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: enabled ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
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
            enabled: enabled,
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
              enabled: enabled,
              prefixIcon: Icons.account_tree_outlined,
            ),
          ),
        ],
        actions: const [],
      ),
      const SizedBox(height: CoeloSpacing.space3),
      // P33 (Owner, 11/09): o par Calendário/Lista divide a largura em 50%
      // cada, maior e centralizado, em vez de dois botões pequenos à direita.
      _AgendaViewToggle(selected: view, onSelected: onViewChanged, enabled: enabled),
      const SizedBox(height: CoeloSpacing.space3),
    ],
  );
}

final class _AgendaViewToggle extends StatelessWidget {
  const _AgendaViewToggle({required this.selected, required this.onSelected, this.enabled = true});

  final AgendaInstitutionalView selected;
  final ValueChanged<AgendaInstitutionalView> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Alternar visualização da Agenda',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: [
              for (final value in AgendaInstitutionalView.values) ...[
                if (value != AgendaInstitutionalView.values.first)
                  const SizedBox(width: CoeloSpacing.space1),
                Expanded(
                  child: OutlinedButton(
                    key: Key('agenda-view-${value.name}'),
                    onPressed: enabled ? () => onSelected(value) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: selected == value ? colors.primary : colors.onSurface,
                      backgroundColor: selected == value ? colors.primaryContainer : null,
                      side: BorderSide(
                        color: selected == value ? colors.primary : colors.outlineVariant,
                      ),
                      minimumSize: const Size(0, CoeloSize.touchMin),
                    ),
                    child: Text(value.label),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rodapé da Agenda (referência do iPhone, P33): botão Hoje à esquerda.
final class _AgendaFooter extends StatelessWidget {
  const _AgendaFooter({required this.onToday, required this.enabled});

  final VoidCallback onToday;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CoeloSpacing.space2),
    child: Row(
      children: [
        OutlinedButton(
          key: const Key('agenda-today'),
          onPressed: enabled ? onToday : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, CoeloSize.touchMin),
            shape: const StadiumBorder(),
          ),
          child: const Text('Hoje'),
        ),
      ],
    ),
  );
}

final class _AgendaMonth extends StatelessWidget {
  const _AgendaMonth({
    required this.month,
    required this.today,
    required this.compact,
    required this.occurrences,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime month, today;

  /// Largura compacta medida pelo `LayoutBuilder` da página (não pelo
  /// `MediaQuery`), para valer também dentro do shell.
  final bool compact;
  final List<AgendaOccurrence> occurrences;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month);
    final visibleStart = first.subtract(Duration(days: first.weekday % 7));
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    // Referência do Owner (calendário do iPhone, 11/09): linhas de altura
    // igual e generosa, separadas por linhas finas, sem contêiner por célula.
    final rowHeight = (compact ? 104.0 : 128.0) * textScale;
    final divider = BorderSide(color: colors.outlineVariant);
    return SingleChildScrollView(
      key: const Key('agenda-month-scroll'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'][i],
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: i == 0 || i == 6 ? colors.onSurfaceVariant : colors.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Column(
            key: const Key('agenda-month-grid'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var row = 0; row < 6; row++)
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: divider)),
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < 7; column++)
                          Expanded(
                            child: _dayCell(visibleStart.add(Duration(days: row * 7 + column))),
                          ),
                      ],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: divider)),
                child: const SizedBox(height: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day) => _AgendaDayCell(
    day: day,
    inMonth: day.month == month.month,
    today: _sameDay(day, today),
    selected: selectedDay != null && _sameDay(day, selectedDay!),
    occurrences: _forDay(occurrences, day),
    compact: compact,
    onPressed: () => onDaySelected(day),
  );
}

final class _AgendaDayCell extends StatelessWidget {
  const _AgendaDayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.occurrences,
    required this.onPressed,
    this.compact = false,
  });

  final DateTime day;
  final bool inMonth, today, selected;
  final List<AgendaOccurrence> occurrences;
  final VoidCallback onPressed;

  /// Largura compacta (telefone), medida pela página.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final weekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final Color numberColor;
    if (today) {
      numberColor = colors.onPrimary;
    } else if (selected) {
      numberColor = colors.surface;
    } else if (!inMonth) {
      numberColor = colors.onSurfaceVariant.withValues(alpha: .55);
    } else if (weekend) {
      numberColor = colors.onSurfaceVariant;
    } else {
      numberColor = colors.onSurface;
    }
    // P33: número do dia um pouco menor, no canto superior esquerdo, com
    // respiro (não colado à borda); hoje em círculo cheio na cor de destaque.
    final number = SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: today
              ? colors.primary
              : selected
              ? colors.onSurface
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: numberColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.day} de ${_monthName(day.month)}, ${occurrences.length} eventos',
      child: InkWell(
        key: Key('agenda-day-${_isoDate(day)}'),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space1,
            CoeloSpacing.space1,
            CoeloSpacing.space1,
            CoeloSpacing.spaceHalf,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.topLeft, child: number),
              const SizedBox(height: CoeloSpacing.space1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Cabem tantas pastilhas quantas a altura da linha permitir
                    // (a linha não cresce, como no iPhone); o excedente vira +N.
                    final pillHeight = 22 * MediaQuery.textScalerOf(context).scale(1);
                    final fit = (constraints.maxHeight / pillHeight).floor();
                    // O "+N" ocupa uma linha só quando não há espaço para ele
                    // sob a última pastilha que cabe.
                    final plusFits = constraints.maxHeight - fit * pillHeight >= 14;
                    final shown = occurrences.length <= fit
                        ? occurrences.length
                        : (plusFits ? fit : fit - 1).clamp(0, occurrences.length);
                    return ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final occurrence in occurrences.take(shown))
                              Padding(
                                padding: const EdgeInsets.only(bottom: CoeloSpacing.spaceHalf),
                                child: _AgendaEventPill(occurrence: occurrence),
                              ),
                            if (occurrences.length > shown)
                              Text(
                                '+${occurrences.length - shown}',
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilha de evento na célula do mês (referência iOS): fundo suave na cor
/// da categoria, ícone pequeno e título truncado; cancelado fica hachurado,
/// com o prefixo "CANCELADO:" e o horário abaixo.
final class _AgendaEventPill extends StatelessWidget {
  const _AgendaEventPill({required this.occurrence});

  final AgendaOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canceled = occurrence.item.status == AgendaItemStatus.canceled;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: canceled ? colors.onSurfaceVariant : colors.onSurface,
    );
    final radius = BorderRadius.circular(CoeloRadius.xs);
    final label = canceled ? 'CANCELADO: ${occurrence.item.title}' : occurrence.item.title;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: canceled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
                if (!occurrence.item.allDay) Text(_time(occurrence.startsAt), style: style),
              ],
            )
          : Row(
              children: [
                Icon(_eventIcon(occurrence.item.type), size: 10, color: colors.onSurface),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: style,
                  ),
                ),
              ],
            ),
    );
    if (canceled) {
      return ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: _HatchPainter(
            background: colors.surfaceContainerHighest,
            stroke: colors.outlineVariant,
          ),
          child: content,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _eventColor(colors, occurrence.item.prominence),
        borderRadius: radius,
      ),
      child: content,
    );
  }
}

/// Fundo hachurado (linhas diagonais finas) do evento cancelado no mês.
final class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.background, required this.stroke});

  final Color background, stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = stroke
      ..strokeWidth = 1;
    const step = 6.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.background != background || old.stroke != stroke;
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
