import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_read_detail.dart';

/// Read-only internal projection. The legacy editor has a different contract.
class ActivityReadDetailPage extends StatefulWidget {
  const ActivityReadDetailPage({
    required this.activityId,
    required this.repository,
    required this.logout,
    required this.onBack,
    required this.sessionAvailable,
    required this.canRead,
    required this.contextRevision,
    this.onEdit,
    this.onAssessmentSettings,
    this.onUnitAssessmentSettings,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.reservationBuilder,
    super.key,
  });
  final String activityId;
  final ActivityReadDetailRepository repository;
  final LogoutAction logout;
  final VoidCallback onBack;
  final bool sessionAvailable;
  final bool canRead;
  final int contextRevision;
  final ValueChanged<ActivityReadDetail>? onEdit;
  final ValueChanged<ActivityReadDetail>? onAssessmentSettings;
  final void Function(ActivityReadDetail, String unitId)? onUnitAssessmentSettings;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final Widget Function(BuildContext, ActivityReadDetail)? reservationBuilder;
  @override
  State<ActivityReadDetailPage> createState() => _ActivityReadDetailPageState();
}

class _ActivityReadDetailPageState extends State<ActivityReadDetailPage> {
  ActivityReadDetail? _detail;
  String _state = 'loading';
  int _generation = 0;
  bool get _allowed =>
      widget.sessionAvailable && widget.canRead && isActivityReadDetailId(widget.activityId);
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ActivityReadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId ||
        !identical(oldWidget.repository, widget.repository) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.canRead != widget.canRead ||
        oldWidget.contextRevision != widget.contextRevision) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _detail = null;
      _state = _allowed ? 'loading' : 'denied';
    });
    if (!_allowed) return;
    try {
      final detail = await widget.repository.fetchById(widget.activityId);
      if (!mounted || generation != _generation || !_allowed) return;
      if (detail.id != widget.activityId.toLowerCase()) {
        throw const FormatException('Wrong activity');
      }
      setState(() {
        _detail = detail;
        _state = 'ready';
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _detail = null;
        _state =
            error is ActivityReadDetailException &&
                error.failure != ActivityReadDetailFailure.unavailable
            ? 'denied'
            : 'unavailable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final generation = _generation;
    void navigate(ValueChanged<ActivityReadDetail>? action) {
      if (!mounted ||
          generation != _generation ||
          !_allowed ||
          detail == null ||
          _detail != detail) {
        return;
      }
      action?.call(detail);
    }

    return SuperadminShell(
      title: 'Visualizar atividade',
      subtitle: 'Consulte os dados e vínculos desta atividade.',
      currentDestination: 'activities',
      logout: widget.logout,
      showChatLauncher: false,
      onDestinationSelected: widget.onDestinationSelected,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space4
              : CoeloSpacing.space6;
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: const Key('activity-read-scroll'),
                      children: [
                        if (detail != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                key: const Key('activity-read-reload'),
                                onPressed: _state == 'loading' || !_allowed
                                    ? null
                                    : () => unawaited(_load()),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Recarregar'),
                              ),
                            ),
                          ),
                          _section(
                            context,
                            'Identidade',
                            _fields(context, {
                              'Nome': detail.name,
                              'Categoria': detail.taxonomyName ?? 'Não informada',
                              'Status': _status(detail.status),
                              'Descrição': detail.description ?? 'Não informada',
                              'Criação': _date(context, detail.createdAt),
                              'Atualização': _date(context, detail.updatedAt),
                            }),
                          ),
                          _section(
                            context,
                            'Vínculos da atividade',
                            _fields(context, {
                              'Unidades': '${detail.counts.units}',
                              'Turmas': '${detail.counts.groups}',
                              'Participantes': '${detail.counts.participants}',
                              'Instrutores': '${detail.counts.instructors}',
                              'Administradores da atividade': '${detail.counts.activityAdmins}',
                            }),
                          ),
                          _section(
                            context,
                            'Unidades vinculadas',
                            detail.units.isEmpty
                                ? const Text('Nenhuma unidade vinculada.')
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final unit in detail.units)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: CoeloSpacing.space3,
                                          ),
                                          child: Text('${unit.name} · Vínculo ativo'),
                                        ),
                                    ],
                                  ),
                          ),
                          _section(
                            context,
                            'Turmas vinculadas',
                            detail.groups.isEmpty
                                ? const Text('Nenhuma turma vinculada.')
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final group in detail.groups)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: CoeloSpacing.space3,
                                          ),
                                          child: _fields(context, {
                                            'Turma': group.name,
                                            'Unidade': detail.units
                                                .firstWhere((unit) => unit.unitId == group.unitId)
                                                .name,
                                            'Participação': group.participationMode == 'all'
                                                ? 'Todos'
                                                : 'Selecionados',
                                            'Status do vínculo': 'Ativo',
                                          }),
                                        ),
                                    ],
                                  ),
                          ),
                          if (widget.onAssessmentSettings != null)
                            _section(
                              context,
                              'Avalia\u00e7\u00f5es',
                              Wrap(
                                spacing: CoeloSpacing.space3,
                                runSpacing: CoeloSpacing.space3,
                                children: [
                                  OutlinedButton(
                                    key: const Key('activity-read-assessment'),
                                    onPressed: () => navigate(widget.onAssessmentSettings),
                                    child: const Text('Configuração avaliativa'),
                                  ),
                                  if (widget.onUnitAssessmentSettings != null)
                                    for (final unit in detail.units)
                                      OutlinedButton(
                                        key: Key('activity-read-assessment-${unit.unitId}'),
                                        onPressed: () => navigate((current) {
                                          widget.onUnitAssessmentSettings!(current, unit.unitId);
                                        }),
                                        child: Text('Avaliação · ${unit.name}'),
                                      ),
                                ],
                              ),
                            ),
                          if (widget.reservationBuilder != null)
                            widget.reservationBuilder!(context, detail),
                        ] else
                          CoeloStatePanel(
                            key: Key('activity-read-$_state'),
                            loading: _state == 'loading',
                            title: _state == 'loading'
                                ? 'Carregando atividade'
                                : _state == 'denied'
                                ? 'Acesso não autorizado'
                                : 'Não foi possível carregar a atividade',
                            message: _state == 'loading'
                                ? 'Aguarde a consulta dos dados.'
                                : _state == 'denied'
                                ? 'Você não tem acesso a este registro.'
                                : 'Tente recarregar os dados.',
                          ),
                        const SizedBox(height: CoeloSpacing.space4),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  SuperadminFormActionFooter(
                    tertiaryAction: TextButton(
                      key: const Key('activity-read-back'),
                      onPressed: widget.onBack,
                      child: const Text('Voltar'),
                    ),
                    continuationActions: [
                      if (detail == null)
                        OutlinedButton.icon(
                          key: const Key('activity-read-reload'),
                          onPressed: _state == 'loading' || !_allowed
                              ? null
                              : () => unawaited(_load()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Recarregar'),
                        ),
                      if (detail != null)
                        Tooltip(
                          message: widget.onEdit == null
                              ? 'A edi\u00e7\u00e3o desta atividade est\u00e1 indispon\u00edvel no momento.'
                              : 'Editar atividade',
                          child: FilledButton(
                            key: const Key('activity-read-edit'),
                            onPressed: widget.onEdit == null ? null : () => navigate(widget.onEdit),
                            child: const Text('Editar atividade'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _section(BuildContext context, String title, Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: CoeloSpacing.space5),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    ),
  ),
);
Widget _fields(BuildContext context, Map<String, String> values) => LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 2 : 1;
    final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
    return Wrap(
      spacing: CoeloSpacing.space4,
      runSpacing: CoeloSpacing.space4,
      children: [
        for (final entry in values.entries)
          SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space1),
                SelectableText(entry.value),
              ],
            ),
          ),
      ],
    );
  },
);
String _date(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final formatter = MaterialLocalizations.of(context);
  return '${formatter.formatCompactDate(local)} ${formatter.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
}

String _status(String value) => switch (value) {
  'draft' => 'Rascunho',
  'active' => 'Ativa',
  'inactive' => 'Inativa',
  'suspended' => 'Suspensa',
  'archived' => 'Arquivada',
  _ => 'Indisponível',
};
