import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_care.dart';
import 'health_care_controller.dart';

enum _MedicationTableView { grouped }

enum _MedicationDirectoryDisplay { cards, table }

final class HealthMedicationPlanListItem {
  const HealthMedicationPlanListItem({
    required this.child,
    required this.medication,
    required this.doseCount,
  });

  final HealthCareChild child;
  final HealthMedication medication;
  final int doseCount;
  HealthMedicationVersion get version => medication.currentVersion;
  String get id => medication.id;
}

final class HealthMedicationPlanDirectoryPage extends StatefulWidget {
  const HealthMedicationPlanDirectoryPage({
    required this.controller,
    required this.logout,
    this.onCreate,
    this.onPlanSelected,
    super.key,
  });

  final HealthCareController controller;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onPlanSelected;

  @override
  State<HealthMedicationPlanDirectoryPage> createState() =>
      _HealthMedicationPlanDirectoryPageState();
}

final class _HealthMedicationPlanDirectoryPageState
    extends State<HealthMedicationPlanDirectoryPage> {
  final _search = TextEditingController();
  var _display = _MedicationDirectoryDisplay.cards;
  var _loading = true;
  var _items = <HealthMedicationPlanListItem>[];
  var _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final children = await Future.wait(
      [
        'child-demo-a',
        'child-demo-b',
      ].map((id) => widget.controller.repository.findChild(id, actor: widget.controller.actor)),
    );
    if (!mounted) return;
    setState(() {
      _items = [
        for (final child in children.whereType<HealthCareChild>())
          for (final medication in child.medications)
            HealthMedicationPlanListItem(
              child: child,
              medication: medication,
              doseCount: child.doses
                  .where((dose) => dose.medicationVersionId == medication.currentVersion.id)
                  .length,
            ),
      ];
      _loading = false;
    });
  }

  List<HealthMedicationPlanListItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items
        .where(
          (item) =>
              item.child.displayName.toLowerCase().contains(query) ||
              item.version.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'health-medication-plans',
    title: 'Planos de medica\u00e7\u00e3o',
    subtitle: 'Vig\u00eancia, hor\u00e1rios, respons\u00e1veis e registros de doses.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return ListView(
          key: const Key('health-medication-plans-directory-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            _toolbar(),
            const SizedBox(height: CoeloSpacing.space4),
            if (_loading)
              const CoeloStatePanel(
                title: 'Carregando',
                message: 'Buscando planos locais.',
                loading: true,
              )
            else if (_visibleItems.isEmpty)
              const CoeloStatePanel(
                title: 'Nenhum plano',
                message: 'Revise a busca ou crie um plano de medica\u00e7\u00e3o.',
              )
            else
              LayoutBuilder(
                builder: (context, contentConstraints) =>
                    _display == _MedicationDirectoryDisplay.cards
                    ? _cards(contentConstraints)
                    : _table(),
              ),
          ],
        );
      },
    ),
  );

  Widget _toolbar() => CoeloAdminListingToolbar(
    search: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: CoeloSpacing.space24 * 3),
      child: CoeloSearchField(
        controller: _search,
        semanticLabel: 'Buscar planos de medica\u00e7\u00e3o',
        hintText: 'Buscar crian\u00e7a ou medicamento',
        onChanged: (value) => setState(() => _query = value),
      ),
    ),
    filters: const [],
    actions: [
      SuperadminDirectoryViewToggle<_MedicationTableView>(
        cardsSelected: _display == _MedicationDirectoryDisplay.cards,
        groupedView: _MedicationTableView.grouped,
        selectedTableView: _MedicationTableView.grouped,
        tableViews: const [
          SuperadminDirectoryTableViewOption(
            value: _MedicationTableView.grouped,
            label: 'Agrupado',
          ),
        ],
        cardsKey: const Key('health-medication-plans-view-cards'),
        tableKey: const Key('health-medication-plans-view-table'),
        onCardsSelected: () => setState(() => _display = _MedicationDirectoryDisplay.cards),
        onTableViewSelected: (_) => setState(() => _display = _MedicationDirectoryDisplay.table),
      ),
    ],
  );

  Widget _cards(BoxConstraints constraints) {
    const minimumCardWidth = 340.0;
    final columns = math.max(1, (constraints.maxWidth / minimumCardWidth).floor());
    final width = (constraints.maxWidth - CoeloSpacing.space6 * (columns - 1)) / columns;
    return Wrap(
      spacing: CoeloSpacing.space6,
      runSpacing: CoeloSpacing.space6,
      children: [
        SizedBox(
          width: width,
          height: 240,
          child: CoeloAdminCreateAction(
            label: 'Criar plano de medica\u00e7\u00e3o',
            onPressed: widget.onCreate,
          ),
        ),
        for (final item in _visibleItems)
          SizedBox(
            width: width,
            child: _MedicationPlanCard(
              item: item,
              onPressed: () => widget.onPlanSelected?.call(item.id),
            ),
          ),
      ],
    );
  }

  Widget _table() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminCreateAction(
        label: 'Criar plano de medica\u00e7\u00e3o',
        description: 'Cadastre vig\u00eancia, hor\u00e1rios e respons\u00e1veis.',
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: widget.onCreate,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminResizableTable<HealthMedicationPlanListItem>(
        items: _visibleItems,
        rowKey: (item) => item.id,
        pinnedColumn: CoeloAdminTableColumn(
          id: 'child',
          label: 'Crian\u00e7a',
          initialWidth: 240,
          minWidth: 180,
          maxWidth: 360,
          cellBuilder: (_, item) => Text(item.child.displayName),
        ),
        columns: [
          CoeloAdminTableColumn(
            id: 'medication',
            label: 'Medicamento',
            initialWidth: 220,
            minWidth: 160,
            maxWidth: 340,
            cellBuilder: (_, item) => Text(item.version.name),
          ),
          CoeloAdminTableColumn(
            id: 'period',
            label: 'Vig\u00eancia',
            initialWidth: 220,
            minWidth: 180,
            maxWidth: 300,
            cellBuilder: (_, item) => Text(_periodLabel(item.version)),
          ),
          CoeloAdminTableColumn(
            id: 'times',
            label: 'Hor\u00e1rios',
            initialWidth: 180,
            minWidth: 140,
            maxWidth: 260,
            cellBuilder: (_, item) => Text(_scheduleLabel(item.version)),
          ),
          CoeloAdminTableColumn(
            id: 'context',
            label: 'Contexto responsável',
            initialWidth: 280,
            minWidth: 220,
            maxWidth: 420,
            cellBuilder: (_, item) => Text(
              _administrationContextLabel(item.version),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CoeloAdminTableColumn(
            id: 'status',
            label: 'Status',
            initialWidth: 160,
            minWidth: 120,
            maxWidth: 220,
            cellBuilder: (_, item) => Text(_reviewStatusLabel(item.version.status)),
          ),
        ],
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: (item) => widget.onPlanSelected?.call(item.id),
      ),
    ],
  );
}

