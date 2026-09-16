import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../auth/domain/logout_action.dart';
import '../daily_routine/daily_routine.dart';
import 'attendance.dart';
import 'attendance_history_controller.dart';

/// Segmentos lineares do Histórico (spec 052 §3): chamadas lançadas e, quando
/// há repositório de rotina, os lançamentos de rotina que saíram do diretório
/// de Rotina diária.
enum AttendanceHistorySegment { calls, launches }

/// Acompanhamento › Assiduidade › Histórico (ADR 0041 B2, `owner.r12-04`).
///
/// Tela de consulta: tabela de chamadas com filtros por instituição, unidade,
/// turma, atividade, situação e período; clicar abre o detalhe já existente.
/// Nenhuma edição de presença acontece aqui. A composição segue o diretório
/// administrativo (Instituições) em modo só tabela, com paginação por cursor.
class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({
    required this.repository,
    required this.logout,
    required this.onOpenCall,
    this.routineRepository,
    this.onPublishLaunch,
    this.initialSegment = AttendanceHistorySegment.calls,
    this.activityController,
    this.onDestinationSelected,
    this.today,
    super.key,
  });

  final AttendanceHistoryRepository repository;
  final LogoutAction logout;
  final ValueChanged<String>? onOpenCall;

  /// Lançamentos de rotina (D7). Sem repositório o segmento não aparece.
  final RoutineDirectoryRepository? routineRepository;

  /// Publicar um lançamento em rascunho (`daily-routine.publish`); devolve
  /// `true` quando o servidor confirmou e a lista deve ser relida.
  final Future<bool> Function(RoutineDirectoryItem launch)? onPublishLaunch;
  final AttendanceHistorySegment initialSegment;
  final SuperadminActivityController? activityController;
  final ValueChanged<String>? onDestinationSelected;
  final DateTime? today;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late AttendanceHistoryController _controller;
  late AttendanceHistorySegment _segment;
  var _footerHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _segment = widget.routineRepository == null
        ? AttendanceHistorySegment.calls
        : widget.initialSegment;
    _controller = _newController()..load();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    _controller.dispose();
    _controller = _newController()..load();
  }

  AttendanceHistoryController _newController() => AttendanceHistoryController(
    repository: widget.repository,
    today: DateUtils.dateOnly(widget.today ?? DateTime.now()),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Histórico de chamadas',
    subtitle: 'Chamadas lançadas no escopo autorizado; abra uma para ver o detalhe.',
    currentDestination: 'attendance-history',
    onDestinationSelected: widget.onDestinationSelected,
    activityController: widget.activityController,
    chatLauncherBottomInset: _footerHeight,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _segment == AttendanceHistorySegment.launches
            ? _RoutineLaunchesSegment(
                key: const Key('attendance-history-launches'),
                repository: widget.routineRepository!,
                onPublishLaunch: widget.onPublishLaunch,
                tabs: _tabs(),
              )
            : _CallsDirectory(
                controller: _controller,
                onOpenCall: widget.onOpenCall,
                tabs: _tabs(),
                onFooterHeightChanged: (height) {
                  if ((_footerHeight - height).abs() >= 0.5) {
                    setState(() => _footerHeight = height);
                  }
                },
              ),
      ),
    ),
  );

  Widget? _tabs() => widget.routineRepository == null
      ? null
      : CoeloAdminUnderlineTabs<AttendanceHistorySegment>(
          key: const Key('attendance-history-segments'),
          selected: _segment,
          tabs: const [
            CoeloAdminUnderlineTab(value: AttendanceHistorySegment.calls, label: 'Chamadas'),
            CoeloAdminUnderlineTab(
              value: AttendanceHistorySegment.launches,
              label: 'Lançamentos de rotina',
            ),
          ],
          onSelected: (value) => setState(() => _segment = value),
        );
}

class _CallsDirectory extends StatelessWidget {
  const _CallsDirectory({
    required this.controller,
    required this.onOpenCall,
    required this.tabs,
    required this.onFooterHeightChanged,
  });

