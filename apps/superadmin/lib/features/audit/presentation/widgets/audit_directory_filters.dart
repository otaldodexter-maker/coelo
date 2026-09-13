import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/audit.dart';
import '../audit_controller.dart';

/// Filtros de domínio da Auditoria. Não têm largura própria: o composto de
/// diretório aplica a largura padrão dos filtros (160 px, metade no compacto).
final class AuditOutcomeFilter extends StatelessWidget {
  const AuditOutcomeFilter({required this.controller, super.key});

  final AuditDirectoryController controller;

  @override
  Widget build(BuildContext context) => CoeloAdminMultiSelectFilter<AuditOutcome>(
    label: 'Resultados',
    options: AuditOutcome.values,
    selectedValues: controller.query.outcomes,
    optionLabel: _outcomeLabel,
    onChanged: (values) => controller.updateFilters(_copy(controller.query, outcomes: values)),
  );
}

final class AuditPeriodFilter extends StatelessWidget {
  const AuditPeriodFilter({required this.controller, required this.clock, super.key});

  final AuditDirectoryController controller;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) => CoeloAdminSingleSelectField<_AuditPeriod>(
    isFilter: true,
    unselectedValue: _AuditPeriod.all,
    label: 'Período',
    value: _selectedPeriod(controller.query),
    options: _AuditPeriod.values,
    optionLabel: _periodLabel,
    searchable: false,
    onChanged: (value) =>
        controller.updateFilters(_copy(controller.query, period: value, now: clock())),
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
  // Rótulos curtos: o filtro tem 160 px na toolbar do composto.
  _AuditPeriod.all => 'Todos',
  _AuditPeriod.today => 'Hoje',
  _AuditPeriod.sevenDays => '7 dias',
  _AuditPeriod.thirtyDays => '30 dias',
};
