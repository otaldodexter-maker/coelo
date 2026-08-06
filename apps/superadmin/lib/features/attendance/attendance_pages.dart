import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/shell/superadmin_shell.dart';
import '../../app/activity/superadmin_activity.dart';
import '../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
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
  String? _institutionId;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Assiduidade',
    subtitle: 'Lance chamadas e acompanhe o histórico de cada contexto.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
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
              if (widget.permissions.canManage) ...[
                const SizedBox(height: CoeloSpacing.space6),
                LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                          ? 340
                          : constraints.maxWidth,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 216),
                        child: CoeloAdminCreateAction(
                          label: 'Nova chamada',
                          icon: Icons.how_to_reg_outlined,
                          onPressed: widget.onCreate,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space8),
              Text('Histórico de chamadas', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space3),
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
    this.initialInstitutionId,
    this.initialUnitId,
    this.initialGroupId,
    this.initialActivityId,
    this.activityController,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<String> onCreated;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final String? initialGroupId;
  final String? initialActivityId;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceNewCallPage> createState() => _AttendanceNewCallPageState();
}

class _AttendanceNewCallPageState extends State<AttendanceNewCallPage> {
  static const _institutions = ['institution-1', 'institution-2', 'institution-3'];
  static const _units = ['unit-1', 'unit-2'];
  static const _groups = ['group-sun', 'group-moon'];
  static const _activities = ['activity-music-group-sun', 'activity-art-group-sun'];

  late String _institution;
  late String _unit;
  late String _group;
  late String _context;
  late String _activity;

  @override
  void initState() {
    super.initState();
    _institution = _initialValue(widget.initialInstitutionId, _institutions);
    _unit = _initialValue(widget.initialUnitId, _units);
    _group = _initialValue(widget.initialGroupId, _groups);
    _activity = _initialValue(widget.initialActivityId, _activities);
    _context = widget.initialActivityId == null ? 'group' : 'activity';
  }

