import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/child_safety.dart';

enum _SafetyLayout { cards, table }

enum _SafetyTableView { grouped }

final class SafetyLandingPage extends StatefulWidget {
  const SafetyLandingPage({
    required this.store,
    required this.logout,
    required this.onOpenChild,
    this.onDestinationSelected,
    super.key,
  });
  final ChildSafetyStore store;
  final LogoutAction logout;
  final ValueChanged<String> onOpenChild;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<SafetyLandingPage> createState() => _SafetyLandingPageState();
}

final class _SafetyLandingPageState extends State<SafetyLandingPage> {
  final search = TextEditingController();
  var query = '';
  var statuses = <PickupAuthorizationStatus>{};
  var institutions = <String>{};
  var units = <String>{};
  var layout = _SafetyLayout.cards;
  var page = 1;
  var pageSize = 8;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ChildSafetyRecord> get visible {
    final term = query.trim().toLowerCase();
    return widget.store.records.where((record) {
      final haystack = [
        record.childName,
        record.internalId,
        record.institutionName,
        record.unitName,
      ].join(' ').toLowerCase();
      return (term.isEmpty || haystack.contains(term)) &&
          (institutions.isEmpty || institutions.contains(record.institutionName)) &&
          (units.isEmpty || units.contains(record.unitName)) &&
          (statuses.isEmpty || record.authorizations.any((item) => statuses.contains(item.status)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Segurança da criança',
    subtitle: 'Gerencie quem pode retirar cada criança e acompanhe aprovações.',
    currentDestination: 'safety',
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final statePanel = switch (widget.store.state) {
            ChildSafetyLoadState.loading => Semantics(
              label: 'Carregando segurança da criança',
              liveRegion: true,
              child: CoeloStatePanel(
                title: 'Carregando segurança da criança',
                message: 'Buscando crianças e autorizações no contexto permitido.',
                loading: true,
              ),
            ),
            ChildSafetyLoadState.error => const CoeloStatePanel(
              title: 'Não foi possível carregar',
              message: 'Tente novamente mais tarde.',
              icon: Icons.error_outline_rounded,
            ),
            ChildSafetyLoadState.unauthorized => const CoeloStatePanel(
              title: 'Sem permissão',
              message: 'O contexto atual não autoriza esta consulta.',
              icon: Icons.lock_outline_rounded,
            ),
            ChildSafetyLoadState.ready =>
              widget.store.records.isEmpty
                  ? const CoeloStatePanel(
                      title: 'Nenhuma criança cadastrada',
                      message: 'Não há crianças disponíveis no contexto atual.',
                      icon: Icons.child_care_outlined,
                    )
                  : null,
          };
          if (statePanel != null) {
            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(padding: EdgeInsets.all(padding), child: statePanel),
              ),
            );
          }
          return ColoredBox(
            key: const Key('safety-directory-surface'),
            color: Theme.of(context).colorScheme.surface,
            child: ListView(
              padding: EdgeInsets.all(padding),
              children: [
                CoeloAdminListingToolbar(
                  search: SizedBox(
                    width: constraints.maxWidth < CoeloBreakpoints.medium.minWidth
                        ? constraints.maxWidth
                        : 300,
                    height: CoeloSize.touchMin,
                    child: CoeloSearchField(
                      controller: search,
                      hintText: 'Nome, RA ou contexto',
                      semanticLabel: 'Buscar criança por nome, RA, instituição ou unidade',
                      onChanged: (value) => setState(() {
                        query = value;
                        page = 1;
                      }),
                    ),
                  ),
                  filters: [
                    SizedBox(
                      width: 180,
                      child: CoeloAdminMultiSelectFilter<String>(
                        label: 'Instituição',
                        options: widget.store.records
                            .map((item) => item.institutionName)
                            .toSet()
                            .toList(),
                        selectedValues: institutions,
                        optionLabel: (value) => value,
                        onChanged: (value) => setState(() {
                          institutions = value;
                          page = 1;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: CoeloAdminMultiSelectFilter<String>(
                        label: 'Unidade',
                        options: widget.store.records.map((item) => item.unitName).toSet().toList(),
                        selectedValues: units,
                        optionLabel: (value) => value,
                        onChanged: (value) => setState(() {
                          units = value;
                          page = 1;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: CoeloAdminMultiSelectFilter<PickupAuthorizationStatus>(
                        label: 'Status',
                        options: PickupAuthorizationStatus.values,
                        selectedValues: statuses,
                        optionLabel: (value) => value.label,
                        onChanged: (value) => setState(() {
                          statuses = value;
                          page = 1;
                        }),
                      ),
                    ),
                  ],
                  actions: [
                    SuperadminDirectoryViewToggle<_SafetyTableView>(
                      cardsSelected: layout == _SafetyLayout.cards,
                      groupedView: _SafetyTableView.grouped,
                      selectedTableView: _SafetyTableView.grouped,
                      tableViews: const [
                        SuperadminDirectoryTableViewOption(
                          value: _SafetyTableView.grouped,
                          label: 'Agrupado',
                        ),
                      ],
                      cardsKey: const Key('safety-view-cards'),
                      tableKey: const Key('safety-view-table'),
                      onCardsSelected: () => setState(() => layout = _SafetyLayout.cards),
                      onTableViewSelected: (_) => setState(() => layout = _SafetyLayout.table),
                    ),
                    FilledButton.icon(
                      onPressed: widget.store.records.isEmpty
                          ? null
                          : () => widget.onOpenChild(widget.store.records.first.childId),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Nova autorização'),
                    ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _Metrics(records: widget.store.records),
                const SizedBox(height: CoeloSpacing.space6),
                _SafetyDirectory(
                  records: visible,
                  layout: layout,
                  page: page,
                  pageSize: pageSize,
                  onOpen: widget.onOpenChild,
                  onClear: () => setState(() {
                    search.clear();
                    query = '';
                    statuses = {};
                    institutions = {};
                    units = {};
                    page = 1;
                  }),
                  onPageChanged: (value) => setState(() => page = value),
                  onPageSizeChanged: (value) => setState(() {
                    pageSize = value;
                    page = 1;
                  }),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

final class _SafetyDirectory extends StatelessWidget {
  const _SafetyDirectory({
    required this.records,
    required this.layout,
    required this.page,
    required this.pageSize,
    required this.onOpen,
    required this.onClear,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final List<ChildSafetyRecord> records;
  final _SafetyLayout layout;
  final int page;
  final int pageSize;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return CoeloStatePanel(
        title: 'Nenhuma criança encontrada',
        message: 'Revise a busca ou os filtros aplicados.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Limpar filtros',
        onAction: onClear,
      );
    }
    final totalPages = (records.length / pageSize).ceil().clamp(1, 999999);
    final safePage = page.clamp(1, totalPages);
    final items = records.skip((safePage - 1) * pageSize).take(pageSize).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (layout == _SafetyLayout.cards)
          _InstitutionGroups(records: items, onOpen: onOpen)
        else
          _SafetyChildrenTable(records: items, onOpen: onOpen),
        if (records.length > pageSize) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Center(
            child: CoeloAdminPagination(
              currentPage: safePage,
              totalPages: totalPages,
              pageSize: pageSize,
              pageSizeOptions: const [8, 20, 50, 100],
              onPageSelected: onPageChanged,
              onPageSizeChanged: onPageSizeChanged,
              onPrevious: safePage > 1 ? () => onPageChanged(safePage - 1) : null,
              onNext: safePage < totalPages ? () => onPageChanged(safePage + 1) : null,
            ),
          ),
        ],
      ],
    );
  }
}

final class _SafetyChildrenTable extends StatelessWidget {
  const _SafetyChildrenTable({required this.records, required this.onOpen});
  final List<ChildSafetyRecord> records;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<ChildSafetyRecord>(
    key: const Key('safety-children-table'),
    items: records,
    rowKey: (item) => 'safety-child-row-' + item.childId,
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: (item) => onOpen(item.childId),
    pinnedColumn: _column('child', 'Criança', (item) => item.childName, 240),
    columns: [
      _column('institution', 'Instituição', (item) => item.institutionName, 220),
      _column('unit', 'Unidade', (item) => item.unitName, 200),
      _column(
        'authorized',
        'Pessoas autorizadas',
        (item) => item.authorizations.length.toString(),
        180,
      ),
      _column(
        'validation',
        'Validação',
        (item) => item.pendingCount > 0 ? 'Há pendentes' : 'Todas ativas',
        180,
      ),
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
    minWidth: 150,
    maxWidth: 360,
    cellBuilder: (context, item) => Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

final class _Metrics extends StatelessWidget {
  const _Metrics({required this.records});
  final List<ChildSafetyRecord> records;

  @override
  Widget build(BuildContext context) {
    final pending = records.fold<int>(0, (sum, item) => sum + item.pendingCount);
    final approved = records.fold<int>(
      0,
      (sum, item) =>
          sum +
          item.authorizations
              .where((value) => value.status == PickupAuthorizationStatus.approved)
              .length,
    );
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      children: [
        _Metric('Crianças', records.length.toString(), Icons.child_care_rounded),
        _Metric('Autorizações ativas', approved.toString(), Icons.verified_user_outlined),
        _Metric('Aguardando aprovação', pending.toString(), Icons.pending_actions_outlined),
      ],
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 180),
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: _surface(context),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: CoeloSpacing.space3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    ),
  );
}

final class _InstitutionGroups extends StatelessWidget {
  const _InstitutionGroups({required this.records, required this.onOpen});
  final List<ChildSafetyRecord> records;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ChildSafetyRecord>>{};
    for (final record in records) {
      groups.putIfAbsent(record.institutionName + ' · ' + record.unitName, () => []).add(record);
    }
    final entries = groups.entries.toList();
    return Column(
      children: [
        for (var group = 0; group < entries.length; group++) ...[
          Container(
            padding: const EdgeInsets.all(CoeloSpacing.space6),
            decoration: _surface(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(entries[group].key, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space4),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: CoeloSpacing.space4,
                    runSpacing: CoeloSpacing.space4,
                    children: [
                      for (final record in entries[group].value)
                        SizedBox(
                          width: constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                              ? (constraints.maxWidth - CoeloSpacing.space4) / 2
                              : constraints.maxWidth,
                          child: CoeloAdminInteractiveCard(
                            semanticLabel:
                                'Abrir segurança de ${record.childName}. '
                                'Status das autorizações: ${_childAuthorizationStatus(record).label}',
                            onPressed: () => onOpen(record.childId),
                            child: Padding(
                              padding: const EdgeInsets.all(CoeloSpacing.space4),
                              child: Row(
                                children: [
                                  CoeloAvatar(
                                    initials: _initials(record.childName),
                                    semanticLabel: 'Avatar de ' + record.childName,
                                    size: CoeloAvatarSize.medium,
                                  ),
                                  const SizedBox(width: CoeloSpacing.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.childName,
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        Text(record.internalId),
                                        Text(
                                          'Instituição: ${record.institutionName}',
                                          key: Key('safety-child-institution-${record.childId}'),
                                        ),
                                        Text(
                                          'Unidade: ${record.unitName}',
                                          key: Key('safety-child-unit-${record.childId}'),
                                        ),
                                        Text(
                                          record.authorizations.length.toString() +
                                              ' pessoas cadastradas',
                                        ),
                                      ],
                                    ),
                                  ),
                                  _ChildAuthorizationStatusIndicator(record: record),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (group < entries.length - 1) const SizedBox(height: CoeloSpacing.space6),
        ],
      ],
    );
  }
}

PickupAuthorizationStatus _childAuthorizationStatus(ChildSafetyRecord record) =>
    record.pendingCount > 0
    ? PickupAuthorizationStatus.pending
    : PickupAuthorizationStatus.approved;

final class _ChildAuthorizationStatusIndicator extends StatelessWidget {
  const _ChildAuthorizationStatusIndicator({required this.record});

  final ChildSafetyRecord record;

  @override
  Widget build(BuildContext context) {
    final status = _childAuthorizationStatus(record);
    final colors = _statusPair(context, status);
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
      semanticLabel: 'Status das autorizações de ${record.childName}: ${status.label}',
      surfaceKey: Key('safety-child-status-${record.childId}'),
    );
  }
}

final class ChildSecurityPage extends StatelessWidget {
  const ChildSecurityPage({
    required this.childId,
    required this.store,
    required this.logout,
    required this.onBack,
    this.onDestinationSelected,
    super.key,
  });
  final String childId;
  final ChildSafetyStore store;
  final LogoutAction logout;
  final VoidCallback onBack;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: logout,
    title: 'Pessoas que podem retirar',
    subtitle: 'A autorização só entra em vigor após aprovação institucional.',
    currentDestination: 'safety',
    onDestinationSelected: onDestinationSelected,
    child: AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final record = store.findChild(childId);
        if (record == null) {
          return Center(
            child: CoeloStatePanel(
              title: 'Criança não encontrada',
              message: 'O vínculo pode ter sido removido ou está fora do seu escopo.',
              icon: Icons.search_off_rounded,
              actionLabel: 'Voltar para Segurança',
              onAction: onBack,
            ),
          );
        }
        return _ChildDetail(record: record, store: store, onBack: onBack);
      },
    ),
  );
}

final class _ChildDetail extends StatelessWidget {
  const _ChildDetail({required this.record, required this.store, required this.onBack});
  final ChildSafetyRecord record;
  final ChildSafetyStore store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: CoeloSpacing.space3,
              runSpacing: CoeloSpacing.space3,
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Segurança'),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(context, record, store),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Cadastrar pessoa'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Container(
              padding: const EdgeInsets.all(CoeloSpacing.space6),
              decoration: _surface(context),
              child: Wrap(
                spacing: CoeloSpacing.space4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CoeloAvatar(
                    initials: _initials(record.childName),
                    semanticLabel: 'Avatar de ' + record.childName,
                    size: CoeloAvatarSize.large,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.childName, style: Theme.of(context).textTheme.headlineSmall),
                      Text(
                        record.internalId +
                            ' · ' +
                            record.institutionName +
                            ' · ' +
                            record.unitName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (record.pendingCount > 0) ...[
              const SizedBox(height: CoeloSpacing.space4),
              _Pending(count: record.pendingCount),
            ],
            const SizedBox(height: CoeloSpacing.space6),
            Text('Pessoas cadastradas', style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'A instituição e a unidade visualizam apenas autorizações dentro da própria hierarquia.',
            ),
            const SizedBox(height: CoeloSpacing.space4),
            if (record.authorizations.isEmpty)
              CoeloStatePanel(
                title: 'Nenhuma pessoa cadastrada',
                message: 'Cadastre alguém e defina a vigência da autorização.',
                icon: Icons.person_add_alt_1_outlined,
                actionLabel: 'Cadastrar pessoa',
                onAction: () => _openForm(context, record, store),
              )
            else if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth)
              _AuthorizedPersonsTable(record: record, store: store)
            else
              for (var index = 0; index < record.authorizations.length; index++) ...[
                _AuthorizationCard(
                  record: record,
                  authorization: record.authorizations[index],
                  store: store,
                ),
                if (index < record.authorizations.length - 1)
                  const SizedBox(height: CoeloSpacing.space4),
              ],
          ],
        ),
      );
    },
  );
}

final class _Pending extends StatelessWidget {
  const _Pending({required this.count});
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
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, color: colors.onWarningContainer),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Text(
              count.toString() +
                  ' solicitação(ões) pendente(s), em revisão. A retirada permanece bloqueada até aprovação.',
              style: TextStyle(color: colors.onWarningContainer),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AuthorizedPersonsTable extends StatelessWidget {
  const _AuthorizedPersonsTable({required this.record, required this.store});
  final ChildSafetyRecord record;
  final ChildSafetyStore store;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<PickupAuthorization>(
    key: const Key('authorized-persons-table'),
    items: record.authorizations,
    rowKey: (item) => 'authorized-person-row-' + item.id,
    headerHeight: 56,
    rowHeight: 72,
    pinnedColumn: _column('name', 'Nome', (item) => item.name, 220),
    columns: [
      _column('relationship', 'Relação / hierarquia', (item) => item.relationship, 190),
      _column(
        'context',
        'Instituição / unidade',
        (item) => item.institutionName + ' · ' + item.unitName,
        260,
      ),
      _column('period', 'Período de retirada', _period, 220),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Status',
        initialWidth: 140,
        minWidth: 120,
        maxWidth: 200,
        cellBuilder: (context, item) => _Status(status: item.status),
      ),
      _column('origin', 'Origem', (item) => item.origin.label, 180),
      CoeloAdminTableColumn(
        id: 'actions',
        label: 'Ações',
        initialWidth: 160,
        minWidth: 140,
        maxWidth: 220,
        cellBuilder: (context, item) => OutlinedButton(
          onPressed: () => _openManagement(context, record, item, store),
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
    cellBuilder: (context, item) => Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

final class _AuthorizationCard extends StatelessWidget {
  const _AuthorizationCard({
    required this.record,
    required this.authorization,
    required this.store,
  });
  final ChildSafetyRecord record;
  final PickupAuthorization authorization;
  final ChildSafetyStore store;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: _surface(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CoeloAvatar(
              initials: _initials(authorization.name),
              semanticLabel: 'Avatar de ' + authorization.name,
              size: CoeloAvatarSize.medium,
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(authorization.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    authorization.relationship +
                        ' · ' +
                        authorization.institutionName +
                        ' · ' +
                        authorization.unitName,
                  ),
                ],
              ),
            ),
            _Status(status: authorization.status),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text('Período: ' + _period(authorization)),
        Text('Origem: ' + authorization.origin.label),
        if (authorization.status != PickupAuthorizationStatus.approved)
          Text(
            'Retirada bloqueada até aprovação.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            if (authorization.status == PickupAuthorizationStatus.pending)
              FilledButton.icon(
                onPressed: () => store.setStatus(
                  record.childId,
                  authorization.id,
                  PickupAuthorizationStatus.approved,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aprovar'),
              ),
            if (authorization.status == PickupAuthorizationStatus.pending)
              OutlinedButton.icon(
                style: _negative(context),
                onPressed: () => store.setStatus(
                  record.childId,
                  authorization.id,
                  PickupAuthorizationStatus.rejected,
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rejeitar'),
              ),
            OutlinedButton.icon(
              onPressed: () => _openForm(context, record, store, authorization: authorization),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            TextButton.icon(
              onPressed: () => showSuperadminNotice(
                context,
                'Convite reenviado para ' + (authorization.identifier ?? authorization.name) + '.',
                icon: Icons.mark_email_read_outlined,
              ),
              icon: const Icon(Icons.forward_to_inbox_outlined),
              label: const Text('Reenviar convite'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => _confirmRemove(context, record, authorization, store),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remover'),
            ),
          ],
        ),
      ],
    ),
  );
}

final class _Status extends StatelessWidget {
  const _Status({required this.status});
  final PickupAuthorizationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusPair(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space3,
        vertical: CoeloSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: Text(status.label, style: TextStyle(color: colors.$2)),
    );
  }
}

final class ChildSecuritySummaryCard extends StatelessWidget {
  const ChildSecuritySummaryCard({
    required this.childId,
    required this.store,
    required this.onOpen,
    super.key,
  });
  final String childId;
  final ChildSafetyStore store;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, child) {
      final record = store.findChild(childId);
      if (record == null) return const SizedBox.shrink();
      return Container(
        key: const Key('child-security-summary-card'),
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        decoration: _surface(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Text(
                    'Pessoas que podem retirar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _Status(
                  status: record.pendingCount > 0
                      ? PickupAuthorizationStatus.pending
                      : PickupAuthorizationStatus.approved,
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            for (final item in record.authorizations.take(2))
              Text(item.name + ' · ' + item.relationship + ' · ' + item.status.label),
            if (record.authorizations.isEmpty)
              const Text('Nenhuma pessoa cadastrada para retirada.'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onOpen, child: const Text('Ver completa')),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openManagement(
  BuildContext context,
  ChildSafetyRecord record,
  PickupAuthorization authorization,
  ChildSafetyStore store,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => CoeloAdminDialogShell(
    title: 'Gerenciar ' + authorization.name,
    body: _AuthorizationCard(record: record, authorization: authorization, store: store),
    primaryAction: FilledButton(
      onPressed: () => Navigator.of(dialogContext).pop(),
      child: const Text('Concluir'),
    ),
  ),
);

Future<void> _confirmRemove(
  BuildContext context,
  ChildSafetyRecord record,
  PickupAuthorization authorization,
  ChildSafetyStore store,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => CoeloAdminDialogShell(
    title: 'Remover autorização',
    body: Text(
      'A autorização de ' +
          authorization.name +
          ' será removida de ' +
          record.childName +
          '. A retirada ficará bloqueada imediatamente.',
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(dialogContext).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(dialogContext).colorScheme.error,
        foregroundColor: Theme.of(dialogContext).colorScheme.onError,
      ),
      onPressed: () {
        store.remove(record.childId, authorization.id);
        Navigator.of(dialogContext).pop();
      },
      child: const Text('Remover'),
    ),
  ),
);

Future<void> _openForm(
  BuildContext context,
  ChildSafetyRecord record,
  ChildSafetyStore store, {
  PickupAuthorization? authorization,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _AuthorizationForm(record: record, store: store, authorization: authorization),
);

final class _AuthorizationForm extends StatefulWidget {
  const _AuthorizationForm({required this.record, required this.store, this.authorization});
  final ChildSafetyRecord record;
  final ChildSafetyStore store;
  final PickupAuthorization? authorization;

  @override
  State<_AuthorizationForm> createState() => _AuthorizationFormState();
}

final class _AuthorizationFormState extends State<_AuthorizationForm> {
  late final name = TextEditingController(text: widget.authorization?.name);
  late final relationship = TextEditingController(text: widget.authorization?.relationship);
  late final identifier = TextEditingController(text: widget.authorization?.identifier);
  late final starts = TextEditingController(text: _date(widget.authorization?.startsAt));
  late final ends = TextEditingController(text: _date(widget.authorization?.endsAt));
  late bool hasAccount = widget.authorization?.hasAppAccount ?? true;
  late bool lifetime = widget.authorization?.lifetime ?? true;
  late PickupAuthorizationOrigin origin =
      widget.authorization?.origin ?? PickupAuthorizationOrigin.institution;
  String? feedback;
  String? error;

  @override
  void dispose() {
    name.dispose();
    relationship.dispose();
    identifier.dispose();
    starts.dispose();
    ends.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: widget.authorization == null ? 'Cadastrar autorização' : 'Editar autorização',
    maxWidth: 680,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toggle(
          'É alguém com conta no app?',
          'Busque por @, celular, e-mail ou CPF para convidar.',
          hasAccount,
          (value) => setState(() => hasAccount = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: identifier,
          labelText: hasAccount ? 'Buscar usuário existente' : 'Canal para convite',
          hintText: '@, celular, e-mail ou CPF',
          prefixIcon: Icons.alternate_email_rounded,
          suffixIcon: IconButton(
            tooltip: 'Buscar',
            onPressed: () => setState(() {
              feedback = identifier.text.trim().isEmpty
                  ? 'Informe um identificador.'
                  : 'Conta verificada ou convite preparado para o canal informado.';
            }),
            icon: const Icon(Icons.search_rounded),
          ),
        ),
        if (feedback != null)
          Text(feedback!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: name,
          labelText: 'Nome',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: relationship,
          labelText: 'Relação / hierarquia',
          hintText: 'Ex.: avó, tio, motorista',
          prefixIcon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<PickupAuthorizationOrigin>(
          label: 'Origem do cadastro',
          value: origin,
          options: PickupAuthorizationOrigin.values,
          optionLabel: (value) => value.label,
          onChanged: (value) => setState(() => origin = value),
          prefixIcon: Icons.how_to_reg_outlined,
        ),
        if (origin == PickupAuthorizationOrigin.guardian)
          Padding(
            padding: const EdgeInsets.only(top: CoeloSpacing.space3),
            child: Text(
              'Cadastro do responsável: ficará Pendente até aprovação institucional.',
              style: TextStyle(color: _statusColors(context).onWarningContainer),
            ),
          ),
        const SizedBox(height: CoeloSpacing.space4),
        _toggle(
          'Vitalício / até o responsável retirar',
          'Permanece válido até revogação explícita.',
          lifetime,
          (value) => setState(() => lifetime = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: starts,
          labelText: 'De',
          hintText: 'DD/MM/AAAA',
          prefixIcon: Icons.event_available_outlined,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: ends,
          labelText: 'Até',
          hintText: 'DD/MM/AAAA',
          prefixIcon: Icons.event_busy_outlined,
          enabled: !lifetime,
        ),
        if (error != null)
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(onPressed: _save, child: const Text('Salvar autorização')),
  );

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> changed) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(subtitle),
          ],
        ),
      ),
      Switch(value: value, onChanged: changed),
    ],
  );

  void _save() {
    if (name.text.trim().isEmpty || relationship.text.trim().isEmpty) {
      setState(() => error = 'Informe nome e relação / hierarquia.');
      return;
    }
    final end = lifetime ? null : _parseDate(ends.text);
    if (!lifetime && end == null) {
      setState(() => error = 'Informe a data final ou marque como vitalícia.');
      return;
    }
    final previous = widget.authorization;
    widget.store.save(
      widget.record.childId,
      PickupAuthorization(
        id: previous?.id ?? 'authorization-' + DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        relationship: relationship.text.trim(),
        institutionName: widget.record.institutionName,
        unitName: widget.record.unitName,
        status: origin == PickupAuthorizationOrigin.guardian
            ? PickupAuthorizationStatus.pending
            : previous?.status ?? PickupAuthorizationStatus.approved,
        origin: origin,
        identifier: identifier.text.trim().isEmpty ? null : identifier.text.trim(),
        startsAt: _parseDate(starts.text),
        endsAt: end,
        lifetime: lifetime,
        hasAppAccount: hasAccount,
      ),
    );
    Navigator.of(context).pop();
  }
}

BoxDecoration _surface(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(CoeloRadius.lg),
  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
);

ButtonStyle _negative(BuildContext context) => OutlinedButton.styleFrom(
  foregroundColor: Theme.of(context).colorScheme.error,
  side: BorderSide(color: Theme.of(context).colorScheme.error),
);

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

String _period(PickupAuthorization item) {
  final from = _date(item.startsAt);
  if (item.lifetime) return from.isEmpty ? 'Vitalício' : 'Desde ' + from + ' · Vitalício';
  return from + ' até ' + _date(item.endsAt);
}

String _date(DateTime? value) => value == null
    ? ''
    : value.day.toString().padLeft(2, '0') +
          '/' +
          value.month.toString().padLeft(2, '0') +
          '/' +
          value.year.toString();

DateTime? _parseDate(String value) {
  final parts = value.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]), month = int.tryParse(parts[1]), year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  final result = DateTime(year, month, day);
  return result.day == day && result.month == month && result.year == year ? result : null;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\\s+')).where((item) => item.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}
