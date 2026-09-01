import 'dart:math';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../../auth/domain/logout_action.dart';
import '../application/child_safety_controller.dart';
import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';

enum _TableView { grouped }

final class SafetyLandingPage extends StatefulWidget {
  const SafetyLandingPage({
    required this.controller,
    required this.logout,
    required this.onOpenChild,
    this.onCreate,
    this.onExport,
    this.onDestinationSelected,
    super.key,
  });
  final ChildSafetyController controller;
  final LogoutAction logout;
  final ValueChanged<String> onOpenChild;
  final VoidCallback? onCreate;
  final VoidCallback? onExport;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<SafetyLandingPage> createState() => _SafetyLandingPageState();
}

final class _SafetyLandingPageState extends State<SafetyLandingPage> {
  final search = TextEditingController();
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;
  bool _measurementScheduled = false;

  void _scheduleFooterMeasurement(bool showFooter) {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      var nextHeight = 0.0;
      if (showFooter) {
        final renderObject = _footerKey.currentContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) return;
        nextHeight = renderObject.size.height;
      }
      if ((nextHeight - _footerHeight).abs() < 0.5) return;
      setState(() => _footerHeight = nextHeight);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller.state == ChildSafetyLoadState.loading) widget.controller.load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Segurança da criança',
    subtitle: 'Autorizações, restrições e alertas com revisão auditada pela unidade.',
    currentDestination: 'safety',
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          if (widget.controller.state == ChildSafetyLoadState.unauthorized) {
            _scheduleFooterMeasurement(false);
            return ColoredBox(
              key: const Key('safety-directory-surface'),
              color: Theme.of(context).colorScheme.surface,
              child: ListView(
                padding: EdgeInsets.all(inset),
                children: const [
                  CoeloStatePanel(
                    title: 'Sem permissão',
                    message: 'O contexto atual não autoriza esta consulta.',
                    icon: Icons.lock_outline_rounded,
                  ),
                ],
              ),
            );
          }
          final showPagination =
              widget.controller.state == ChildSafetyLoadState.ready &&
              widget.controller.totalPages > 1;
          _scheduleFooterMeasurement(showPagination);
          final footerInset = showPagination ? _footerHeight + CoeloSpacing.space4 : 0.0;
          return ColoredBox(
            key: const Key('safety-directory-surface'),
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(inset, inset, inset, inset + footerInset),
                  children: [
                    CoeloAdminListingToolbar(
                      search: SizedBox(
                        width: constraints.maxWidth < 768 ? constraints.maxWidth : 320,
                        height: CoeloSize.touchMin,
                        child: CoeloSearchField(
                          controller: search,
                          hintText: 'Nome ou identificação interna',
                          semanticLabel: 'Buscar criança no escopo autorizado',
                          onChanged: widget.controller.setSearch,
                        ),
                      ),
                      filters: const [],
                      actions: [
                        SuperadminDirectoryViewToggle<_TableView>(
                          cardsSelected:
                              widget.controller.query.view == ChildSafetyDirectoryView.cards,
                          groupedView: _TableView.grouped,
                          selectedTableView: _TableView.grouped,
                          tableViews: const [
                            SuperadminDirectoryTableViewOption(
                              value: _TableView.grouped,
                              label: 'Agrupado',
                            ),
                          ],
                          cardsKey: const Key('safety-view-cards'),
                          tableKey: const Key('safety-view-table'),
                          onCardsSelected: () =>
                              widget.controller.setView(ChildSafetyDirectoryView.cards),
                          onTableViewSelected: (_) =>
                              widget.controller.setView(ChildSafetyDirectoryView.table),
                        ),
                        CoeloAdminFileActions(
                          actions: [
                            CoeloAdminFileAction(
                              key: const Key('safety-import-file'),
                              label: 'Importar',
                              icon: Icons.upload_file_outlined,
                              onPressed: () => showSuperadminNotice(
                                context,
                                'Indisponível nesta etapa',
                                icon: Icons.info_outline_rounded,
                              ),
                            ),
                            CoeloAdminFileAction(
                              key: const Key('safety-export-csv'),
                              label: 'Exportar CSV',
                              icon: Icons.download_outlined,
                              onPressed:
                                  widget.onExport ??
                                  () => showSuperadminNotice(
                                    context,
                                    'Indisponível nesta etapa',
                                    icon: Icons.info_outline_rounded,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    SuperadminUnderlineTabs<ChildSafetyDirectorySegment>(
                      tabs: [
                        for (final value in ChildSafetyDirectorySegment.values)
                          SuperadminUnderlineTab(
                            value: value,
                            label: '${value.label} (${widget.controller.segmentCounts[value]})',
                          ),
                      ],
                      selected: widget.controller.query.segment,
                      onSelected: widget.controller.setStatusSegment,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _body(),
                  ],
                ),
                if (showPagination)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizeChangedLayoutNotifier(
                      key: _footerKey,
                      child: SuperadminListingPaginationFooter(
                        semanticKey: const Key('safety-directory-pagination-footer'),
                        horizontalPadding: inset,
                        compactCurrentPage: widget.controller.currentPage + 1,
                        compactTotalPages: widget.controller.totalPages,
                        compactOnPrevious: widget.controller.currentPage > 0
                            ? () => widget.controller.goToPage(widget.controller.currentPage - 1)
                            : null,
                        compactOnNext:
                            widget.controller.currentPage + 1 < widget.controller.totalPages
                            ? () => widget.controller.goToPage(widget.controller.currentPage + 1)
                            : null,
                        child: _pagination(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
  Widget _body() => switch (widget.controller.state) {
    ChildSafetyLoadState.loading => const CoeloStatePanel(
      title: 'Carregando segurança da criança',
      message: 'Buscando somente contextos autorizados.',
      loading: true,
    ),
    ChildSafetyLoadState.unauthorized => const CoeloStatePanel(
      title: 'Sem permissão',
      message: 'O contexto atual não autoriza esta consulta.',
      icon: Icons.lock_outline_rounded,
    ),
    ChildSafetyLoadState.error => CoeloStatePanel(
      title: 'Não foi possível carregar',
      message: 'Nenhum dado anterior foi mantido.',
      icon: Icons.error_outline_rounded,
      actionLabel: 'Tentar novamente',
      onAction: widget.controller.retry,
    ),
    ChildSafetyLoadState.ready => _ready(),
  };
  Widget _ready() {
    final c = widget.controller;
    if (c.records.isEmpty && !c.canCreate) {
      return CoeloStatePanel(
        title: c.query.hasActiveFilters
            ? 'Nenhuma criança encontrada'
            : 'Nenhuma criança disponível',
        message: 'Revise a busca ou a segmentação.',
        icon: Icons.search_off_rounded,
      );
    }
    return Column(
      children: [
        if (c.query.view == ChildSafetyDirectoryView.cards)
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 1180
                  ? 3
                  : box.maxWidth >= 720
                  ? 2
                  : 1;
              final cards = <Widget>[
                if (c.canCreate && widget.onCreate != null)
                  ConstrainedBox(
                    key: const Key('safety-create-card'),
                    constraints: const BoxConstraints(minHeight: 220),
                    child: CoeloAdminCreateAction(
                      label: 'Criar segurança',
                      icon: Icons.add_moderator_outlined,
                      onPressed: widget.onCreate,
                    ),
                  ),
                for (final record in c.records)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 220),
                    child: SafetyChildDirectoryCard(
                      record: record,
                      onPressed: () => widget.onOpenChild(record.childId),
                    ),
                  ),
              ];
              return Column(
                children: [
                  for (var start = 0; start < cards.length; start += columns) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var column = 0; column < columns; column++) ...[
                            Expanded(
                              child: start + column < cards.length
                                  ? cards[start + column]
                                  : const SizedBox.shrink(),
                            ),
                            if (column + 1 < columns) const SizedBox(width: CoeloSpacing.space6),
                          ],
                        ],
                      ),
                    ),
                    if (start + columns < cards.length) const SizedBox(height: CoeloSpacing.space6),
                  ],
                ],
              );
            },
          )
        else ...[
          if (c.canCreate && widget.onCreate != null) ...[
            CoeloAdminCreateAction(
              key: const Key('safety-create-banner'),
              label: 'Criar segurança',
              description: 'Busque e selecione a criança antes de cadastrar.',
              icon: Icons.add_moderator_outlined,
              variant: CoeloAdminCreateActionVariant.banner,
              onPressed: widget.onCreate,
            ),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          _SafetyTable(records: c.records, onOpen: widget.onOpenChild),
        ],
      ],
    );
  }

  Widget _pagination() {
    final c = widget.controller;
    return CoeloAdminPagination(
      currentPage: c.currentPage + 1,
      totalPages: c.totalPages,
      pageSize: c.pageSize,
      pageSizeOptions: c.query.view == ChildSafetyDirectoryView.cards
          ? const [11, 20, 50, 100]
          : const [8, 20, 50, 100],
      onPageSelected: (value) => c.goToPage(value - 1),
      onPageSizeChanged: c.setPageSize,
      onPrevious: c.currentPage > 0 ? () => c.goToPage(c.currentPage - 1) : null,
      onNext: c.currentPage + 1 < c.totalPages ? () => c.goToPage(c.currentPage + 1) : null,
    );
  }
}

final class SafetyChildDirectoryCard extends StatelessWidget {
  const SafetyChildDirectoryCard({required this.record, required this.onPressed, super.key});
  final ChildSafetyRecord record;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final status = switch (record.directorySegment) {
      ChildSafetyDirectorySegment.awaitingApproval => PickupAuthorizationStatus.pending,
      ChildSafetyDirectorySegment.authorized => PickupAuthorizationStatus.approved,
      ChildSafetyDirectorySegment.attention ||
      ChildSafetyDirectorySegment.withoutAuthorization ||
      ChildSafetyDirectorySegment.all => PickupAuthorizationStatus.rejected,
    };
    final statusLabel = switch (record.directorySegment) {
      ChildSafetyDirectorySegment.awaitingApproval => 'Aguardando aprovação',
      ChildSafetyDirectorySegment.attention => 'Atenção',
      ChildSafetyDirectorySegment.authorized => 'Autorizada',
      ChildSafetyDirectorySegment.withoutAuthorization => 'Sem autorização',
      ChildSafetyDirectorySegment.all => status.label,
    };
    final colors = _statusPair(context, status);
    final active = record.authorizationCount;
    return CoeloAdminInteractiveCard(
      semanticLabel: 'Abrir segurança de ${record.childName}. ${status.label}',
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CoeloAvatar(
                  initials: _initials(record.childName),
                  semanticLabel: 'Avatar de ${record.childName}',
                  size: CoeloAvatarSize.medium,
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.childName, style: Theme.of(context).textTheme.titleMedium),
                      Text(record.internalId),
                    ],
                  ),
                ),
                CoeloAdminExpandableStatusIndicator(
                  key: Key('safety-child-status-${record.childId}'),
                  label: statusLabel,
                  semanticLabel: 'Status de ${record.childName}: $statusLabel',
                  backgroundColor: colors.$1,
                  foregroundColor: colors.$2,
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Text(record.institutionName, key: Key('safety-child-institution-${record.childId}')),
            Text(record.unitName, key: Key('safety-child-unit-${record.childId}')),
            const SizedBox(height: CoeloSpacing.space3),
            Row(
              children: [
                Expanded(child: Text('Autorizações\n$active')),
                Expanded(child: Text('Em análise\n${record.pendingCount}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SafetyTable extends StatelessWidget {
  const _SafetyTable({required this.records, required this.onOpen});
  final List<ChildSafetyRecord> records;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => records.isEmpty
      ? const CoeloStatePanel(
          title: 'Nenhuma criança encontrada',
          message: 'Revise a busca ou a segmentação.',
          icon: Icons.search_off_rounded,
        )
      : CoeloAdminResizableTable<ChildSafetyRecord>(
          key: const Key('safety-children-table'),
          items: records,
          rowKey: (r) => 'safety-child-row-${r.childId}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (r) => onOpen(r.childId),
          pinnedColumn: _column('child', 'Criança', (r) => r.childName, 240),
          columns: [
            _column('institution', 'Instituição', (r) => r.institutionName, 220),
            _column('unit', 'Unidade', (r) => r.unitName, 200),
            _column('authorized', 'Autorizadas', (r) => r.authorizations.length.toString(), 160),
            _column('pending', 'Em análise', (r) => r.pendingCount.toString(), 150),
          ],
        );
  CoeloAdminTableColumn<ChildSafetyRecord> _column(
    String id,
    String label,
    String Function(ChildSafetyRecord) value,
    double width,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: 140,
    maxWidth: 360,
    cellBuilder: (_, item) => Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

final class ChildSecurityPage extends StatefulWidget {
  const ChildSecurityPage({
    required this.childId,
    required this.controller,
    required this.logout,
    required this.onBack,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    super.key,
  });
  final String childId;
  final ChildSafetyController controller;
  final LogoutAction logout;
  final VoidCallback onBack;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<ChildSecurityPage> createState() => _ChildSecurityPageState();
}

final class _ChildSecurityPageState extends State<ChildSecurityPage> {
  late Future<ChildSafetyRecord?> record;
  late int dataVersion;
  @override
  void initState() {
    super.initState();
    record = widget.controller.fetchChild(widget.childId);
    dataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (!mounted || dataVersion == widget.controller.dataVersion) return;
    dataVersion = widget.controller.dataVersion;
    setState(() {
      record = widget.controller.fetchChild(widget.childId);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Segurança da criança',
    subtitle: 'Contexto privado, vigência e histórico auditável.',
    currentDestination: 'safety',
    onDestinationSelected: widget.onDestinationSelected,
    child: FutureBuilder<ChildSafetyRecord?>(
      future: record,
      builder: (context, snapshot) => LayoutBuilder(
        builder: (context, constraints) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CoeloStatePanel(
                title: 'Carregando contexto',
                message: 'Revalidando acesso.',
                loading: true,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: CoeloStatePanel(
                title: 'Contexto indisponível',
                message: 'Não foi possível abrir este registro.',
                icon: Icons.error_outline_rounded,
                actionLabel: 'Voltar',
                onAction: widget.onBack,
              ),
            );
          }
          final child = snapshot.data;
          if (child == null) {
            return Center(
              child: CoeloStatePanel(
                title: 'Registro não encontrado',
                message: 'O registro não existe ou não pertence ao seu escopo.',
                icon: Icons.search_off_rounded,
                actionLabel: 'Voltar',
                onAction: widget.onBack,
              ),
            );
          }
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final identity = Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                constraints: const BoxConstraints.tightFor(
                  width: CoeloSize.touchMin,
                  height: CoeloSize.touchMin,
                ),
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.childName, style: Theme.of(context).textTheme.headlineSmall),
                    Text('${child.institutionName} · ${child.unitName} · ${child.internalId}'),
                  ],
                ),
              ),
            ],
          );
          return ListView(
            padding: EdgeInsets.all(inset),
            children: [
              identity,
              const SizedBox(height: CoeloSpacing.space6),
              if (widget.controller.canCreate && widget.onCreate != null) ...[
                CoeloAdminCreateAction(
                  key: const Key('safety-create-authorization-banner'),
                  label: 'Criar autorização',
                  description: 'Cadastre uma pessoa autorizada para esta criança.',
                  icon: Icons.person_add_alt_1_outlined,
                  variant: CoeloAdminCreateActionVariant.banner,
                  onPressed: widget.onCreate,
                ),
                const SizedBox(height: CoeloSpacing.space4),
              ],
              if (child.pendingCount > 0) ...[
                _PendingNotice(count: child.pendingCount),
                const SizedBox(height: CoeloSpacing.space4),
              ],
              if (child.authorizations.isEmpty)
                CoeloStatePanel(
                  title: 'Nenhuma pessoa autorizada',
                  message: 'A retirada permanece bloqueada até uma autorização ser aprovada.',
                  icon: Icons.gpp_bad_outlined,
                  actionLabel: widget.controller.canCreate && widget.onCreate != null
                      ? 'Criar autorização'
                      : null,
                  onAction: widget.controller.canCreate ? widget.onCreate : null,
                )
              else if (constraints.maxWidth >= 768)
                _AuthorizedTable(
                  record: child,
                  controller: widget.controller,
                  onEdit: widget.onEdit,
                )
              else
                Column(
                  children: [
                    for (final item in child.authorizations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                        child: AuthorizedPersonCard(
                          record: child,
                          authorization: item,
                          controller: widget.controller,
                          onEdit: widget.onEdit == null ? null : () => widget.onEdit!(item.id),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}

final class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(context);
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Text(
        '$count solicitação(ões) aguardando aprovação. A retirada permanece bloqueada.',
        style: TextStyle(color: colors.onWarningContainer),
      ),
    );
  }
}

final class _AuthorizedTable extends StatelessWidget {
  const _AuthorizedTable({required this.record, required this.controller, required this.onEdit});
  final ChildSafetyRecord record;
  final ChildSafetyController controller;
  final ValueChanged<String>? onEdit;
  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<PickupAuthorization>(
    key: const Key('authorized-persons-table'),
    items: record.authorizations,
    rowKey: (a) => 'authorized-person-row-${a.id}',
    headerHeight: 56,
    rowHeight: 72,
    pinnedColumn: _column('name', 'Nome', (a) => a.name, 220),
    columns: [
      _column('relationship', 'Relação', (a) => a.relationship, 180),
      _column('validity', 'Validade', _period, 220),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Status',
        initialWidth: 150,
        minWidth: 140,
        maxWidth: 220,
        cellBuilder: (_, item) => _Status(status: item.status),
      ),
      CoeloAdminTableColumn(
        id: 'actions',
        label: 'Ações',
        initialWidth: 150,
        minWidth: 140,
        maxWidth: 220,
        cellBuilder: (context, item) => OutlinedButton(
          onPressed: () => _manage(context, record, item, controller, onEdit),
          child: const Text('Gerenciar'),
        ),
      ),
    ],
  );
  CoeloAdminTableColumn<PickupAuthorization> _column(
    String id,
    String label,
    String Function(PickupAuthorization) value,
    double width,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: 140,
    maxWidth: 360,
    cellBuilder: (_, item) => Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

final class AuthorizedPersonCard extends StatelessWidget {
  const AuthorizedPersonCard({
    required this.record,
    required this.authorization,
    required this.controller,
    this.onEdit,
    super.key,
  });
  final ChildSafetyRecord record;
  final PickupAuthorization authorization;
  final ChildSafetyController controller;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: '${authorization.name}, ${authorization.status.label}',
    onPressed: () => _manage(
      context,
      record,
      authorization,
      controller,
      onEdit == null ? null : (_) => onEdit!(),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CoeloAvatar(
                initials: _initials(authorization.name),
                semanticLabel: 'Avatar de ${authorization.name}',
                size: CoeloAvatarSize.medium,
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorization.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(authorization.relationship),
                  ],
                ),
              ),
              _Status(status: authorization.status),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          AuthorizationValiditySummary(authorization: authorization),
        ],
      ),
    ),
  );
}

final class AuthorizationValiditySummary extends StatelessWidget {
  const AuthorizationValiditySummary({required this.authorization, super.key});
  final PickupAuthorization authorization;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Validade da autorização: ${_period(authorization)}',
    child: Row(
      children: [
        const Icon(Icons.event_available_outlined, size: CoeloSize.iconSm),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(_period(authorization))),
      ],
    ),
  );
}

final class ChildSafetyWizardPage extends StatefulWidget {
  const ChildSafetyWizardPage({
    required this.controller,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.childId,
    this.authorizationId,
    this.onDestinationSelected,
    super.key,
  });
  final ChildSafetyController controller;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  final String? childId;
  final String? authorizationId;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<ChildSafetyWizardPage> createState() => _ChildSafetyWizardPageState();
}

final class _ChildSafetyWizardPageState extends State<ChildSafetyWizardPage> {
  final childSearch = TextEditingController(),
      personId = TextEditingController(),
      relationshipDetail = TextEditingController(),
      requestReason = TextEditingController();
  var step = 0,
      searching = false,
      relationship = 'mother',
      pickup = true,
      emergency = false,
      transport = false;
  var options = const <ChildSafetyChildOption>[];
  ChildSafetyChildOption? child;
  DateTimeRange? validity;
  var validityOpenEnded = false;
  String? error;
  int expectedVersion = 1;
  static const labels = ['Criança', 'Pessoa autorizada', 'Validade e capacidades', 'Revisão'];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    if (widget.childId != null) _loadInitialContext();
  }

  void _controllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialContext() async {
    try {
      final record = await widget.controller.fetchChild(widget.childId!);
      if (!mounted || record == null) return;
      var option = ChildSafetyChildOption(
        id: record.childId,
        name: record.childName,
        internalId: record.internalId,
        childContextId: record.childContextId,
        institutionId: record.institutionId,
        institutionName: record.institutionName,
        unitId: record.unitId,
        unitName: record.unitName,
      );
      PickupAuthorization? authorization;
      if (widget.authorizationId != null) {
        for (final value in record.authorizations) {
          if (value.id == widget.authorizationId) authorization = value;
        }
        if (authorization == null) throw const ChildSafetyNotFoundException();
        option = ChildSafetyChildOption(
          id: record.childId,
          name: record.childName,
          internalId: record.internalId,
          childContextId: authorization.childContextId,
          institutionName: authorization.institutionName,
          unitId: authorization.unitId,
          unitName: authorization.unitName,
        );
      }
      setState(() {
        child = option;
        options = [option];
        childSearch.text = record.childName;
        if (authorization != null) {
          personId.text = authorization.personId ?? '';
          relationship = _relationshipCode(authorization.relationship);
          relationshipDetail.text = relationship == 'other' ? authorization.relationship : '';
          requestReason.text = authorization.requestReason ?? '';
          validity = authorization.startsAt == null
              ? null
              : DateTimeRange(
                  start: authorization.startsAt!,
                  end: authorization.endsAt ?? authorization.startsAt!,
                );
          validityOpenEnded = authorization.startsAt != null && authorization.endsAt == null;
          pickup = authorization.capabilityCodes.contains('pickup');
          emergency = authorization.capabilityCodes.contains('emergency_contact');
          transport = authorization.capabilityCodes.contains('transport');
          expectedVersion = authorization.version;
        }
      });
    } on Exception {
      if (mounted) setState(() => error = 'Não foi possível carregar o contexto solicitado.');
    }
  }

  @override
  void dispose() {
    childSearch.dispose();
    personId.dispose();
    relationshipDetail.dispose();
    requestReason.dispose();
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: widget.authorizationId == null ? 'Criar segurança' : 'Editar segurança',
    subtitle: 'A autorização individual nunca é herdada e depende de revisão da unidade.',
    currentDestination: 'safety',
    onDestinationSelected: widget.onDestinationSelected,
    child: LayoutBuilder(
      builder: (context, constraints) => SuperadminFormFrame(
        viewportWidth: constraints.maxWidth,
        navigation: SuperadminFormStepNavigation(
          currentIndex: step,
          steps: [
            for (var index = 0; index < labels.length; index++)
              SuperadminFormStep(
                label: labels[index],
                enabled: index <= step,
                status: index == step
                    ? SuperadminFormStepStatus.current
                    : index < step
                    ? SuperadminFormStepStatus.complete
                    : SuperadminFormStepStatus.incomplete,
              ),
          ],
          onStepSelected: (value) => setState(() => step = value),
        ),
        body: _section(),
        footer: SuperadminFormActionFooter(
          tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
          continuationActions: [
            if (step > 0)
              OutlinedButton(
                onPressed: () => setState(() => step--),
                child: const Text('Anterior'),
              ),
            FilledButton(
              key: const Key('safety-wizard-primary'),
              onPressed: widget.controller.isSaving ? null : _continue,
              child: Text(step == 3 ? 'Enviar para aprovação' : 'Continuar'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _section() => _panel(labels[step], switch (step) {
    0 => [
      CoeloFormTextField(
        controller: childSearch,
        labelText: 'Buscar criança',
        hintText: 'Nome ou identificação interna',
        prefixIcon: Icons.search_rounded,
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          constraints: const BoxConstraints.tightFor(
            width: CoeloSize.touchMin,
            height: CoeloSize.touchMin,
          ),
          onPressed: searching ? null : _search,
          icon: searching
              ? const SizedBox.square(
                  dimension: CoeloSize.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (final option in options) ...[
        CoeloAdminInteractiveCard(
          semanticLabel: 'Selecionar ${option.name}',
          onPressed: () => setState(() => child = option),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                Icon(
                  child == option ? Icons.check_circle_rounded : Icons.child_care_outlined,
                  color: child == option
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${option.institutionName} · ${option.unitName}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
      ],
    ],
    1 => [
      CoeloFormTextField(
        controller: personId,
        labelText: 'Identificador da pessoa global',
        hintText: 'UUID da pessoa selecionada',
        prefixIcon: Icons.person_search_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: requestReason,
        labelText: 'Motivo da solicitação',
        hintText: 'Informe o motivo auditável',
        prefixIcon: Icons.notes_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<String>(
        label: 'Relação',
        value: relationship,
        options: const ['mother', 'father', 'grandparent', 'other'],
        optionLabel: (value) => switch (value) {
          'mother' => 'Mãe',
          'father' => 'Pai',
          'grandparent' => 'Avó/Avô',
          _ => 'Outros',
        },
        onChanged: (value) => setState(() => relationship = value),
        prefixIcon: Icons.family_restroom_outlined,
      ),
      if (relationship == 'other') ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: relationshipDetail,
          labelText: 'Detalhe da relação',
          prefixIcon: Icons.account_tree_outlined,
        ),
      ],
    ],
    2 => [
      CoeloDateRangeField(
        value: validity,
        onChanged: (value) => setState(() {
          validity = value;
          if (value == null) validityOpenEnded = false;
        }),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        showQuickRanges: false,
        labelText: 'Período de validade (opcional)',
      ),
      if (validity != null) ...[
        const SizedBox(height: CoeloSpacing.space2),
        CoeloAdminToggleField(
          label: 'Sem data final',
          description: 'A validade começa na data escolhida e permanece sem término definido.',
          value: validityOpenEnded,
          onChanged: (value) => setState(() => validityOpenEnded = value),
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminToggleField(
        label: 'Retirada',
        description: 'Pode retirar após aprovação.',
        value: pickup,
        onChanged: (v) => setState(() => pickup = v),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      CoeloAdminToggleField(
        label: 'Contato de emergência',
        description: 'Pode ser acionada em emergência.',
        value: emergency,
        onChanged: (v) => setState(() => emergency = v),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      CoeloAdminToggleField(
        label: 'Transporte',
        description: 'Pode realizar transporte autorizado.',
        value: transport,
        onChanged: (v) => setState(() => transport = v),
      ),
    ],
    _ => [
      _Review(label: 'Criança', value: child?.name ?? 'Não selecionada'),
      _Review(
        label: 'Contexto',
        value: '${child?.institutionName ?? '—'} · ${child?.unitName ?? '—'}',
      ),
      _Review(label: 'Pessoa global', value: personId.text.trim()),
      _Review(label: 'Capacidades', value: _capabilities().join(', ')),
      const SizedBox(height: CoeloSpacing.space4),
      Text(
        'Solicitação individual: não herda política e não autoriza retirada antes da aprovação.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  });
  Widget _panel(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          step == 0
              ? 'A busca é server-side e restrita ao escopo autorizado.'
              : step == 3
              ? 'A unidade decidirá; até lá a retirada permanece bloqueada.'
              : 'Preencha apenas os dados necessários.',
        ),
        const SizedBox(height: CoeloSpacing.space6),
        ...children,
        if (error != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    ),
  );
  Future<void> _search() async {
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final result = await widget.controller.searchChildren(childSearch.text);
      if (mounted) setState(() => options = result);
    } on Exception {
      if (mounted) setState(() => error = 'Não foi possível buscar crianças.');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _continue() async {
    setState(() => error = null);
    if (step == 0 && child == null) {
      setState(() => error = 'Busque e selecione uma criança.');
      return;
    }
    if (step == 1 &&
        (personId.text.trim().isEmpty ||
            requestReason.text.trim().length < 3 ||
            (relationship == 'other' && relationshipDetail.text.trim().isEmpty))) {
      setState(() => error = 'Selecione a pessoa global e informe relação e motivo.');
      return;
    }
    if (step == 2 && _capabilities().isEmpty) {
      setState(() => error = 'Selecione ao menos uma capacidade.');
      return;
    }
    if (step < 3) {
      setState(() => step++);
      return;
    }
    final selected = child!;
    if (selected.childContextId == null || selected.unitId == null) {
      setState(() => error = 'O contexto autorizado da criança está incompleto.');
      return;
    }
    final saved = await widget.controller.saveAuthorization(
      SavePickupAuthorizationCommand(
        requestId: _uuid(),
        childId: selected.id,
        childContextId: selected.childContextId!,
        unitId: selected.unitId!,
        personId: personId.text.trim(),
        authorizationId: widget.authorizationId,
        expectedVersion: expectedVersion,
        relationshipCode: relationship,
        relationshipDetail: relationship == 'other' ? relationshipDetail.text.trim() : null,
        capabilityCodes: _capabilities(),
        requestReason: requestReason.text.trim(),
        validFrom: validity?.start,
        validUntil: validityOpenEnded ? null : validity?.end,
      ),
    );
    if (!mounted) return;
    if (saved) {
      widget.onSaved();
    } else {
      setState(() => error = widget.controller.errorMessage);
    }
  }

  Set<String> _capabilities() => {
    if (pickup) 'pickup',
    if (emergency) 'emergency_contact',
    if (transport) 'transport',
  };
}

String _relationshipCode(String value) => switch (value.toLowerCase()) {
  'mother' || 'mãe' => 'mother',
  'father' || 'pai' => 'father',
  'grandparent' || 'avó' || 'avô' => 'grandparent',
  _ => 'other',
};

final class _Review extends StatelessWidget {
  const _Review({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
      child: constraints.maxWidth < 520
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: CoeloSpacing.space1),
                Text(value),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(label, style: Theme.of(context).textTheme.labelLarge),
                ),
                Expanded(child: Text(value)),
              ],
            ),
    ),
  );
}

final class _Status extends StatelessWidget {
  const _Status({required this.status});
  final PickupAuthorizationStatus status;
  @override
  Widget build(BuildContext context) {
    final colors = _statusPair(context, status);
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      semanticLabel: 'Status da autorização: ${status.label}',
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }
}

Future<void> _manage(
  BuildContext context,
  ChildSafetyRecord record,
  PickupAuthorization authorization,
  ChildSafetyController controller,
  ValueChanged<String>? onEdit,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => CoeloAdminDialogShell(
    title: 'Gerenciar ${authorization.name}',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Status(status: authorization.status),
        if (authorization.status == PickupAuthorizationStatus.approved) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text('Situação: ${authorization.lifecycleStatus.label}'),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        AuthorizationValiditySummary(authorization: authorization),
        if (authorization.status == PickupAuthorizationStatus.pending) ...[
          const SizedBox(height: CoeloSpacing.space4),
          FilledButton.icon(
            onPressed: () => _transition(
              dialogContext,
              controller,
              record,
              authorization,
              PickupAuthorizationStatus.approved,
              'Documento e vínculo conferidos pela unidade',
            ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aprovar'),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _transition(
              dialogContext,
              controller,
              record,
              authorization,
              PickupAuthorizationStatus.rejected,
              'Solicitação rejeitada pela unidade',
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Rejeitar'),
          ),
        ],
        if (authorization.status == PickupAuthorizationStatus.approved &&
            authorization.lifecycleStatus == PickupAuthorizationLifecycleStatus.active) ...[
          const SizedBox(height: CoeloSpacing.space4),
          OutlinedButton.icon(
            key: const Key('safety-suspend-authorization'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _confirmSuspend(dialogContext, controller, record, authorization),
            icon: const Icon(Icons.pause_circle_outline_rounded),
            label: const Text('Suspender autorização'),
          ),
        ],
      ],
    ),
    secondaryAction: onEdit == null || authorization.status != PickupAuthorizationStatus.pending
        ? null
        : OutlinedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onEdit(authorization.id);
            },
            child: const Text('Editar'),
          ),
    primaryAction: FilledButton(
      onPressed: () => Navigator.of(dialogContext).pop(),
      child: const Text('Concluir'),
    ),
  ),
);

Future<void> _confirmSuspend(
  BuildContext context,
  ChildSafetyController controller,
  ChildSafetyRecord record,
  PickupAuthorization authorization,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (confirmationContext) => CoeloAdminDialogShell(
      title: 'Suspender autorização?',
      body: Text('${authorization.name} ficará impedido(a) de retirar a criança até nova revisão.'),
      secondaryAction: OutlinedButton(
        key: const Key('safety-cancel-suspension'),
        onPressed: () => Navigator.of(confirmationContext).pop(false),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('safety-confirm-suspension'),
        onPressed: () => Navigator.of(confirmationContext).pop(true),
        child: const Text('Suspender'),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final succeeded = await controller.suspendAuthorization(
    SuspendPickupAuthorizationCommand(
      requestId: _uuid(),
      childId: record.childId,
      authorizationId: authorization.id,
      reason: 'Autorização suspensa para revisão da unidade',
      expectedVersion: authorization.version,
    ),
  );
  if (!context.mounted) return;
  if (succeeded) {
    Navigator.of(context).pop();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(controller.errorMessage ?? 'Não foi possível suspender a autorização.'),
      ),
    );
  }
}

Future<void> _transition(
  BuildContext context,
  ChildSafetyController controller,
  ChildSafetyRecord record,
  PickupAuthorization authorization,
  PickupAuthorizationStatus status,
  String reason,
) async {
  final succeeded = await controller.transitionAuthorization(
    TransitionPickupAuthorizationCommand(
      requestId: _uuid(),
      childId: record.childId,
      authorizationId: authorization.id,
      status: status,
      reason: reason,
      expectedVersion: authorization.version,
    ),
  );
  if (context.mounted && succeeded) Navigator.of(context).pop();
}

CoeloStatusColors _statusColors(BuildContext context) =>
    Theme.of(context).extension<CoeloStatusColors>() ??
    (Theme.brightnessOf(context) == Brightness.dark
        ? CoeloStatusColors.dark
        : CoeloStatusColors.light);
(Color, Color) _statusPair(BuildContext context, PickupAuthorizationStatus status) {
  final colors = _statusColors(context);
  return switch (status) {
    PickupAuthorizationStatus.pending => (colors.warningContainer, colors.onWarningContainer),
    PickupAuthorizationStatus.approved => (colors.successContainer, colors.onSuccessContainer),
    PickupAuthorizationStatus.rejected => (colors.errorContainer, colors.onErrorContainer),
  };
}

String _period(PickupAuthorization value) {
  final from = _date(value.startsAt);
  if (value.lifetime) return from.isEmpty ? 'Até revogação' : 'Desde $from · até revogação';
  return '${from.isEmpty ? 'Início não informado' : from} até '
      '${_date(value.endsAt).isEmpty ? 'data não informada' : _date(value.endsAt)}';
}

String _date(DateTime? value) => value == null
    ? ''
    : '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((value) => value.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

String _uuid() {
  final random = Random.secure(), bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