  bool get _notRequired => _context == 'activity' && _activity == 'activity-art-group-sun';
  bool get _canCreate => widget.permissions.canManage && !_notRequired;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Lançar chamada',
    subtitle: 'Selecione o contexto antes de registrar a presença.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
        final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        final navigation = SuperadminFormStepNavigation(
          currentIndex: 0,
          steps: [
            SuperadminFormStep(label: 'Contexto', status: SuperadminFormStepStatus.current),
            SuperadminFormStep(
              label: 'Chamada',
              status: SuperadminFormStepStatus.incomplete,
              enabled: _canCreate,
            ),
          ],
          onStepSelected: (index) {
            if (index == 1 && _canCreate) _create();
          },
        );
        final content = Expanded(
          child: Column(
            children: [
              if (!wide) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('attendance-context-scroll'),
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Contexto da chamada',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: CoeloSpacing.space2),
                          Text(
                            'A data é hoje. Escolha a turma e, quando necessário, a atividade.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: CoeloSpacing.space5),
                          const _AttendanceInlineNotice(),
                          const SizedBox(height: CoeloSpacing.space5),
                          CoeloAdminSingleSelectField<String>(
                            label: 'Instituição',
                            value: _institution,
                            options: _institutions,
                            optionLabel: _institutionLabel,
                            onChanged: (value) => setState(() => _institution = value),
                            prefixIcon: Icons.account_balance_outlined,
                          ),
                          const SizedBox(height: CoeloSpacing.space4),
                          CoeloAdminSingleSelectField<String>(
                            label: 'Unidade',
                            value: _unit,
                            options: _units,
                            optionLabel: _unitLabel,
                            onChanged: (value) => setState(() => _unit = value),
                            prefixIcon: Icons.apartment_outlined,
                          ),
                          const SizedBox(height: CoeloSpacing.space4),
                          CoeloAdminSingleSelectField<String>(
                            label: 'Turma',
                            value: _group,
                            options: _groups,
                            optionLabel: _groupLabel,
                            onChanged: (value) => setState(() => _group = value),
                            prefixIcon: Icons.groups_outlined,
                          ),
                          const SizedBox(height: CoeloSpacing.space4),
                          CoeloAdminSingleSelectField<String>(
                            label: 'Contexto',
                            value: _context,
                            options: const ['group', 'activity'],
                            optionLabel: (value) => value == 'group' ? 'Turma' : 'Atividade',
                            onChanged: (value) => setState(() => _context = value),
                            prefixIcon: Icons.account_tree_outlined,
                          ),
                          if (_context == 'activity') ...[
                            const SizedBox(height: CoeloSpacing.space4),
                            CoeloAdminSingleSelectField<String>(
                              label: 'Atividade na turma',
                              value: _activity,
                              options: _activities,
                              optionLabel: _activityLabel,
                              onChanged: (value) => setState(() => _activity = value),
                              prefixIcon: Icons.local_activity_outlined,
                            ),
                          ],
                          const SizedBox(height: CoeloSpacing.space5),
                          const _AttendanceContextFacts(),
                          if (_notRequired) ...[
                            const SizedBox(height: CoeloSpacing.space4),
                            const _AttendanceRequirementNotice(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SuperadminFormActionFooter(
                surfaceKey: const Key('attendance-context-footer'),
                tertiaryAction: TextButton(
                  key: const Key('attendance-context-cancel'),
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                continuationActions: [
                  FilledButton(
                    key: const Key('attendance-context-continue'),
                    onPressed: _canCreate ? _create : null,
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ],
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
              content,
            ],
          ),
        );
      },
    ),
  );

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

  static String _initialValue(String? value, List<String> options) =>
      value != null && options.contains(value) ? value : options.first;
}

class _AttendanceInlineNotice extends StatelessWidget {
  const _AttendanceInlineNotice({this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
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

class _AttendanceContextFacts extends StatelessWidget {
  const _AttendanceContextFacts();

  @override
  Widget build(BuildContext context) {
    final date = AttendanceFixtures.today;
    final facts = [
      _AttendanceFact(
        icon: Icons.calendar_today_outlined,
        label: 'Data',
        value: 'Hoje · ${_attendanceDate(date)}',
      ),
      const _AttendanceFact(
        icon: Icons.people_outline,
        label: 'Participantes esperados',
        value: '3 participantes',
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
              return Column(
                children: [
                  facts.first,
                  const SizedBox(height: CoeloSpacing.space3),
                  facts.last,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: facts.first),
                const SizedBox(width: CoeloSpacing.space6),
                Expanded(child: facts.last),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceFact extends StatelessWidget {
  const _AttendanceFact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AttendanceRequirementNotice extends StatelessWidget {
  const _AttendanceRequirementNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space3),
          const Expanded(
            child: Text(
              'Chamada não exigida. Esta atividade não gera pendência nem afeta indicadores.',
            ),
          ),
        ],
      ),
    ),
  );
}

String _unitLabel(String value) => value == 'unit-1' ? 'Unidade Centro' : 'Unidade Norte';
String _groupLabel(String value) => value == 'group-sun' ? 'Turma Sol' : 'Turma Lua';
String _activityLabel(String value) => value == 'activity-music-group-sun'
    ? 'Música · Chamada exigida'
    : 'Artes · Chamada não exigida';

class AttendanceCallPage extends StatefulWidget {
  const AttendanceCallPage({
    required this.repository,
    required this.callId,
    required this.permissions,
    required this.logout,
    required this.onBack,
    this.focusedParticipantId,
    this.participantRoutineBuilder,
    this.routinePendingParticipantIds = const {},
    this.activityController,
    super.key,
  });

  final InMemoryAttendanceRepository repository;
  final String callId;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onBack;
  final String? focusedParticipantId;
  final Widget Function(BuildContext context, AttendanceParticipant participant)?
  participantRoutineBuilder;
  final Set<String> routinePendingParticipantIds;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceCallPage> createState() => _AttendanceCallPageState();
}

class _AttendanceCallPageState extends State<AttendanceCallPage> {
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
    final writable = widget.permissions.canManage || widget.permissions.canOperate(call);
    final concluded =
        call.status == AttendanceCallStatus.completed ||
        call.status == AttendanceCallStatus.corrected;
    final firstPendingRoutine = call.participants
        .where((item) => widget.routinePendingParticipantIds.contains(item.id))
        .firstOrNull;
    return SuperadminShell(
      logout: widget.logout,
      title: concluded ? 'Chamada · ${call.contextName}' : 'Lançar chamada',
      subtitle: '${call.institutionName} · ${call.unitName} · ${call.groupName}',
      currentDestination: 'attendance',
      activityController: widget.activityController,
      child: ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
            final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                ? CoeloSpacing.space10
                : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                ? CoeloSpacing.space6
                : CoeloSpacing.space4;
            final navigation = SuperadminFormStepNavigation(
              currentIndex: 1,
              steps: const [
                SuperadminFormStep(label: 'Contexto', status: SuperadminFormStepStatus.complete),
                SuperadminFormStep(label: 'Chamada', status: SuperadminFormStepStatus.current),
              ],
              onStepSelected: (index) {
                if (index == 0) widget.onBack();
              },
            );
            final colors = Theme.of(context).colorScheme;
            final content = Expanded(
              child: Column(
                children: [
                  if (!wide) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('attendance-call-scroll'),
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AttendanceInlineNotice(readOnly: !writable),
                              const SizedBox(height: CoeloSpacing.space4),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  border: Border.all(color: colors.outlineVariant),
                                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hoje · ${_attendanceDate(call.date)}',
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: CoeloSpacing.spaceHalf),
                                      Text(
                                        '${call.groupName} · ${call.contextName}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${call.institutionName} · ${call.unitName} · '
                                        '${call.participants.length} participantes',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: CoeloSpacing.space4),
                              DecoratedBox(
                                key: const Key('attendance-participant-list'),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  border: Border.all(color: colors.outlineVariant),
                                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(CoeloSpacing.space4),
                                        child: _AttendanceCallToolbar(
                                          call: call,
                                          writable: writable && !concluded,
                                          onMarkRemaining: () =>
                                              widget.repository.markRemainingPresent(call.id),
                                        ),
                                      ),
                                      Divider(height: 1, color: colors.outlineVariant),
                                      if (call.participants.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(CoeloSpacing.space6),
                                          child: Text(
                                            'Nenhum participante encontrado para este contexto.',
                                          ),
                                        )
                                      else
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: call.participants.length,
                                          separatorBuilder: (context, index) =>
                                              Divider(height: 1, color: colors.outlineVariant),
                                          itemBuilder: (context, index) {
                                            final participant = call.participants[index];
                                            final notice = widget.repository.notices
                                                .where(
                                                  (item) =>
                                                      item.participantId == participant.id &&
                                                      item.callId == call.id,
                                                )
                                                .firstOrNull;
                                            return _ParticipantCard(
                                              participant: participant,
                                              notice: notice,
                                              focused:
                                                  participant.id == widget.focusedParticipantId,
                                              writable: writable && !concluded,
                                              routine: widget.participantRoutineBuilder?.call(
                                                context,
                                                participant,
                                              ),
                                              routinePending: widget.routinePendingParticipantIds
                                                  .contains(participant.id),
                                              routineInitiallyExpanded:
                                                  firstPendingRoutine?.id == participant.id,
                                              noteController: _notes.putIfAbsent(
                                                participant.id,
                                                () => TextEditingController(text: participant.note),
                                              ),
                                              onStateChanged: (state) =>
                                                  widget.repository.setParticipantState(
                                                    call.id,
                                                    participant.id,
                                                    state,
                                                  ),
                                              onConfirmNotice:
                                                  notice != null && notice.pending && writable
                                                  ? () => widget.repository.confirmNotice(notice.id)
                                                  : null,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: CoeloSpacing.space4),
                              _AttendanceCompletionHint(
                                call: call,
                                requiredRoutineCount: widget.routinePendingParticipantIds.length,
                              ),
                              if (!writable) ...[
                                const SizedBox(height: CoeloSpacing.space3),
                                TextButton(
                                  onPressed: widget.onBack,
                                  child: const Text('Voltar para Assiduidade'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (writable)
                    SuperadminFormActionFooter(
                      surfaceKey: const Key('attendance-call-footer'),
                      tertiaryAction: TextButton(
                        onPressed: widget.onBack,
                        child: const Text('Voltar para Assiduidade'),
                      ),
                      continuationActions: [
                        if (concluded)
                          OutlinedButton.icon(
                            onPressed: () => _showCorrection(context, call),
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Corrigir chamada'),
                          )
                        else
                          FilledButton(
                            key: const Key('attendance-call-complete'),
                            onPressed:
                                call.hasUnmarked || widget.routinePendingParticipantIds.isNotEmpty
                                ? null
                                : () => widget.repository.completeCall(call.id),
                            child: const Text('Concluir chamada'),
                          ),
                      ],
                    ),
                ],
              ),
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
                  content,
                ],
              ),
            );
          },
        ),
      ),
    );
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

class _AttendanceCallToolbar extends StatelessWidget {
  const _AttendanceCallToolbar({
    required this.call,
    required this.writable,
    required this.onMarkRemaining,
  });

  final AttendanceCall call;
  final bool writable;
  final VoidCallback onMarkRemaining;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alunos de ${call.groupName}', style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${call.markedCount} marcados · '
            '${call.participants.length - call.markedCount} sem marcação',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
      final action = OutlinedButton.icon(
        onPressed: writable ? onMarkRemaining : null,
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Marcar restantes como presentes'),
      );
      if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: CoeloSpacing.space3),
            action,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          action,
        ],
      );
    },
  );
}

class _AttendanceCompletionHint extends StatelessWidget {
  const _AttendanceCompletionHint({required this.call, required this.requiredRoutineCount});