  final AttendanceHistoryController controller;
  final ValueChanged<String>? onOpenCall;
  final Widget? tabs;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final query = state.query;
    final options = state.options;
    final today = controller.today;
    final units = options?.units
            .where((unit) => query.institutionId == null || unit.institutionId == query.institutionId)
            .toList(growable: false) ??
        const <AttendanceContextOption>[];
    final groups = options?.groups
            .where(
              (group) =>
                  (query.institutionId == null || group.institutionId == query.institutionId) &&
                  (query.unitId == null || group.unitId == query.unitId),
            )
            .toList(growable: false) ??
        const <AttendanceContextOption>[];
    final activities = options?.activities
            .where((activity) => query.groupId != null && activity.groupId == query.groupId)
            .toList(growable: false) ??
        const <AttendanceContextOption>[];

    return CoeloAdminDirectory<AttendanceHistorySegment>(
      scrollKey: const Key('attendance-history-scroll'),
      loadingKey: const Key('attendance-history-loading'),
      status: switch (state.status) {
        AttendanceHistoryStatus.loading => CoeloAdminDirectoryStatus.loading,
        AttendanceHistoryStatus.data => CoeloAdminDirectoryStatus.success,
        AttendanceHistoryStatus.empty => CoeloAdminDirectoryStatus.empty,
        AttendanceHistoryStatus.noResults => CoeloAdminDirectoryStatus.noResults,
        AttendanceHistoryStatus.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
        AttendanceHistoryStatus.error ||
        AttendanceHistoryStatus.unavailable => CoeloAdminDirectoryStatus.failure,
      },
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhuma chamada no período',
        emptyIcon: Icons.fact_check_outlined,
        noResults: 'Nenhuma chamada encontrada',
        noResultsIcon: Icons.search_off_rounded,
        failure: 'Histórico indisponível',
        failureIcon: Icons.error_outline_rounded,
        unauthorized: 'Acesso não autorizado',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      errorMessage: switch (state.status) {
        AttendanceHistoryStatus.empty => 'As chamadas lançadas aparecem aqui após o primeiro registro.',
        AttendanceHistoryStatus.noResults => 'Ajuste os filtros ou o período.',
        AttendanceHistoryStatus.unavailable =>
          'Este host ainda não possui uma fonte produtiva autorizada.',
        AttendanceHistoryStatus.error => state.errorMessage,
        AttendanceHistoryStatus.unauthorized =>
          'Seu acesso a este escopo não permite consultar o histórico.',
        _ => null,
      },
      onRetry: state.status == AttendanceHistoryStatus.unavailable ? null : controller.load,
      onClearFilters: state.hasFilters ? controller.clearFilters : null,
      search: const SizedBox.shrink(),
      searchWidth: 0,
      filters: [
        CoeloAdminSingleSelectField<String?>(
          key: const Key('attendance-history-filter-institution'),
          label: 'Instituição',
          value: query.institutionId,
          options: <String?>[null, ...?options?.institutions.map((item) => item.id)],
          optionLabel: (value) => value == null
              ? 'Todas as instituições'
              : _optionName(options?.institutions, value),
          onChanged: controller.changeInstitution,
          prefixIcon: Icons.account_balance_outlined,
          isFilter: true,
        ),
        CoeloAdminSingleSelectField<String?>(
          key: const Key('attendance-history-filter-unit'),
          label: 'Unidade',
          value: query.unitId,
          options: <String?>[null, ...units.map((item) => item.id)],
          optionLabel: (value) => value == null ? 'Todas as unidades' : _optionName(units, value),
          onChanged: controller.changeUnit,
          prefixIcon: Icons.apartment_outlined,
          isFilter: true,
        ),
        CoeloAdminSingleSelectField<String?>(
          key: const Key('attendance-history-filter-group'),
          label: 'Turma',
          value: query.groupId,
          options: <String?>[null, ...groups.map((item) => item.id)],
          optionLabel: (value) => value == null ? 'Todas as turmas' : _optionName(groups, value),
          onChanged: controller.changeGroup,
          prefixIcon: Icons.groups_outlined,
          isFilter: true,
        ),
        if (activities.isNotEmpty)
          CoeloAdminSingleSelectField<String?>(
            key: const Key('attendance-history-filter-activity'),
            label: 'Atividade',
            value: query.activityId,
            options: <String?>[null, ...activities.map((item) => item.id)],
            optionLabel: (value) =>
                value == null ? 'Turma e atividades' : _optionName(activities, value),
            onChanged: controller.changeActivity,
            prefixIcon: Icons.local_activity_outlined,
            isFilter: true,
          ),
        CoeloAdminSingleSelectField<AttendanceHistoryStatusFilter?>(
          key: const Key('attendance-history-filter-status'),
          label: 'Situação',
          value: query.status,
          options: const <AttendanceHistoryStatusFilter?>[
            null,
            AttendanceHistoryStatusFilter.pending,
            AttendanceHistoryStatusFilter.completed,
          ],
          optionLabel: (value) => switch (value) {
            AttendanceHistoryStatusFilter.pending => 'Em andamento',
            AttendanceHistoryStatusFilter.completed => 'Concluídas',
            null => 'Todas as situações',
          },
          onChanged: controller.changeStatus,
          prefixIcon: Icons.filter_alt_outlined,
          isFilter: true,
        ),
        SizedBox(
          width: 300,
          child: CoeloDateRangeField(
            key: const Key('attendance-history-filter-period'),
            value: DateTimeRange(start: query.periodStart, end: query.periodEnd),
            firstDate: DateTime(today.year - 5),
            lastDate: today,
            currentDate: today,
            onChanged: (range) {
              if (range != null) controller.changePeriod(range.start, range.end);
            },
          ),
        ),
      ],
      trailing: [
        if (state.hasFilters)
          TextButton.icon(
            key: const Key('attendance-history-clear-filters'),
            onPressed: controller.clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
          ),
      ],
      tabs: tabs,
      display: CoeloAdminDirectoryDisplay.table,
      onDisplayChanged: (_) {},
      showDisplayToggle: false,
      groupedTableView: AttendanceHistorySegment.calls,
      selectedTableView: AttendanceHistorySegment.calls,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: AttendanceHistorySegment.calls,
          label: 'Chamadas',
        ),
      ],
      onTableViewSelected: (_) {},
      fileActions: null,
      table: _CallsTable(items: state.items, onOpenCall: onOpenCall),
      pagination: state.status == AttendanceHistoryStatus.data
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('attendance-history-pagination'),
              currentPage: state.pageIndex + 1,
              totalPages: state.totalPages,
              onPageSelected: controller.goToPage,
            )
          : null,
      onFooterHeightChanged: onFooterHeightChanged,
    );
  }

  String _optionName(List<AttendanceContextOption>? options, String id) =>
      options?.where((item) => item.id == id).map((item) => item.name).firstOrNull ?? id;
}

