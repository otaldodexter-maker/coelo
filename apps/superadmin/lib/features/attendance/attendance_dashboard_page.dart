import 'dart:math' as math;

import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../auth/domain/logout_action.dart';
import 'attendance.dart';
import 'attendance_dashboard_controller.dart';

class AttendanceDashboardPage extends StatefulWidget {
  const AttendanceDashboardPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    required this.onCreate,
    required this.onOpenCall,
    this.dashboardRepository,
    this.activityController,
    super.key,
  });

  final AttendanceRepository repository;
  final AttendanceDashboardRepository? dashboardRepository;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpenCall;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceDashboardPage> createState() => _AttendanceDashboardPageState();
}

class _AttendanceDashboardPageState extends State<AttendanceDashboardPage> {
  late final AttendanceDashboardController? _controller;
  late final DateTime _today;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repository =
        widget.dashboardRepository ??
        (widget.repository is AttendanceDashboardRepository
            ? widget.repository as AttendanceDashboardRepository
            : null);
    _today = DateUtils.dateOnly(DateTime.now());
    _controller = repository == null
        ? null
        : AttendanceDashboardController(
            repository: repository,
            initialQuery: AttendanceDashboardQuery(
              periodStart: DateTime(_today.year, _today.month),
              periodEnd: _today,
            ),
          );
    _controller?.load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Assiduidade',
    subtitle: 'Visão consolidada de presença e chamadas no escopo autorizado.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final controller = _controller;
          if (controller == null) {
            return Padding(
              padding: EdgeInsets.all(inset),
              child: const CoeloStatePanel(
                title: 'Dashboard indisponível',
                message: 'Este host ainda não possui uma fonte produtiva autorizada.',
                icon: Icons.lock_outline_rounded,
              ),
            );
          }
          return ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _DashboardStateView(
              controller: controller,
              searchController: _searchController,
              today: _today,
              maxWidth: constraints.maxWidth,
              inset: inset,
              onCreate: widget.onCreate,
              onOpenCall: widget.onOpenCall,
            ),
          );
        },
      ),
    ),
  );
}

class _DashboardStateView extends StatelessWidget {
  const _DashboardStateView({
    required this.controller,
    required this.searchController,
    required this.today,
    required this.maxWidth,
    required this.inset,
    required this.onCreate,
    required this.onOpenCall,
  });