final class _MedicationPlanCard extends StatelessWidget {
  const _MedicationPlanCard({required this.item, required this.onPressed});

  final HealthMedicationPlanListItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    minHeight: 240,
    onPressed: onPressed,
    semanticLabel: 'Abrir plano de ${item.version.name} para ${item.child.displayName}',
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoeloAvatar(semanticLabel: 'Avatar de ${item.child.displayName}', initials: 'CD'),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.child.displayName, style: Theme.of(context).textTheme.titleMedium),
                    Text(item.version.name),
                  ],
                ),
              ),
              _MedicationStatusIndicator(status: item.version.status),
              const SizedBox(width: CoeloSpacing.space2),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Vig\u00eancia', style: Theme.of(context).textTheme.labelLarge),
          Text(_periodLabel(item.version)),
          const SizedBox(height: CoeloSpacing.space2),
          Text('Hor\u00e1rios', style: Theme.of(context).textTheme.labelLarge),
          Text(_scheduleLabel(item.version)),
          const SizedBox(height: CoeloSpacing.space2),
          Text('Contexto responsável', style: Theme.of(context).textTheme.labelLarge),
          Text(
            _administrationContextLabel(item.version),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text('${item.doseCount} registro(s) de dose'),
        ],
      ),
    ),
  );
}

final class _MedicationStatusIndicator extends StatelessWidget {
  const _MedicationStatusIndicator({required this.status});

  final HealthMedicationReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = switch (status) {
      HealthMedicationReviewStatus.requested ||
      HealthMedicationReviewStatus.underReview => (colors.infoContainer, colors.onInfoContainer),
      HealthMedicationReviewStatus.approved ||
      HealthMedicationReviewStatus.active => (colors.successContainer, colors.onSuccessContainer),
      HealthMedicationReviewStatus.refused ||
      HealthMedicationReviewStatus.rejected => (colors.errorContainer, colors.onErrorContainer),
      HealthMedicationReviewStatus.ended || HealthMedicationReviewStatus.invalidated => (
        colors.historyContainer,
        colors.onHistoryContainer,
      ),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: _reviewStatusLabel(status),
      backgroundColor: pair.$1,
      foregroundColor: pair.$2,
    );
  }
}

String _administrationContextLabel(HealthMedicationVersion version) {
  final contexts = <String>{
    for (final schedule in version.schedules)
      schedule.atHome
          ? 'Casa'
          : _institutionLabel(schedule.institutionId ?? 'institution-not-informed'),
  };
  final responsibles = <String>{
    for (final id in version.policy?.recipientIds ?? const <String>{}) _responsibleLabel(id),
  };
  final contextLabel = contexts.isEmpty ? 'Contexto não informado' : contexts.join(', ');
  final responsibleLabel = responsibles.isEmpty
      ? 'Responsável não informado'
      : responsibles.join(', ');
  return '$contextLabel • $responsibleLabel';
}

String _institutionLabel(String value) => switch (value) {
  'institution-demo-a' => 'Instituição Demo A',
  'institution-demo-b' => 'Instituição Demo B',
  _ => value,
};

String _responsibleLabel(String value) => switch (value) {
  'professional-demo-professor' => 'Professor Demo',
  'professional-demo-nurse' => 'Enfermagem Demo',
  'coordinator-demo-a' => 'Coordenação Demo',
  _ => value,
};
String _periodLabel(HealthMedicationVersion version) =>
    '${_dateLabel(version.startsAt)} \u2014 ${_dateLabel(version.endsAt)}';

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _scheduleLabel(HealthMedicationVersion version) {
  if (version.schedules.isEmpty) return 'Sem hor\u00e1rio';
  return version.schedules
      .map(
        (schedule) =>
            '${schedule.time.hour.toString().padLeft(2, '0')}:'
            '${schedule.time.minute.toString().padLeft(2, '0')}',
      )
      .join(', ');
}

String _reviewStatusLabel(HealthMedicationReviewStatus value) => switch (value) {
  HealthMedicationReviewStatus.requested => 'Solicitado',
  HealthMedicationReviewStatus.underReview => 'Em revis\u00e3o',
  HealthMedicationReviewStatus.approved => 'Aprovado',
  HealthMedicationReviewStatus.refused => 'Recusado',
  HealthMedicationReviewStatus.active => 'Ativo',
  HealthMedicationReviewStatus.ended => 'Encerrado',
  HealthMedicationReviewStatus.rejected => 'Rejeitado',
  HealthMedicationReviewStatus.invalidated => 'Invalidado',
};