class _CallsTable extends StatelessWidget {
  const _CallsTable({required this.items, required this.onOpenCall});

  final List<AttendanceHistoryItem> items;
  final ValueChanged<String>? onOpenCall;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<AttendanceHistoryItem>(
    items: items,
    rowKey: (item) => item.id,
    onRowPressed: onOpenCall == null
        ? null
        : (item) {
            if (item.canOpen) onOpenCall!(item.id);
          },
    pinnedColumn: _column('date', 'Data', 130, (item) => _dateLabel(item.date)),
    columns: [
      _column('context', 'Turma / atividade', 260, (item) => item.contextName),
      _column('unit', 'Unidade', 200, (item) => item.unitName),
      _column('responsible', 'Quem lançou', 180, (item) => item.responsible),
      _column('present', 'Presentes', 110, (item) => '${item.present}'),
      _column('absent', 'Ausentes', 110, (item) => '${item.absent}'),
      _column('expected', 'Esperados', 110, (item) => '${item.expected}'),
      CoeloAdminTableColumn<AttendanceHistoryItem>(
        id: 'routine',
        label: 'Rotina',
        initialWidth: 240,
        minWidth: CoeloSize.touchMin * 2,
        maxWidth: 480,
        cellBuilder: (context, item) => _RoutineCell(routine: item.routine, status: item.status),
      ),
      _column('status', 'Situação', 140, (item) => attendanceHistoryStatusLabel(item.status)),
      if (onOpenCall != null)
        CoeloAdminTableColumn<AttendanceHistoryItem>(
          id: 'actions',
          label: 'Ações',
          initialWidth: CoeloSize.touchMin * 2,
          minWidth: CoeloSize.touchMin * 2,
          maxWidth: CoeloSize.touchMin * 3,
          cellBuilder: (context, item) => item.canOpen
              ? IconButton(
                  key: ValueKey('attendance-history-open-${item.id}'),
                  tooltip: 'Abrir chamada',
                  onPressed: () => onOpenCall!(item.id),
                  icon: const Icon(Icons.open_in_new_rounded),
                )
              : const SizedBox.shrink(),
        ),
    ],
    headerHeight: CoeloSize.touchMin,
    rowHeight: CoeloSize.touchMin,
  );
}

