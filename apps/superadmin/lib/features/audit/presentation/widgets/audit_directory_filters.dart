import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/audit.dart';
import '../audit_controller.dart';

final class AuditDirectoryFilters extends StatelessWidget {
  const AuditDirectoryFilters({
    required this.controller,
    required this.searchController,
    required this.clock,
    super.key,
  });

  final AuditDirectoryController controller;
  final TextEditingController searchController;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
      final columns = !largeText && constraints.maxWidth >= 720 ? 3 : 1;
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
      final query = controller.query;
      return Wrap(
        key: const Key('audit-filter-controls'),
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        children: [
          SizedBox(
            width: width,
            height: CoeloSize.touchMin,
            child: CoeloSearchField(
              key: const Key('audit-search'),
              controller: searchController,
              hintText: 'Buscar na auditoria',
              semanticLabel: 'Buscar na auditoria',
              onChanged: controller.updateSearch,
            ),
          ),
          SizedBox(
            key: const Key('audit-outcome-filter'),
            width: width,
            child: CoeloAdminMultiSelectFilter<AuditOutcome>(
              label: 'Todos os resultados',
              options: AuditOutcome.values,
              selectedValues: query.outcomes,
              optionLabel: _outcomeLabel,
              onChanged: (values) =>
                  controller.updateFilters(_copy(controller.query, outcomes: values)),
            ),
          ),
          SizedBox(
            key: const Key('audit-period-filter'),
            width: width,
            child: CoeloAdminSingleSelectField<_AuditPeriod>(
              label: 'Período',
              value: _selectedPeriod(query),
              options: _AuditPeriod.values,
              optionLabel: _periodLabel,
              searchable: false,
              onChanged: (value) =>
                  controller.updateFilters(_copy(controller.query, period: value, now: clock())),
            ),
          ),
        ],
      );
    },
  );
}

AuditQuery _copy(
  AuditQuery query, {
  Set<AuditOutcome>? outcomes,
  _AuditPeriod? period,
  DateTime? now,
}) => AuditQuery(
  search: query.search,
  actorIds: query.actorIds,
  contextKinds: query.contextKinds,
  actionCodes: query.actionCodes,
  resourceTypes: query.resourceTypes,
  outcomes: outcomes ?? query.outcomes,
  origins: query.origins,
  institutionId: query.institutionId,
  from: period == null
      ? query.from
      : period == _AuditPeriod.all
      ? null
      : _periodStart(period, now!),
  to: period == null
      ? query.to
      : period == _AuditPeriod.all
      ? null
      : now,
  pageSize: query.pageSize,
);

String _outcomeLabel(AuditOutcome value) => switch (value) {
  AuditOutcome.success => 'Sucesso',
  AuditOutcome.failure => 'Falha',
  AuditOutcome.denied => 'Negado',
};

enum _AuditPeriod { all, today, sevenDays, thirtyDays }

_AuditPeriod _selectedPeriod(AuditQuery query) {
  final from = query.from;
  final to = query.to;
  if (from == null || to == null) return _AuditPeriod.all;
  final days = to.difference(from).inDays;
  return days <= 1
      ? _AuditPeriod.today
      : days <= 7
      ? _AuditPeriod.sevenDays
      : _AuditPeriod.thirtyDays;
}

DateTime _periodStart(_AuditPeriod period, DateTime now) {
  return switch (period) {
    _AuditPeriod.all => now,
    _AuditPeriod.today => DateTime(now.year, now.month, now.day),
    _AuditPeriod.sevenDays => now.subtract(const Duration(days: 7)),
    _AuditPeriod.thirtyDays => now.subtract(const Duration(days: 30)),
  };
}

String _periodLabel(_AuditPeriod period) => switch (period) {
  _AuditPeriod.all => 'Todo o período',
  _AuditPeriod.today => 'Hoje',
  _AuditPeriod.sevenDays => 'Últimos 7 dias',
  _AuditPeriod.thirtyDays => 'Últimos 30 dias',
};
