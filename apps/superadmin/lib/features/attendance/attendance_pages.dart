import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/shell/superadmin_shell.dart';
import '../../app/activity/superadmin_activity.dart';
import '../auth/domain/logout_action.dart';
import 'attendance.dart';

class AttendanceDashboardPage extends StatefulWidget {
  const AttendanceDashboardPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    required this.onCreate,
    required this.onOpenCall,
    this.activityController,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpenCall;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceDashboardPage> createState() => _AttendanceDashboardPageState();
}

class _AttendanceDashboardPageState extends State<AttendanceDashboardPage> {
  var _period = _AttendancePeriod.last30Days;
  String? _institutionId;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Assiduidade',
    subtitle: 'Acompanhe percentuais, pendências e o histórico de chamadas.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    actions: [
      if (widget.permissions.canManage)
        FilledButton.icon(
          key: const Key('attendance-new-call'),
          onPressed: widget.onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nova chamada'),
        ),
    ],
    child: ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final calls = widget.repository.calls
            .where((call) => _institutionId == null || call.institutionId == _institutionId)
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocalDataNotice(readOnly: !widget.permissions.canManage),
              const SizedBox(height: CoeloSpacing.space6),
              Text('Hoje', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space3),
              _TodayMetrics(repository: widget.repository),
              const SizedBox(height: CoeloSpacing.space8),
              Text('Período analítico', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space3),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                      ? 280.0
                      : constraints.maxWidth;
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: width,
                      child: CoeloAdminSingleSelectField<_AttendancePeriod>(
                        label: 'Período',
                        value: _period,
                        options: _AttendancePeriod.values,
                        optionLabel: (value) => value.label,
                        onChanged: (value) async {
                          if (value == _AttendancePeriod.custom) {
                            await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2027),
                              initialDateRange: DateTimeRange(
                                start: DateTime(2026, 7, 5),
                                end: AttendanceFixtures.today,
                              ),
                            );
                          }
                          if (mounted) setState(() => _period = value);
                        },
                        prefixIcon: Icons.date_range_outlined,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _AnalyticMetrics(metrics: widget.repository.metrics),
              const SizedBox(height: CoeloSpacing.space6),
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _institutionId = null),
                    child: const Text('Todas as instituições'),
                  ),
                  if (_institutionId != null) ...[
                    const Icon(Icons.chevron_right_rounded),
                    Text(calls.firstOrNull?.institutionName ?? 'Instituição'),
                  ],
                ],
              ),
              const SizedBox(height: CoeloSpacing.space2),
              _AttendanceCallList(
                calls: calls,
                onOpenCall: widget.onOpenCall,
                onInstitutionSelected: (id) => setState(() => _institutionId = id),
              ),
              const SizedBox(height: CoeloSpacing.space6),
              const _ExpectationLegend(),
            ],
          ),
        );
      },
    ),
  );
}

class AttendanceNewCallPage extends StatefulWidget {
  const AttendanceNewCallPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    required this.onCancel,
    required this.onCreated,
    this.activityController,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<String> onCreated;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceNewCallPage> createState() => _AttendanceNewCallPageState();
}

class _AttendanceNewCallPageState extends State<AttendanceNewCallPage> {
  var _institution = 'institution-1';
  var _unit = 'unit-1';
  var _group = 'group-sun';
  String _context = 'group';
  var _activity = 'activity-music-group-sun';