class _RoutineCell extends StatelessWidget {
  const _RoutineCell({required this.routine, required this.status});

  final AttendanceRoutineRef routine;
  final AttendanceCallStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualifier = routine.sourceLabel(
      concluded: AttendanceRoutineRef.statusConcluded(status),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: qualifier == null ? routine.label : '${routine.label} — $qualifier',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routine.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (qualifier != null && routine.isLegacyFor(status))
              Text(
                qualifier,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lançamentos de rotina (D7) que saíram do diretório de Rotina diária:
/// lista somente leitura com Publicar apenas em rascunho (spec 052 §3).
class _RoutineLaunchesSegment extends StatefulWidget {
  const _RoutineLaunchesSegment({
    required this.repository,
    required this.onPublishLaunch,
    required this.tabs,
    super.key,
  });

  final RoutineDirectoryRepository repository;
  final Future<bool> Function(RoutineDirectoryItem launch)? onPublishLaunch;
  final Widget? tabs;

  @override
  State<_RoutineLaunchesSegment> createState() => _RoutineLaunchesSegmentState();
}

class _RoutineLaunchesSegmentState extends State<_RoutineLaunchesSegment> {
  RoutineDirectoryPage? _launches;
  Map<String, String> _applicationNames = const {};
  var _loading = true;
  String? _error;
  var _unauthorized = false;
  final _publishing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _unauthorized = false;
    });
    try {
      final launches = await widget.repository.fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.launch, pageSize: 50),
      );
      final applications = await widget.repository.fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.application, pageSize: 50),
      );
      if (!mounted) return;
      setState(() {
        _launches = launches;
        _applicationNames = {for (final item in applications.items) item.id: item.name};
        _loading = false;
      });
    } on RoutineRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unauthorized = error.kind == RoutineRepositoryFailureKind.unauthorized;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar os lançamentos de rotina.';
      });
    }
  }

  Future<void> _publish(RoutineDirectoryItem item) async {
    final publish = widget.onPublishLaunch;
    if (publish == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('daily-routine-publish-dialog'),
        title: 'Publicar este lançamento?',
        body: const Text(
          'As famílias autorizadas passam a ver a rotina deste dia. '
          'Depois de publicado, ajustes exigem uma correção com justificativa.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('daily-routine-publish-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Publicar'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing.add(item.id));
    try {
      final published = await publish(item);
      if (!mounted) return;
      if (published) await _load();
    } finally {
      if (mounted) setState(() => _publishing.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _launches;
    final canManage = page?.canManage ?? false;
    return CoeloAdminDirectory<AttendanceHistorySegment>(
      scrollKey: const Key('attendance-history-launches-scroll'),
      loadingKey: const Key('attendance-history-launches-loading'),
      status: _loading
          ? CoeloAdminDirectoryStatus.loading
          : _unauthorized
          ? CoeloAdminDirectoryStatus.unauthorized
          : _error != null
          ? CoeloAdminDirectoryStatus.failure
          : (page == null || page.items.isEmpty)
          ? CoeloAdminDirectoryStatus.empty
          : CoeloAdminDirectoryStatus.success,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum lançamento de rotina',
        emptyIcon: Icons.event_note_outlined,
        noResults: 'Nenhum resultado',
        failure: 'Lançamentos indisponíveis',
        failureIcon: Icons.error_outline_rounded,
        unauthorized: 'Acesso não autorizado',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      errorMessage: _error ??
          (page != null && page.items.isEmpty
              ? 'Use "Lançar hoje" em Rotina diária › Rotinas para criar o lançamento do dia.'
              : null),
      onRetry: _load,
      search: const SizedBox.shrink(),
      searchWidth: 0,
      tabs: widget.tabs,
      display: CoeloAdminDirectoryDisplay.table,
      onDisplayChanged: (_) {},
      showDisplayToggle: false,
      groupedTableView: AttendanceHistorySegment.launches,
      selectedTableView: AttendanceHistorySegment.launches,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: AttendanceHistorySegment.launches,
          label: 'Lançamentos de rotina',
        ),
      ],
      onTableViewSelected: (_) {},
      fileActions: null,
      table: CoeloAdminResizableTable<RoutineDirectoryItem>(
        items: page?.items ?? const [],
        rowKey: (item) => item.id,
        pinnedColumn: _launchColumn('date', 'Data', 130, (item) => _launchDateLabel(item.name)),
        columns: [
          _launchColumn(
            'routine',
            'Rotina',
            240,
            (item) => _applicationNames[item.applicationId] ?? 'Rotina aplicada',
          ),
          _launchColumn('status', 'Situação', 140, (item) => routineStatusLabel(item.status)),
          _launchColumn('version', 'Versão', 100, (item) => 'v${item.version}'),
          if (canManage && widget.onPublishLaunch != null)
            CoeloAdminTableColumn<RoutineDirectoryItem>(
              id: 'actions',
              label: 'Ações',
              initialWidth: CoeloSize.touchMin * 2,
              minWidth: CoeloSize.touchMin * 2,
              maxWidth: CoeloSize.touchMin * 3,
              cellBuilder: (context, item) => item.status == 'draft'
                  ? IconButton(
                      key: Key('daily-routine-publish-${item.id}-row'),
                      tooltip: _publishing.contains(item.id) ? 'Publicando…' : 'Publicar lançamento',
                      onPressed: _publishing.contains(item.id) ? null : () => _publish(item),
                      icon: const Icon(Icons.publish_rounded),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
        headerHeight: CoeloSize.touchMin,
        rowHeight: CoeloSize.touchMin,
      ),
    );
  }
}

String attendanceHistoryStatusLabel(AttendanceCallStatus status) => switch (status) {
  AttendanceCallStatus.notStarted => 'Não iniciada',
  AttendanceCallStatus.inProgress => 'Em andamento',
  AttendanceCallStatus.completed => 'Concluída',
  AttendanceCallStatus.reopened => 'Reaberta',
};

CoeloAdminTableColumn<AttendanceHistoryItem> _column(
  String id,
  String label,
  double width,
  String Function(AttendanceHistoryItem item) value,
) => CoeloAdminTableColumn<AttendanceHistoryItem>(
  id: id,
  label: label,
  initialWidth: width,
  minWidth: CoeloSize.touchMin * 2,
  maxWidth: 480,
  cellBuilder: (context, item) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  ),
);

CoeloAdminTableColumn<RoutineDirectoryItem> _launchColumn(
  String id,
  String label,
  double width,
  String Function(RoutineDirectoryItem item) value,
) => CoeloAdminTableColumn<RoutineDirectoryItem>(
  id: id,
  label: label,
  initialWidth: width,
  minWidth: CoeloSize.touchMin * 2,
  maxWidth: 480,
  cellBuilder: (context, item) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  ),
);

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _launchDateLabel(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  return parsed == null ? isoDate : routineCivilDate(parsed);
}