  final AttendanceDashboardController controller;
  final TextEditingController searchController;
  final DateTime today;
  final double maxWidth;
  final double inset;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpenCall;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final snapshot = switch (state) {
      AttendanceDashboardReady(:final snapshot) ||
      AttendanceDashboardEmpty(:final snapshot) => snapshot,
      AttendanceDashboardLoading(:final previous) ||
      AttendanceDashboardFailure(previous: final previous) => previous,
      _ => null,
    };
    if (snapshot != null) {
      return Stack(
        children: [
          _DashboardContent(
            snapshot: snapshot,
            controller: controller,
            searchController: searchController,
            today: today,
            maxWidth: maxWidth,
            inset: inset,
            onCreate: onCreate,
            onOpenCall: onOpenCall,
          ),
          if (state is AttendanceDashboardLoading)
            const PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: LinearProgressIndicator(minHeight: CoeloSpacing.space1),
            ),
          if (state is AttendanceDashboardFailure)
            PositionedDirectional(
              top: CoeloSpacing.space2,
              start: inset,
              end: inset,
              child: Semantics(
                liveRegion: true,
                label: 'Não foi possível atualizar. Os dados exibidos podem estar desatualizados.',
                child: Container(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(CoeloRadius.lg),
                    border: Border.all(color: Theme.of(context).colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem_rounded),
                      const SizedBox(width: CoeloSpacing.space3),
                      const Expanded(
                        child: Text('Não foi possível atualizar. Exibindo os últimos dados.'),
                      ),
                      OutlinedButton(
                        onPressed: controller.retry,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final panel = switch (state) {
      AttendanceDashboardUnauthorizedState() => const CoeloStatePanel(
        title: 'Acesso não autorizado',
        message: 'Você não possui permissão para consultar esta visão.',
        icon: Icons.lock_outline_rounded,
      ),
      AttendanceDashboardFailure() => CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Confira a conexão e tente novamente.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: controller.retry,
      ),
      _ => const CoeloStatePanel(
        title: 'Carregando assiduidade',
        message: 'Buscando somente os dados do seu escopo.',
        loading: true,
      ),
    };
    return Padding(padding: EdgeInsets.all(inset), child: panel);
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.controller,
    required this.searchController,
    required this.today,
    required this.maxWidth,
    required this.inset,
    required this.onCreate,
    required this.onOpenCall,
  });

  final AttendanceDashboardSnapshot snapshot;
  final AttendanceDashboardController controller;
  final TextEditingController searchController;
  final DateTime today;
  final double maxWidth;
  final double inset;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpenCall;

  bool get _wide => maxWidth >= CoeloBreakpoints.large.minWidth;
  bool get _twoColumns => maxWidth >= CoeloBreakpoints.expanded.minWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(inset),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardHeader(access: snapshot.access, onCreate: onCreate),
        const SizedBox(height: CoeloSpacing.space6),
        _Filters(query: snapshot.query, controller: controller, today: today),
        const SizedBox(height: CoeloSpacing.space4),
        _TopBand(snapshot: snapshot, wide: _wide, controller: controller, today: today),
        const SizedBox(height: CoeloSpacing.space4),
        _SectionSurface(
          title: 'Desempenho por contexto',
          subtitle: snapshot.contextLabel,
          child: _RankingGrid(
            rankings: snapshot.rankings,
            twoColumns: _twoColumns,
            controller: controller,
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _SectionSurface(
          title: 'Presença no período',
          subtitle: snapshot.contextLabel,
          child: _AttendanceChart(points: snapshot.series),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _CallsSection(
          snapshot: snapshot,
          controller: controller,
          searchController: searchController,
          onOpenCall: onOpenCall,
        ),
      ],
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.access, required this.onCreate});
  final AttendanceDashboardAccess access;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: CoeloSpacing.space4,
    runSpacing: CoeloSpacing.space3,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visão geral da assiduidade', style: Theme.of(context).textTheme.titleLarge),
          const Text('Indicadores calculados sobre registros oficiais válidos.'),
        ],
      ),
      if (access.canCreateCall)
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nova chamada'),
        ),
    ],
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.query, required this.controller, required this.today});
  final AttendanceDashboardQuery query;
  final AttendanceDashboardController controller;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: CoeloDateRangeField(
            value: DateTimeRange(start: query.periodStart, end: query.periodEnd),
            firstDate: DateTime(today.year - 5),
            lastDate: today,
            currentDate: today,
            onChanged: (range) {
              if (range != null) controller.changePeriod(range.start, range.end);
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: CoeloAdminSingleSelectField<AttendanceDashboardGranularity>(
            label: 'Granularidade',
            value: query.granularity,
            options: AttendanceDashboardGranularity.values,
            optionLabel: _granularityLabel,
            onChanged: controller.changeGranularity,
            prefixIcon: Icons.calendar_view_week_outlined,
          ),
        ),
        if (_breadcrumbs(query).isNotEmpty)
          Semantics(
            label: 'Contexto aplicado: ${_breadcrumbs(query).join(', ')}',
            child: Wrap(
              spacing: CoeloSpacing.space2,
              children: _breadcrumbs(query).map((label) => Chip(label: Text(label))).toList(),
            ),
          ),
      ],
    );
  }
}