  bool get _notRequired => _context == 'activity' && _activity == 'activity-art-group-sun';

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Nova chamada',
    subtitle: 'Crie uma sessão local de presença para grupo ou atividade.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LocalDataNotice(),
              const SizedBox(height: CoeloSpacing.space5),
              CoeloAdminSingleSelectField<String>(
                label: 'Instituição',
                value: _institution,
                options: const ['institution-1', 'institution-2', 'institution-3'],
                optionLabel: _institutionLabel,
                onChanged: (value) => setState(() => _institution = value),
                prefixIcon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloAdminSingleSelectField<String>(
                label: 'Unidade',
                value: _unit,
                options: const ['unit-1', 'unit-2'],
                optionLabel: (value) => value == 'unit-1' ? 'Unidade Centro' : 'Unidade Norte',
                onChanged: (value) => setState(() => _unit = value),
                prefixIcon: Icons.apartment_outlined,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloAdminSingleSelectField<String>(
                label: 'Grupo',
                value: _group,
                options: const ['group-sun', 'group-moon'],
                optionLabel: (value) => value == 'group-sun' ? 'Grupo Sol' : 'Grupo Lua',
                onChanged: (value) => setState(() => _group = value),
                prefixIcon: Icons.groups_outlined,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloAdminSingleSelectField<String>(
                label: 'Contexto',
                value: _context,
                options: const ['group', 'activity'],
                optionLabel: (value) => value == 'group' ? 'Grupo' : 'Atividade',
                onChanged: (value) => setState(() => _context = value),
                prefixIcon: Icons.account_tree_outlined,
              ),
              if (_context == 'activity') ...[
                const SizedBox(height: CoeloSpacing.space4),
                CoeloAdminSingleSelectField<String>(
                  label: 'Atividade no grupo',
                  value: _activity,
                  options: const ['activity-music-group-sun', 'activity-art-group-sun'],
                  optionLabel: (value) => value == 'activity-music-group-sun'
                      ? 'Música · Chamada exigida'
                      : 'Artes · Chamada não exigida',
                  onChanged: (value) => setState(() => _activity = value),
                  prefixIcon: Icons.local_activity_outlined,
                ),
              ],
              const SizedBox(height: CoeloSpacing.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Data'),
                subtitle: const Text('03/08/2026'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.people_outline),
                title: Text('Participantes esperados'),
                subtitle: Text('3 participantes fictícios'),
              ),
              if (_notRequired)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(CoeloSpacing.space4),
                    child: Text(
                      'Chamada não exigida. Esta atividade não gera pendência nem afeta indicadores.',
                    ),
                  ),
                ),
              const SizedBox(height: CoeloSpacing.space5),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 600
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _canCreate ? _create : null,
                            child: const Text('Criar chamada'),
                          ),
                          const SizedBox(height: CoeloSpacing.space2),
                          OutlinedButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
                          FilledButton(
                            onPressed: _canCreate ? _create : null,
                            child: const Text('Criar chamada'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  bool get _canCreate => widget.permissions.canManage && !_notRequired;

  void _create() {
    final call = widget.repository.createCall(
      AttendanceCallDraft(
        institutionId: _institution,
        unitId: _unit,
        groupId: _group,
        activityContextId: _context == 'activity' ? _activity : null,
        date: AttendanceFixtures.today,
      ),
    );
    widget.onCreated(call.id);
  }
}

class AttendanceCallPage extends StatefulWidget {
  const AttendanceCallPage({
    required this.repository,
    required this.callId,
    required this.permissions,
    required this.logout,
    required this.onBack,
    required this.onPreview,
    this.focusedParticipantId,
    this.activityController,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final String callId;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onBack;
  final VoidCallback onPreview;
  final String? focusedParticipantId;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceCallPage> createState() => _AttendanceCallPageState();
}

class _AttendanceCallPageState extends State<AttendanceCallPage> {
  final _selected = <String>{};
  final _notes = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.repository.callById(widget.callId);
    if (call == null) return const Center(child: Text('Chamada não encontrada.'));
    final writable = widget.permissions.canManage;
    final concluded =
        call.status == AttendanceCallStatus.completed ||
        call.status == AttendanceCallStatus.corrected;
    return SuperadminShell(
      logout: widget.logout,
      title: 'Chamada · ${call.contextName}',
      subtitle: '${call.institutionName} · ${call.unitName} · ${call.groupName}',
      currentDestination: 'attendance',
      activityController: widget.activityController,
      actions: [
        OutlinedButton.icon(
          onPressed: widget.onPreview,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Visualizar como professor'),
        ),
      ],
      child: ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!writable) const _LocalDataNotice(readOnly: true) else const _LocalDataNotice(),
              const SizedBox(height: CoeloSpacing.space4),
              _CallProgress(call: call),
              const SizedBox(height: CoeloSpacing.space4),
              if (!concluded && writable) ...[
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => widget.repository.markRemainingPresent(call.id),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Marcar restantes como presentes'),
                    ),
                    if (_selected.isNotEmpty)
                      OutlinedButton(
                        onPressed: () => _applySelected(call, AttendancePresenceState.present),
                        child: Text('Aplicar presente a ${_selected.length} selecionados'),
                      ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
              ],
              for (final participant in call.participants)
                _ParticipantCard(
                  participant: participant,
                  notice: widget.repository.notices
                      .where(
                        (item) => item.participantId == participant.id && item.callId == call.id,
                      )
                      .firstOrNull,
                  focused: participant.id == widget.focusedParticipantId,
                  selected: _selected.contains(participant.id),
                  writable: writable && !concluded,
                  noteController: _notes.putIfAbsent(
                    participant.id,
                    () => TextEditingController(text: participant.note),
                  ),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selected.add(participant.id);
                    } else {
                      _selected.remove(participant.id);
                    }
                  }),
                  onStateChanged: (state) =>
                      widget.repository.setParticipantState(call.id, participant.id, state),
                  onConfirmNotice:
                      writable &&
                          !concluded &&
                          widget.repository.notices.any(
                            (item) =>
                                item.participantId == participant.id &&
                                item.callId == call.id &&
                                item.pending,
                          )
                      ? () => setState(() {
                          final notice = widget.repository.notices.firstWhere(
                            (item) =>
                                item.participantId == participant.id && item.callId == call.id,
                          );
                          widget.repository.confirmNotice(notice.id);
                        })
                      : null,
                ),
              const SizedBox(height: CoeloSpacing.space4),
              _CallSummary(call: call, pendingNotices: widget.repository.pendingNoticeCount),
              const SizedBox(height: CoeloSpacing.space4),
              if (concluded && writable)
                OutlinedButton.icon(
                  onPressed: () => _showCorrection(context, call),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Corrigir chamada'),
                )
              else if (writable)
                FilledButton(
                  onPressed: call.hasUnmarked
                      ? null
                      : () => widget.repository.completeCall(call.id),
                  child: const Text('Concluir chamada'),
                ),
              if (call.revisions.isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space5),
                Text('Histórico de correções', style: Theme.of(context).textTheme.titleMedium),
                for (final revision in call.revisions)
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text('${revision.previous.label} → ${revision.current.label}'),
                    subtitle: Text('${revision.author} · ${revision.reason}'),
                  ),
              ],
              const SizedBox(height: CoeloSpacing.space3),
              TextButton(onPressed: widget.onBack, child: const Text('Voltar para Assiduidade')),
            ],
          ),
        ),
      ),
    );
  }

  void _applySelected(AttendanceCall call, AttendancePresenceState state) {
    for (final id in _selected) {
      widget.repository.setParticipantState(call.id, id, state);
    }
    setState(_selected.clear);
  }

  Future<void> _showCorrection(BuildContext context, AttendanceCall call) async {
    final reason = TextEditingController();
    var state = call.participants.first.state;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Corrigir chamada',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoeloAdminSingleSelectField<AttendancePresenceState>(
                label: 'Novo estado de ${call.participants.first.name}',
                value: state,
                options: AttendancePresenceState.values
                    .where((item) => item != AttendancePresenceState.unmarked)
                    .toList(),
                optionLabel: (value) => value.label,
                onChanged: (value) => setDialogState(() => state = value),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: reason,
                labelText: 'Motivo da correção',
                prefixIcon: Icons.edit_note_outlined,
              ),
            ],
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              widget.repository.correctParticipant(
                callId: call.id,
                participantId: call.participants.first.id,
                state: state,
                reason: reason.text,
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Registrar correção'),
          ),
        ),
      ),
    );
    reason.dispose();
  }
}