  final AttendanceCall call;
  final int requiredRoutineCount;

  @override
  Widget build(BuildContext context) {
    final unmarked = call.participants.length - call.markedCount;
    final ready = unmarked == 0 && requiredRoutineCount == 0;
    return Semantics(
      liveRegion: true,
      child: Text(
        ready
            ? 'Todos os participantes estão prontos para conclusão.'
            : 'Conclua $unmarked presenças e $requiredRoutineCount respostas obrigatórias.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ready
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

String _attendanceDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class _AttendanceStateButton extends StatelessWidget {
  const _AttendanceStateButton({
    required this.label,
    required this.state,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final AttendancePresenceState state;
  final bool selected;
  final bool enabled;
  final ValueChanged<AttendancePresenceState> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label para presença',
      child: OutlinedButton(
        onPressed: enabled ? () => onSelected(state) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
          foregroundColor: selected ? colors.primary : colors.onSurface,
          backgroundColor: selected ? colors.primaryContainer : colors.surface,
          side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AttendanceStatusLabel extends StatelessWidget {
  const _AttendanceStatusLabel({required this.state});

  final AttendancePresenceState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = state == AttendancePresenceState.absent ? 'Falta' : state.label;
    return Semantics(
      label: 'Estado de presença: $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: state == AttendancePresenceState.unmarked
              ? colors.surfaceContainerHighest
              : colors.primaryContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space3,
            vertical: CoeloSpacing.space2,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: state == AttendancePresenceState.unmarked
                  ? colors.onSurfaceVariant
                  : colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceRoutineSection extends StatelessWidget {
  const _AttendanceRoutineSection({required this.pending, required this.child});

  final bool pending;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Rotina diária', style: Theme.of(context).textTheme.titleSmall)),
              if (pending)
                Text(
                  '1 obrigatória pendente',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          child,
        ],
      ),
    ),
  );
}

class _ParticipantCard extends StatefulWidget {
  const _ParticipantCard({
    required this.participant,
    required this.notice,
    required this.focused,
    required this.writable,
    required this.routine,
    required this.routinePending,
    required this.routineInitiallyExpanded,
    required this.noteController,
    required this.onStateChanged,
    required this.onConfirmNotice,
  });

  final AttendanceParticipant participant;
  final AttendanceNotice? notice;
  final bool focused;
  final bool writable;
  final Widget? routine;
  final bool routinePending;
  final bool routineInitiallyExpanded;
  final TextEditingController noteController;
  final ValueChanged<AttendancePresenceState> onStateChanged;
  final VoidCallback? onConfirmNotice;

  @override
  State<_ParticipantCard> createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<_ParticipantCard> {
  late bool _detailsExpanded = widget.focused;
  late bool _routineExpanded = widget.routineInitiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: widget.focused ? colors.primaryContainer : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final identity = _identity(context);
                final status = _AttendanceStatusLabel(state: widget.participant.state);
                final actions = _actions();
                if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: CoeloSpacing.space2),
                      Align(alignment: AlignmentDirectional.centerStart, child: status),
                      const SizedBox(height: CoeloSpacing.space3),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: identity),
                    const SizedBox(width: CoeloSpacing.space3),
                    status,
                    const SizedBox(width: CoeloSpacing.space3),
                    Flexible(flex: 5, child: actions),
                  ],
                );
              },
            ),
            if (_detailsExpanded) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _details(context),
            ],
            if (_routineExpanded && widget.routine != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _AttendanceRoutineSection(pending: widget.routinePending, child: widget.routine!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = widget.participant.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
    return Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.primary,
            child: Text(initials),
          ),
        ),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.participant.name, style: Theme.of(context).textTheme.titleSmall),
              Text(
                widget.notice == null
                    ? 'Sem aviso da família'
                    : widget.notice!.pending
                    ? 'Aviso da família pendente'
                    : 'Aviso da família confirmado',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.notice?.pending == true ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions() => Wrap(
    alignment: WrapAlignment.end,
    spacing: CoeloSpacing.space2,
    runSpacing: CoeloSpacing.space2,
    children: [
      _AttendanceStateButton(
        label: 'Presente',
        state: AttendancePresenceState.present,
        selected: widget.participant.state == AttendancePresenceState.present,
        enabled: widget.writable,
        onSelected: widget.onStateChanged,
      ),
      _AttendanceStateButton(
        label: 'Falta',
        state: AttendancePresenceState.absent,
        selected: widget.participant.state == AttendancePresenceState.absent,
        enabled: widget.writable,
        onSelected: widget.onStateChanged,
      ),
      _AttendanceStateButton(
        label: 'Atraso',
        state: AttendancePresenceState.late,
        selected: widget.participant.state == AttendancePresenceState.late,
        enabled: widget.writable,
        onSelected: widget.onStateChanged,
      ),
      _AttendanceStateButton(
        label: 'Saída antecipada',
        state: AttendancePresenceState.earlyDeparture,
        selected: widget.participant.state == AttendancePresenceState.earlyDeparture,
        enabled: widget.writable,
        onSelected: widget.onStateChanged,
      ),
      TextButton.icon(
        onPressed: () => setState(() => _detailsExpanded = !_detailsExpanded),
        icon: Icon(_detailsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        label: const Text('Detalhes'),
      ),
      if (widget.routine != null)
        TextButton.icon(
          onPressed: () => setState(() => _routineExpanded = !_routineExpanded),
          icon: Icon(_routineExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: const Text('Rotina'),
        ),
    ],
  );

  Widget _details(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.notice != null) ...[
            Text(
              '${widget.notice!.intent.label} · ${widget.notice!.reason}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: CoeloSpacing.spaceHalf),
            Text('${widget.notice!.note} O aviso não altera o registro oficial.'),
            if (widget.onConfirmNotice != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onConfirmNotice,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirmar registro oficial'),
                ),
              ),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          CoeloFormTextField(
            controller: widget.noteController,
            labelText: 'Observação individual',
            prefixIcon: Icons.notes_outlined,
            enabled: widget.writable,
            maxLines: 2,
            onChanged: (value) => widget.participant.note = value,
          ),
        ],
      ),
    ),
  );
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