class _TopBand extends StatelessWidget {
  const _TopBand({
    required this.snapshot,
    required this.wide,
    required this.controller,
    required this.today,
  });
  final AttendanceDashboardSnapshot snapshot;
  final bool wide;
  final AttendanceDashboardController controller;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final calendar = _SectionSurface(
      title: 'Período',
      child: CoeloDateRangePicker(
        value: DateTimeRange(start: snapshot.query.periodStart, end: snapshot.query.periodEnd),
        firstDate: DateTime(today.year - 5),
        lastDate: today,
        currentDate: today,
        showQuickRanges: false,
        onChanged: (range) {
          if (range != null) controller.changePeriod(range.start, range.end);
        },
      ),
    );
    final kpis = _KpiGrid(kpis: snapshot.kpis);
    final attention = _Attention(items: snapshot.attention);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kpis,
          const SizedBox(height: CoeloSpacing.space4),
          attention,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: calendar),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(flex: 6, child: kpis),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(flex: 4, child: attention),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});
  final AttendanceDashboardKpis kpis;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final oneColumn =
          constraints.maxWidth < CoeloBreakpoints.medium.minWidth ||
          MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      final width = oneColumn
          ? constraints.maxWidth
          : math.max(0, (constraints.maxWidth - CoeloSpacing.space3) / 2).toDouble();
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [
          _KpiTile(
            key: const Key('attendance-kpi-presence'),
            width: width,
            icon: Icons.groups_2_outlined,
            value: _rateLabel(kpis.presence),
            label: 'Presença geral',
            helper: kpis.presence.isSufficient
                ? '${kpis.presence.officialRecords} registros oficiais'
                : 'Dados insuficientes: nenhum registro oficial válido.',
          ),
          _KpiTile(
            key: const Key('attendance-kpi-pending'),
            width: width,
            icon: Icons.schedule_outlined,
            value: '${kpis.pendingCalls}',
            label: 'Chamadas pendentes',
            helper: 'Aguardando conclusão',
          ),
          _KpiTile(
            key: const Key('attendance-kpi-absences'),
            width: width,
            icon: Icons.person_off_outlined,
            value: '${kpis.absences}',
            label: 'Faltas no período',
            helper: 'Em registros oficiais válidos',
          ),
          _KpiTile(
            key: const Key('attendance-kpi-review'),
            width: width,
            icon: Icons.fact_check_outlined,
            value: '${kpis.inReview}',
            label: 'Em revisão',
            helper: 'Avisos familiares pendentes',
          ),
        ],
      );
    },
  );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    super.key,
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.helper,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value. $helper',
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin * 3),
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  Text(helper, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.items});
  final List<AttendanceAttentionItem> items;

  @override
  Widget build(BuildContext context) => _SectionSurface(
    title: 'Atenção necessária',
    child: items.isEmpty
        ? const Text('Nenhuma pendência autorizada no período.')
        : Column(
            children: items
                .map(
                  (item) => Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: Text('${item.count} ${item.label}\n${item.detail}')),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _RankingGrid extends StatelessWidget {
  const _RankingGrid({required this.rankings, required this.twoColumns, required this.controller});
  final List<AttendanceRanking> rankings;
  final bool twoColumns;
  final AttendanceDashboardController controller;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) return const Text('Nenhum contexto disponível para este perfil.');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = twoColumns
            ? (constraints.maxWidth - CoeloSpacing.space4) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: CoeloSpacing.space4,
          runSpacing: CoeloSpacing.space4,
          children: rankings.map((ranking) {
            return SizedBox(
              width: width,
              child: _RankingPanel(ranking: ranking, controller: controller),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({required this.ranking, required this.controller});
  final AttendanceRanking ranking;
  final AttendanceDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final title = _rankingTitle(ranking.kind);
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: CoeloSpacing.space2,
            children: [
              Text('$title · ${ranking.total}', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                width: 190,
                child: CoeloAdminSingleSelectField<AttendanceRankingDirection>(
                  label: ranking.kind == AttendanceRankingKind.teachers ? 'Conclusão' : 'Presença',
                  value: ranking.direction,
                  options: AttendanceRankingDirection.values,
                  optionLabel: (value) => value == AttendanceRankingDirection.highest
                      ? 'Maior ${ranking.kind == AttendanceRankingKind.teachers ? 'conclusão' : 'presença'}'
                      : 'Menor ${ranking.kind == AttendanceRankingKind.teachers ? 'conclusão' : 'presença'}',
                  onChanged: controller.changeRankingDirection,
                  prefixIcon: Icons.sort_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          ...ranking.items
              .take(3)
              .map(
                (item) => _RankingRow(
                  key: ValueKey('${ranking.kind.name}-${item.id}'),
                  item: item,
                  kind: ranking.kind,
                  selected: _selectedId(controller.query, ranking.kind) == item.id,
                  onPressed: () => _selectRanking(controller, ranking.kind, item.id),
                ),
              ),
          if (ranking.items.isEmpty) const Text('Dados insuficientes neste contexto.'),
          if (ranking.total > 3)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _RankingDialog(
                    repository: controller.repository,
                    query: controller.query,
                    kind: ranking.kind,
                  ),
                ),
                child: const Text('Ver todos'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RankingDialog extends StatefulWidget {
  const _RankingDialog({required this.repository, required this.query, required this.kind});
  final AttendanceDashboardRepository repository;
  final AttendanceDashboardQuery query;
  final AttendanceRankingKind kind;

  @override
  State<_RankingDialog> createState() => _RankingDialogState();
}

class _RankingDialogState extends State<_RankingDialog> {
  static const _pageSize = 20;
  var _page = 1;
  late Future<AttendanceRanking> _result = _load();

  Future<AttendanceRanking> _load() => widget.repository.fetchRanking(
    query: widget.query,
    kind: widget.kind,
    page: _page,
    pageSize: _pageSize,
  );

  void _changePage(int value) {
    setState(() {
      _page = value;
      _result = _load();
    });
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('attendance-ranking-dialog'),
    closeButtonKey: const Key('attendance-ranking-dialog-close'),
    title: _rankingTitle(widget.kind),
    closeTooltip: 'Fechar listagem de contexto',
    body: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
      child: FutureBuilder<AttendanceRanking>(
        future: _result,
        builder: (context, result) {
          if (result.hasError) {
            return CoeloStatePanel(
              title: 'Não foi possível carregar',
              message: 'Tente novamente.',
              actionLabel: 'Tentar novamente',
              onAction: () => _changePage(_page),
            );
          }
          final ranking = result.data;
          if (ranking == null) return const Center(child: CircularProgressIndicator());
          final totalPages = math.max(1, (ranking.total / _pageSize).ceil());
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ranking.items.length,
                  separatorBuilder: (_, _) => const Divider(height: CoeloSpacing.space1),
                  itemBuilder: (context, index) {
                    final item = ranking.items[index];
                    return SizedBox(
                      key: ValueKey('ranking-dialog-${widget.kind.name}-${item.id}'),
                      height: CoeloSize.touchMin,
                      child: Row(
                        children: [
                          Expanded(child: Text(item.label)),
                          Text(_rateLabel(item.rate)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminPagination(
                currentPage: _page,
                totalPages: totalPages,
                onPrevious: _page > 1 ? () => _changePage(_page - 1) : null,
                onNext: _page < totalPages ? () => _changePage(_page + 1) : null,
                onPageSelected: _changePage,
              ),
            ],
          );
        },
      ),
    ),
    primaryAction: FilledButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Fechar'),
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.item,
    required this.kind,
    required this.selected,
    required this.onPressed,
    super.key,
  });
  final AttendanceRankingItem item;
  final AttendanceRankingKind kind;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${item.label}, ${_rateLabel(item.rate)}',
      child: CoeloAdminInteractiveCard(
        onPressed: onPressed,
        minHeight: CoeloSize.touchMin,
        child: Container(
          padding: const EdgeInsets.all(CoeloSpacing.space2),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer.withValues(alpha: 0.35) : null,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            border: selected ? Border.all(color: colors.primary, width: 2) : null,
          ),
          child: Row(
            children: [
              if (selected) ...[
                Icon(Icons.check_circle_outline, color: colors.primary),
                const SizedBox(width: CoeloSpacing.space2),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: CoeloSpacing.space1),
                    LinearProgressIndicator(
                      value: item.rate.percent == null ? 0 : item.rate.percent! / 100,
                      minHeight: CoeloSpacing.space1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Flexible(child: Text(_rateLabel(item.rate), textAlign: TextAlign.end)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.points});
  final List<AttendanceSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Text('Dados insuficientes para traçar o período.');
    final colors = Theme.of(context).colorScheme;
    final currentDescription = points
        .map((point) => '${point.label}: ${_rateLabel(point.current)}')
        .join('; ');
    final previousDescription = points
        .where((point) => point.previous != null)
        .map((point) => '${point.label}: ${_rateLabel(point.previous!)}')
        .join('; ');
    final hasPrevious = previousDescription.isNotEmpty;
    return Semantics(
      key: const Key('attendance-series-chart'),
      excludeSemantics: true,
      label:
          'Gráfico de presença. Período atual: $currentDescription.'
          '${hasPrevious ? ' Período anterior, linha tracejada com marcadores quadrados: $previousDescription.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space2,
            children: [
              _SeriesLegendItem(label: 'Período atual', color: colors.primary),
              if (hasPrevious)
                _SeriesLegendItem(label: 'Período anterior', color: colors.outline, dashed: true),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _AttendanceSeriesPainter(
                points: points.map((item) => item.current.percent).toList(growable: false),
                previous: points.map((item) => item.previous?.percent).toList(growable: false),
                currentColor: colors.primary,
                previousColor: colors.outline,
                gridColor: colors.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesLegendItem extends StatelessWidget {
  const _SeriesLegendItem({required this.label, required this.color, this.dashed = false});

  final String label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: CoeloSize.touchMin / 2,
        child: dashed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  3,
                  (_) => ColoredBox(color: color, child: const SizedBox(width: 5, height: 2)),
                ),
              )
            : ColoredBox(color: color, child: const SizedBox(height: 2)),
      ),
      const SizedBox(width: CoeloSpacing.space2),
      Flexible(child: Text(label)),
    ],
  );
}

class _AttendanceSeriesPainter extends CustomPainter {
  const _AttendanceSeriesPainter({
    required this.points,
    required this.previous,
    required this.currentColor,
    required this.previousColor,
    required this.gridColor,
  });
  final List<double?> points;
  final List<double?> previous;
  final Color currentColor;
  final Color previousColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = gridColor;
    for (var index = 0; index <= 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), grid);
    }
    _drawSeries(canvas, size, previous, previousColor, dashed: true);
    _drawSeries(canvas, size, points, currentColor);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double?> values,
    Color color, {
    bool dashed = false,
  }) {
    if (values.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final geometry = _seriesGeometry(size, values);
    for (final point in geometry.markers) {
      final marker = Paint()..color = color;
      if (dashed) {
        canvas.drawRect(Rect.fromCenter(center: point, width: 6, height: 6), marker);
      } else {
        canvas.drawCircle(point, 3, marker);
      }
    }
    if (dashed) {
      _drawDashedPath(canvas, geometry.path, paint);
    } else {
      canvas.drawPath(geometry.path, paint);
    }
  }

  ({Path path, List<Offset> markers, int segmentCount}) _seriesGeometry(
    Size size,
    List<double?> values,
  ) {
    final path = Path();
    final markers = <Offset>[];
    var started = false;
    var segmentCount = 0;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        started = false;
        continue;
      }
      final point = Offset(
        size.width * index / (values.length - 1),
        size.height * (1 - value.clamp(0, 100) / 100),
      );
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
        segmentCount++;
      }
      markers.add(point);
    }
    return (path: path, markers: markers, segmentCount: segmentCount);
  }

  @visibleForTesting
  ({int markerCount, int segmentCount}) debugSeriesTopology(Size size, List<double?> values) {
    final geometry = _seriesGeometry(size, values);
    return (markerCount: geometry.markers.length, segmentCount: geometry.segmentCount);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + dashLength, metric.length)),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceSeriesPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.previous != previous ||
      oldDelegate.currentColor != currentColor ||
      oldDelegate.previousColor != previousColor ||
      oldDelegate.gridColor != gridColor;
}

class _CallsSection extends StatelessWidget {
  const _CallsSection({
    required this.snapshot,
    required this.controller,
    required this.searchController,
    required this.onOpenCall,
  });
  final AttendanceDashboardSnapshot snapshot;
  final AttendanceDashboardController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onOpenCall;

  @override
  Widget build(BuildContext context) => _SectionSurface(
    title: 'Últimas chamadas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: CoeloSearchField(
            controller: searchController,
            onChanged: controller.changeSearch,
            semanticLabel: 'Buscar chamada',
            hintText: 'Buscar chamada',
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space3,
          children: [
            SizedBox(
              width: 220,
              child: CoeloAdminSingleSelectField<String>(
                label: 'Status',
                value: snapshot.query.statuses.length != 1
                    ? 'all'
                    : snapshot.query.statuses.single.name,
                options: const ['all', 'pending', 'completed', 'inReview'],
                optionLabel: (value) => switch (value) {
                  'pending' => 'Pendente',
                  'completed' => 'Concluída',
                  'inReview' => 'Em revisão',
                  _ => 'Todos os status',
                },
                onChanged: (value) => controller.changeStatuses(
                  value == 'all' ? const {} : {AttendanceDashboardCallStatus.values.byName(value)},
                ),
                prefixIcon: Icons.filter_alt_outlined,
              ),
            ),
            SizedBox(
              width: 220,
              child: CoeloAdminSingleSelectField<AttendanceDashboardCallSort>(
                label: 'Ordenar por',
                value: snapshot.query.sort,
                options: AttendanceDashboardCallSort.values,
                optionLabel: _sortLabel,
                onChanged: controller.changeSort,
                prefixIcon: Icons.sort_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (snapshot.calls.items.isEmpty)
          const Text('Nenhuma chamada encontrada para os filtros atuais.')
        else
          CoeloAdminResizableTable<AttendanceDashboardCallRow>(
            items: snapshot.calls.items,
            rowKey: (item) => item.id,
            pinnedColumn: _column('context', 'Contexto', 300, (item) => item.context),
            columns: [
              _column('date', 'Data', 160, (item) => _dateLabel(item.date)),
              _column('responsible', 'Responsável', 180, (item) => item.responsible),
              _column('present', 'Presentes', 110, (item) => '${item.present}'),
              _column('absent', 'Faltas', 100, (item) => '${item.absent}'),
              _column('late', 'Atrasos', 100, (item) => '${item.late}'),
              _column('presence', 'Presença', 120, (item) => _rateLabel(item.presence)),
              _column('status', 'Status', 130, (item) => _statusLabel(item.status)),
              CoeloAdminTableColumn<AttendanceDashboardCallRow>(
                id: 'actions',
                label: 'Ações',
                initialWidth: CoeloSize.touchMin * 2,
                minWidth: CoeloSize.touchMin * 2,
                maxWidth: CoeloSize.touchMin * 3,
                cellBuilder: (context, item) => item.canOpen
                    ? IconButton(
                        key: ValueKey('attendance-open-${item.id}'),
                        tooltip: 'Abrir chamada',
                        onPressed: () => onOpenCall(item.id),
                        icon: const Icon(Icons.open_in_new_rounded),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            headerHeight: CoeloSize.touchMin,
            rowHeight: CoeloSize.touchMin,
          ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminPagination(
          currentPage: snapshot.calls.page,
          totalPages: snapshot.calls.totalPages,
          pageSize: snapshot.calls.pageSize,
          pageSizeOptions: const [10, 20, 50],
          onPageSizeChanged: controller.changePageSize,
          onPrevious: snapshot.calls.page > 1
              ? () => controller.changePage(snapshot.calls.page - 1)
              : null,
          onNext: snapshot.calls.page < snapshot.calls.totalPages
              ? () => controller.changePage(snapshot.calls.page + 1)
              : null,
          onPageSelected: controller.changePage,
        ),
      ],
    ),
  );
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: CoeloSpacing.space3),
          child,
        ],
      ),
    );
  }
}

CoeloAdminTableColumn<AttendanceDashboardCallRow> _column(
  String id,
  String label,
  double width,
  String Function(AttendanceDashboardCallRow item) value,
) => CoeloAdminTableColumn<AttendanceDashboardCallRow>(
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

void _selectRanking(
  AttendanceDashboardController controller,
  AttendanceRankingKind kind,
  String id,
) {
  switch (kind) {
    case AttendanceRankingKind.institutions:
      controller.selectInstitution(id);
    case AttendanceRankingKind.units:
      controller.selectUnit(id);
    case AttendanceRankingKind.groups:
      controller.selectGroup(id);
    case AttendanceRankingKind.activities:
      controller.selectActivity(id);
    case AttendanceRankingKind.students:
      controller.selectChild(id);
    case AttendanceRankingKind.teachers:
      break;
  }
}

String? _selectedId(AttendanceDashboardQuery query, AttendanceRankingKind kind) => switch (kind) {
  AttendanceRankingKind.institutions => query.institutionId,
  AttendanceRankingKind.units => query.unitId,
  AttendanceRankingKind.groups => query.groupId,
  AttendanceRankingKind.activities => query.activityId,
  AttendanceRankingKind.students => query.childId,
  AttendanceRankingKind.teachers => null,
};

String _rateLabel(AttendanceRate rate) =>
    rate.isSufficient ? '${rate.percent!.toStringAsFixed(1)}%' : 'Dados insuficientes';

String _granularityLabel(AttendanceDashboardGranularity value) => switch (value) {
  AttendanceDashboardGranularity.daily => 'Diária',
  AttendanceDashboardGranularity.weekly => 'Semanal',
  AttendanceDashboardGranularity.monthly => 'Mensal',
};

String _rankingTitle(AttendanceRankingKind value) => switch (value) {
  AttendanceRankingKind.institutions => 'Instituições',
  AttendanceRankingKind.units => 'Unidades',
  AttendanceRankingKind.groups => 'Turmas',
  AttendanceRankingKind.activities => 'Atividades',
  AttendanceRankingKind.students => 'Alunos',
  AttendanceRankingKind.teachers => 'Professores',
};

String _statusLabel(AttendanceDashboardCallStatus value) => switch (value) {
  AttendanceDashboardCallStatus.pending => 'Pendente',
  AttendanceDashboardCallStatus.completed => 'Concluída',
  AttendanceDashboardCallStatus.inReview => 'Em revisão',
};

String _sortLabel(AttendanceDashboardCallSort value) => switch (value) {
  AttendanceDashboardCallSort.context => 'Contexto',
  AttendanceDashboardCallSort.date => 'Data',
  AttendanceDashboardCallSort.responsible => 'Responsável',
  AttendanceDashboardCallSort.presence => 'Presença',
  AttendanceDashboardCallSort.status => 'Status',
};

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

List<String> _breadcrumbs(AttendanceDashboardQuery query) => [
  if (query.institutionId != null) 'Instituição selecionada',
  if (query.unitId != null) 'Unidade selecionada',
  if (query.groupId != null) 'Turma selecionada',
  if (query.activityId != null) 'Atividade selecionada',
  if (query.childId != null) 'Aluno selecionado',
];