class AttendanceTeacherPreviewPage extends StatelessWidget {
  const AttendanceTeacherPreviewPage({
    required this.repository,
    required this.callId,
    required this.permissions,
    required this.onBack,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final String callId;
  final AttendancePermissions permissions;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final call = repository.callById(callId);
    final allowed = call != null && permissions.canOperate(call);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Prévia da Chamada do professor'),
      ),
      body: SafeArea(
        child: allowed
            ? ListenableBuilder(
                listenable: repository,
                builder: (context, _) => SingleChildScrollView(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Prévia da Chamada do professor · dados locais · alterações não persistem',
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                      Text(call.contextName, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: CoeloSpacing.space3),
                      OutlinedButton(
                        onPressed: () => repository.markRemainingPresent(call.id),
                        child: const Text('Marcar restantes como presentes'),
                      ),
                      for (final participant in call.participants)
                        ListTile(
                          title: Text(participant.name),
                          subtitle: Text(participant.state.label),
                          trailing: PopupMenuButton<AttendancePresenceState>(
                            tooltip: 'Alterar estado de ${participant.name}',
                            onSelected: (state) =>
                                repository.setParticipantState(call.id, participant.id, state),
                            itemBuilder: (context) => AttendancePresenceState.values
                                .where((state) => state != AttendancePresenceState.unmarked)
                                .map(
                                  (state) => PopupMenuItem(value: state, child: Text(state.label)),
                                )
                                .toList(),
                          ),
                        ),
                      FilledButton(
                        onPressed: call.hasUnmarked ? null : () => repository.completeCall(call.id),
                        child: const Text('Concluir chamada'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space6),
                  child: Text(
                    'Esta chamada está fora do vínculo atribuído ao professor simulado.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
      ),
    );
  }
}

class _LocalDataNotice extends StatelessWidget {
  const _LocalDataNotice({this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          const Icon(Icons.memory_outlined),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Text(
              readOnly
                  ? 'Modo somente leitura · Dados locais de demonstração; recarregar restaura o estado inicial.'
                  : 'Dados locais de demonstração · As alterações não persistem após recarregar.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _TodayMetrics extends StatelessWidget {
  const _TodayMetrics({required this.repository});

  final InMemoryAttendanceRepository repository;

  @override
  Widget build(BuildContext context) {
    final calls = repository.calls.where((call) => call.date == AttendanceFixtures.today).toList();
    return _MetricGrid(
      metrics: [
        ('Chamadas esperadas', '${calls.length + 1}', Icons.event_available_outlined),
        (
          'Concluídas',
          '${calls.where((call) => call.status == AttendanceCallStatus.completed || call.status == AttendanceCallStatus.corrected).length}',
          Icons.task_alt_rounded,
        ),
        (
          'Pendentes',
          '${calls.where((call) => call.status == AttendanceCallStatus.notStarted || call.status == AttendanceCallStatus.inProgress).length}',
          Icons.pending_actions_outlined,
        ),
        (
          'Avisos familiares',
          '${repository.pendingNoticeCount}',
          Icons.notifications_active_outlined,
        ),
      ],
    );
  }
}

class _AnalyticMetrics extends StatelessWidget {
  const _AnalyticMetrics({required this.metrics});
  final AttendanceMetrics metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MetricGrid(
        metrics: [
          ('Presença', '${metrics.presencePercent.toStringAsFixed(1)}%', Icons.how_to_reg_outlined),
          ('Meta do contexto', '92%', Icons.flag_outlined),
          ('Variação', '+1,8 p.p.', Icons.trending_up_rounded),
          ('Justificadas', '${metrics.justifiedAbsences}', Icons.fact_check_outlined),
          ('Não justificadas', '${metrics.unjustifiedAbsences}', Icons.report_outlined),
          ('Atrasos', '${metrics.late}', Icons.schedule_outlined),
          ('Saídas antecipadas', '${metrics.earlyDepartures}', Icons.exit_to_app_rounded),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Semantics(
        label: 'Presença do período ${metrics.presencePercent.toStringAsFixed(1)} por cento',
        child: LinearProgressIndicator(
          value: metrics.presencePercent / 100,
          minHeight: CoeloSpacing.space2,
        ),
      ),
    ],
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200
          ? 4
          : constraints.maxWidth >= 600
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Row(
                    children: [
                      Icon(metric.$3),
                      const SizedBox(width: CoeloSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.$1, style: Theme.of(context).textTheme.bodyMedium),
                            Text(metric.$2, style: Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AttendanceCallList extends StatelessWidget {
  const _AttendanceCallList({
    required this.calls,
    required this.onOpenCall,
    required this.onInstitutionSelected,
  });
  final List<AttendanceCall> calls;
  final ValueChanged<String> onOpenCall;
  final ValueChanged<String> onInstitutionSelected;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final call in calls)
          ListTile(
            onTap: () => onOpenCall(call.id),
            leading: Icon(call.status.icon),
            title: Text(call.contextName),
            subtitle: Text(
              '${call.institutionName} · ${call.responsible}\n${call.markedCount}/${call.participants.length} preenchidos · ${call.status.label}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Filtrar por ${call.institutionName}',
              onPressed: () => onInstitutionSelected(call.institutionId),
              icon: const Icon(Icons.account_tree_outlined),
            ),
          ),
      ],
    ),
  );
}

class _ExpectationLegend extends StatelessWidget {
  const _ExpectationLegend();
  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: CoeloSpacing.space3,
    runSpacing: CoeloSpacing.space2,
    children: [
      Chip(avatar: Icon(Icons.block_outlined), label: Text('Chamada não exigida')),
      Chip(avatar: Icon(Icons.event_busy_outlined), label: Text('Nenhuma chamada prevista')),
      Chip(avatar: Icon(Icons.pending_actions_outlined), label: Text('Chamada não iniciada')),
    ],
  );
}

class _CallProgress extends StatelessWidget {
  const _CallProgress({required this.call});
  final AttendanceCall call;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${call.participants.length} esperados · ${call.markedCount} preenchidos · ${call.participants.length - call.markedCount} pendentes',
          ),
          const SizedBox(height: CoeloSpacing.space2),
          LinearProgressIndicator(
            value: call.participants.isEmpty ? 0 : call.markedCount / call.participants.length,
          ),
        ],
      ),
    ),
  );
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.notice,
    required this.focused,
    required this.selected,
    required this.writable,
    required this.noteController,
    required this.onSelected,
    required this.onStateChanged,
    required this.onConfirmNotice,
  });
  final AttendanceParticipant participant;
  final AttendanceNotice? notice;
  final bool focused;
  final bool selected;
  final bool writable;
  final TextEditingController noteController;
  final ValueChanged<bool> onSelected;
  final ValueChanged<AttendancePresenceState> onStateChanged;
  final VoidCallback? onConfirmNotice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: focused ? colors.primaryContainer : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: writable ? (value) => onSelected(value ?? false) : null,
                ),
                Expanded(
                  child: Text(participant.name, style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(participant.state.label),
              ],
            ),
            if (notice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(notice!.pending ? 'Aguardando confirmação' : 'Aviso confirmado'),
                    subtitle: Text(
                      '${notice!.intent.label} · ${notice!.reason}\nO aviso não altera o registro oficial.',
                    ),
                  ),
                  if (onConfirmNotice != null)
                    OutlinedButton.icon(
                      onPressed: onConfirmNotice,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Confirmar registro oficial'),
                    ),
                ],
              ),
            CoeloAdminSingleSelectField<AttendancePresenceState>(
              label: 'Estado de presença',
              value: participant.state,
              options: AttendancePresenceState.values,
              optionLabel: (value) => value.label,
              onChanged: onStateChanged,
              enabled: writable,
              prefixIcon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            CoeloFormTextField(
              controller: noteController,
              labelText: 'Observação individual',
              prefixIcon: Icons.notes_outlined,
              enabled: writable,
              maxLines: 2,
              onChanged: (value) => participant.note = value,
            ),
          ],
        ),
      ),
    );
  }
}

class _CallSummary extends StatelessWidget {
  const _CallSummary({required this.call, required this.pendingNotices});
  final AttendanceCall call;
  final int pendingNotices;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final state in AttendancePresenceState.values)
            Text(
              '${state.label}: ${call.participants.where((item) => item.state == state).length}',
            ),
          Text('Avisos familiares pendentes: $pendingNotices'),
        ],
      ),
    ),
  );
}

enum _AttendancePeriod { today, last7Days, last30Days, currentMonth, custom }

extension on _AttendancePeriod {
  String get label => switch (this) {
    _AttendancePeriod.today => 'Hoje',
    _AttendancePeriod.last7Days => '7 dias',
    _AttendancePeriod.last30Days => '30 dias',
    _AttendancePeriod.currentMonth => 'Mês atual',
    _AttendancePeriod.custom => 'Período personalizado',
  };
}

extension AttendancePresencePresentation on AttendancePresenceState {
  String get label => switch (this) {
    AttendancePresenceState.unmarked => 'Não marcado',
    AttendancePresenceState.present => 'Presente',
    AttendancePresenceState.absent => 'Ausente',
    AttendancePresenceState.late => 'Atraso',
    AttendancePresenceState.earlyDeparture => 'Saída antecipada',
  };
}

extension on AttendanceCallStatus {
  String get label => switch (this) {
    AttendanceCallStatus.notStarted => 'Não iniciada',
    AttendanceCallStatus.inProgress => 'Em andamento',
    AttendanceCallStatus.completed => 'Concluída',
    AttendanceCallStatus.corrected => 'Corrigida',
  };

  IconData get icon => switch (this) {
    AttendanceCallStatus.notStarted => Icons.pending_actions_outlined,
    AttendanceCallStatus.inProgress => Icons.play_circle_outline,
    AttendanceCallStatus.completed => Icons.task_alt_rounded,
    AttendanceCallStatus.corrected => Icons.history_rounded,
  };
}

extension on AttendanceNoticeIntent {
  String get label => switch (this) {
    AttendanceNoticeIntent.absence => 'Ausência informada',
    AttendanceNoticeIntent.expectedPresence => 'Presença esperada',
    AttendanceNoticeIntent.lateArrival => 'Chegada atrasada',
    AttendanceNoticeIntent.earlyDeparture => 'Saída antecipada',
  };
}

String _institutionLabel(String id) => switch (id) {
  'institution-2' => 'Colégio Aurora · meta 90%',
  'institution-3' => 'Espaço Ipê · meta 95%',
  _ => 'Instituto Horizonte · meta 92%',
};
