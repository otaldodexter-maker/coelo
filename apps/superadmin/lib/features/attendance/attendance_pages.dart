import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/shell/superadmin_shell.dart';
import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_notice.dart';
import '../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../auth/domain/logout_action.dart';
import '../daily_routine/daily_routine.dart';
import '../daily_routine/daily_routine_feeling_picker.dart';
import 'attendance.dart';

export 'attendance_dashboard_page.dart';

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
    this.today,
    this.activityController,
    super.key,
  });

  final AttendanceRepository repository;
  final AttendancePermissions permissions;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<String> onCreated;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final String? initialGroupId;
  final String? initialActivityId;
  final DateTime? today;
  final SuperadminActivityController? activityController;

  @override
  State<AttendanceNewCallPage> createState() => _AttendanceNewCallPageState();
}

class _AttendanceNewCallPageState extends State<AttendanceNewCallPage> {
  final _dateFocusNode = FocusNode(debugLabel: 'attendance-date-picker');
  AttendanceContextOptions? _options;
  Object? _loadError;
  String? _institution;
  String? _unit;
  String? _group;
  late String _context;
  String? _activity;
  late DateTime _date;
  var _currentStep = 0;
  var _submitting = false;
  Object? _commandError;
  var _optionsLoadGeneration = 0;

  DateTime get _today => DateUtils.dateOnly(widget.today ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _context = widget.initialActivityId == null ? 'group' : 'activity';
    _date = _today;
    _loadOptions(useInitialValues: true);
  }

  @override
  void didUpdateWidget(covariant AttendanceNewCallPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) && oldWidget.today == widget.today) {
      return;
    }
    _date = _today;
    _loadOptions(useInitialValues: true);
  }

  @override
  void dispose() {
    _optionsLoadGeneration++;
    _dateFocusNode.dispose();
    super.dispose();
  }

  List<AttendanceContextOption> get _institutions => _options?.institutions ?? const [];
  List<AttendanceContextOption> get _units => (_options?.units ?? const [])
      .where((item) => item.institutionId == null || item.institutionId == _institution)
      .toList(growable: false);
  List<AttendanceContextOption> get _groups => (_options?.groups ?? const [])
      .where(
        (item) =>
            (item.institutionId == null || item.institutionId == _institution) &&
            (item.unitId == null || item.unitId == _unit),
      )
      .toList(growable: false);
  List<AttendanceContextOption> get _activities => (_options?.activities ?? const [])
      .where(
        (item) =>
            (item.institutionId == null || item.institutionId == _institution) &&
            (item.unitId == null || item.unitId == _unit) &&
            (item.groupId == null || item.groupId == _group),
      )
      .toList(growable: false);

  AttendanceContextOption? get _selectedActivity =>
      _activities.where((item) => item.id == _activity).firstOrNull;
  bool get _notRequired => _context == 'activity' && _selectedActivity?.attendanceRequired == false;
  bool get _hasSelection =>
      _institution != null &&
      _unit != null &&
      _group != null &&
      (_context == 'group' || _selectedActivity != null);
  bool get _canCreate =>
      widget.permissions.canCreate(backendCanManage: _options!.canManage) &&
      (_options?.canManage ?? false) &&
      _hasSelection &&
      !_notRequired;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Lançar chamada',
    subtitle: 'Selecione o contexto antes de registrar a presença.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    child: _options == null
        ? _loadingOrFailure()
        : !_hasSelection
        ? _emptyState()
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
              final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                  ? CoeloSpacing.space10
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? CoeloSpacing.space6
                  : CoeloSpacing.space4;
              final navigation = SuperadminFormStepNavigation(
                currentIndex: _currentStep,
                steps: [
                  SuperadminFormStep(
                    label: 'Contexto',
                    status: _currentStep == 0
                        ? SuperadminFormStepStatus.current
                        : SuperadminFormStepStatus.complete,
                  ),
                  SuperadminFormStep(
                    label: 'Rotina diária',
                    status: _currentStep == 1
                        ? SuperadminFormStepStatus.current
                        : SuperadminFormStepStatus.incomplete,
                  ),
                  const SuperadminFormStep(
                    label: 'Chamada',
                    status: SuperadminFormStepStatus.incomplete,
                  ),
                ],
                onStepSelected: (index) {
                  if (index < 2) setState(() => _currentStep = index);
                  if (index == 2 && _canCreate && !_submitting) _create();
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
                                  _currentStep == 0
                                      ? 'Contexto da chamada'
                                      : 'Rotina diária vinculada',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: CoeloSpacing.space2),
                                Text(
                                  _currentStep == 0
                                      ? 'Escolha a data, a turma e, quando necessário, a atividade.'
                                      : 'Confira a rotina efetiva antes de lançar a chamada.',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: CoeloSpacing.space5),
                                OutlinedButton.icon(
                                  key: const Key('attendance-date-picker'),
                                  focusNode: _dateFocusNode,
                                  onPressed:
                                      widget.permissions.canCreate(
                                        backendCanManage: _options!.canManage,
                                      )
                                      ? _pickDate
                                      : null,
                                  icon: const Icon(Icons.calendar_today_outlined),
                                  label: Text('Data da chamada · ${_attendanceDate(_date)}'),
                                ),
                                if (_currentStep == 1) ...[
                                  const SizedBox(height: CoeloSpacing.space4),
                                  const Text(
                                    'A rotina aplicável será resolvida pelo contexto autorizado.',
                                  ),
                                ],
                                const SizedBox(height: CoeloSpacing.space5),
                                CoeloAdminSingleSelectField<String>(
                                  label: 'Instituição',
                                  value: _institution!,
                                  options: _institutions
                                      .map((item) => item.id)
                                      .toList(growable: false),
                                  optionLabel: (id) => _labelFor(_institutions, id),
                                  onChanged: _selectInstitution,
                                  prefixIcon: Icons.account_balance_outlined,
                                ),
                                const SizedBox(height: CoeloSpacing.space4),
                                CoeloAdminSingleSelectField<String>(
                                  label: 'Unidade',
                                  value: _unit!,
                                  options: _units.map((item) => item.id).toList(growable: false),
                                  optionLabel: (id) => _labelFor(_units, id),
                                  onChanged: _selectUnit,
                                  prefixIcon: Icons.apartment_outlined,
                                ),
                                const SizedBox(height: CoeloSpacing.space4),
                                CoeloAdminSingleSelectField<String>(
                                  label: 'Turma',
                                  value: _group!,
                                  options: _groups.map((item) => item.id).toList(growable: false),
                                  optionLabel: (id) => _labelFor(_groups, id),
                                  onChanged: _selectGroup,
                                  prefixIcon: Icons.groups_outlined,
                                ),
                                const SizedBox(height: CoeloSpacing.space4),
                                CoeloAdminSingleSelectField<String>(
                                  label: 'Contexto',
                                  value: _context,
                                  options: _activities.isEmpty
                                      ? const ['group']
                                      : const ['group', 'activity'],
                                  optionLabel: (value) => value == 'group' ? 'Turma' : 'Atividade',
                                  onChanged: (value) => setState(() {
                                    _context = value;
                                    if (value == 'activity') {
                                      _activity = _validId(_activity, _activities);
                                    }
                                  }),
                                  prefixIcon: Icons.account_tree_outlined,
                                ),
                                if (_context == 'activity' && _activities.isNotEmpty) ...[
                                  const SizedBox(height: CoeloSpacing.space4),
                                  CoeloAdminSingleSelectField<String>(
                                    label: 'Atividade na turma',
                                    value: _activity!,
                                    options: _activities
                                        .map((item) => item.id)
                                        .toList(growable: false),
                                    optionLabel: (id) => _labelFor(_activities, id),
                                    onChanged: (value) => setState(() => _activity = value),
                                    prefixIcon: Icons.local_activity_outlined,
                                  ),
                                ],
                                const SizedBox(height: CoeloSpacing.space5),
                                _AttendanceContextFacts(date: _date, today: _today),
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
                    if (_commandError != null) ...[
                      const SizedBox(height: CoeloSpacing.space3),
                      const _AttendanceCommandErrorBanner(
                        message: 'Não foi possível criar a chamada.',
                      ),
                    ],
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
                          onPressed: !_canCreate || _submitting
                              ? null
                              : _currentStep == 0
                              ? () => setState(() => _currentStep = 1)
                              : _create,
                          child: Text(_currentStep == 0 ? 'Continuar' : 'Lançar chamada'),
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

  Future<void> _pickDate() async {
    final today = _today;
    final selected = await showCoeloDateRangePicker(
      context: context,
      value: DateTimeRange(start: _date, end: _date),
      firstDate: DateTime(1970),
      lastDate: today,
      currentDate: today,
      showQuickRanges: false,
      selectionMode: CoeloDateSelectionMode.single,
    );
    if (!mounted) return;
    _dateFocusNode.requestFocus();
    if (selected == null) return;
    _date = DateUtils.dateOnly(selected.start);
    await _loadOptions();
  }

  Future<void> _loadOptions({bool useInitialValues = false}) async {
    final generation = ++_optionsLoadGeneration;
    final repository = widget.repository;
    final requestedDate = _date;
    if (mounted) {
      setState(() {
        _options = null;
        _loadError = null;
      });
    }
    try {
      final options = await repository.fetchContextOptions(date: requestedDate);
      if (!_isCurrentOptionsLoad(generation, repository, requestedDate)) return;
      final preferredInstitution = useInitialValues ? widget.initialInstitutionId : _institution;
      final institution = _validId(preferredInstitution, options.institutions);
      final units = options.units
          .where((item) => item.institutionId == null || item.institutionId == institution)
          .toList(growable: false);
      final preferredUnit = useInitialValues ? widget.initialUnitId : _unit;
      final unit = _validId(preferredUnit, units);
      final groups = options.groups
          .where(
            (item) =>
                (item.institutionId == null || item.institutionId == institution) &&
                (item.unitId == null || item.unitId == unit),
          )
          .toList(growable: false);
      final preferredGroup = useInitialValues ? widget.initialGroupId : _group;
      final group = _validId(preferredGroup, groups);
      final activities = options.activities
          .where(
            (item) =>
                (item.institutionId == null || item.institutionId == institution) &&
                (item.unitId == null || item.unitId == unit) &&
                (item.groupId == null || item.groupId == group),
          )
          .toList(growable: false);
      final preferredActivity = useInitialValues ? widget.initialActivityId : _activity;
      final activity = _validId(preferredActivity, activities);
      setState(() {
        _options = options;
        _institution = institution;
        _unit = unit;
        _group = group;
        _activity = activity;
        if (_context == 'activity' && activity == null) _context = 'group';
      });
    } catch (error) {
      if (_isCurrentOptionsLoad(generation, repository, requestedDate)) {
        setState(() => _loadError = error);
      }
    }
  }

  bool _isCurrentOptionsLoad(
    int generation,
    AttendanceRepository repository,
    DateTime requestedDate,
  ) =>
      mounted &&
      generation == _optionsLoadGeneration &&
      identical(repository, widget.repository) &&
      DateUtils.isSameDay(requestedDate, _date);

  Widget _loadingOrFailure() {
    final error = _loadError;
    if (error == null) {
      return const Center(
        key: Key('attendance-context-loading'),
        child: CircularProgressIndicator(),
      );
    }
    final unauthorized = error is AttendanceUnauthorizedException;
    return CoeloStatePanel(
      key: Key(unauthorized ? 'attendance-context-unauthorized' : 'attendance-context-failure'),
      title: unauthorized ? 'Acesso n\u00e3o autorizado' : 'N\u00e3o foi poss\u00edvel carregar',
      message: unauthorized
          ? 'Voc\u00ea n\u00e3o tem acesso aos contextos desta chamada.'
          : 'Verifique sua conex\u00e3o e tente novamente.',
      icon: unauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
      actionLabel: unauthorized ? 'Voltar para Assiduidade' : 'Tentar novamente',
      onAction: unauthorized ? widget.onCancel : _loadOptions,
    );
  }

  Widget _emptyState() => CoeloStatePanel(
    key: const Key('attendance-context-empty'),
    title: 'Nenhum contexto dispon\u00edvel',
    message: 'N\u00e3o h\u00e1 institui\u00e7\u00e3o, unidade e turma autorizadas para esta data.',
    icon: Icons.event_busy_outlined,
    actionLabel: 'Escolher outra data',
    onAction: _pickDate,
  );

  void _selectInstitution(String value) => setState(() {
    _institution = value;
    _unit = _validId(null, _units);
    _group = _validId(null, _groups);
    _activity = _validId(null, _activities);
    if (_context == 'activity' && _activity == null) _context = 'group';
  });

  void _selectUnit(String value) => setState(() {
    _unit = value;
    _group = _validId(null, _groups);
    _activity = _validId(null, _activities);
    if (_context == 'activity' && _activity == null) _context = 'group';
  });

  void _selectGroup(String value) => setState(() {
    _group = value;
    _activity = _validId(null, _activities);
    if (_context == 'activity' && _activity == null) _context = 'group';
  });

  static String? _validId(String? preferred, List<AttendanceContextOption> options) {
    if (preferred != null && options.any((item) => item.id == preferred)) return preferred;
    return options.firstOrNull?.id;
  }

  static String _labelFor(List<AttendanceContextOption> options, String id) =>
      options.firstWhere((item) => item.id == id).name;

  Future<void> _create() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _commandError = null;
    });
    try {
      final call = await widget.repository.createCall(
        AttendanceCallDraft(
          institutionId: _institution!,
          unitId: _unit!,
          groupId: _group!,
          activityContextId: _context == 'activity' ? _activity : null,
          date: _date,
        ),
      );
      if (!mounted) return;
      widget.onCreated(call.id);
    } catch (error) {
      if (mounted) setState(() => _commandError = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AttendanceContextFacts extends StatelessWidget {
  const _AttendanceContextFacts({required this.date, required this.today});

  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final facts = [
      _AttendanceFact(
        icon: Icons.calendar_today_outlined,
        label: 'Data',
        value: '${DateUtils.isSameDay(date, today) ? 'Hoje · ' : ''}${_attendanceDate(date)}',
      ),
      const _AttendanceFact(
        icon: Icons.people_outline,
        label: 'Participantes esperados',
        value: 'Definidos pelo contexto autorizado',
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

  final AttendanceRepository repository;
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
  AttendanceBulkReceipt? _lastBulkReceipt;

  AttendanceCall? _call;
  Object? _initialLoadError;
  Object? _commandError;
  var _loading = true;
  var _commandInFlight = false;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadCall();
  }

  @override
  void didUpdateWidget(covariant AttendanceCallPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callId == widget.callId && identical(oldWidget.repository, widget.repository)) {
      return;
    }
    for (final controller in _notes.values) {
      controller.dispose();
    }
    _notes.clear();
    _call = null;
    _lastBulkReceipt = null;
    _loading = true;
    _loadCall();
  }

  Future<void> _loadCall() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final callId = widget.callId;
    if (mounted) {
      setState(() {
        _loading = _call == null;
        _initialLoadError = null;
        _commandError = null;
      });
    }
    try {
      final call = await repository.fetchCall(callId);
      if (_isCurrentCallLoad(generation, repository, callId)) {
        setState(() {
          _call = call;
          _loading = false;
          _initialLoadError = null;
        });
      }
    } catch (error) {
      if (_isCurrentCallLoad(generation, repository, callId)) {
        setState(() {
          _initialLoadError = error;
          _loading = false;
        });
      }
    }
  }

  bool _isCurrentCallLoad(int generation, AttendanceRepository repository, String callId) =>
      mounted &&
      generation == _loadGeneration &&
      identical(repository, widget.repository) &&
      callId == widget.callId;

  @override
  void dispose() {
    _loadGeneration++;
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(
        child: const CoeloStatePanel(
          title: 'Carregando chamada',
          message: 'Buscando o registro no escopo autorizado.',
          loading: true,
        ),
      );
    }
    if (_initialLoadError != null) {
      final unauthorized = _initialLoadError is AttendanceUnauthorizedException;
      return _shell(
        child: CoeloStatePanel(
          title: unauthorized ? 'Acesso não autorizado' : 'Não foi possível carregar a chamada.',
          message: unauthorized
              ? 'Você não possui acesso a este registro.'
              : 'Confira a conexão e tente novamente.',
          icon: unauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
          actionLabel: unauthorized ? 'Voltar para Assiduidade' : 'Tentar novamente',
          onAction: unauthorized ? widget.onBack : _loadCall,
        ),
      );
    }
    final call = _call;
    if (call == null) {
      return _shell(
        child: CoeloStatePanel(
          title: 'Chamada não encontrada.',
          message: 'O registro não existe ou não está mais disponível.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Voltar para Assiduidade',
          onAction: widget.onBack,
        ),
      );
    }
    final canWrite = call.canManage && widget.permissions.canOperate(call);
    final writable = canWrite && !_commandInFlight;
    final concluded = call.status == AttendanceCallStatus.completed;
    final firstPendingRoutine = call.participants
        .where((item) => widget.routinePendingParticipantIds.contains(item.id))
        .firstOrNull;
    return SuperadminShell(
      logout: widget.logout,
      title: concluded ? 'Chamada · ${call.contextName}' : 'Lançar chamada',
      subtitle: '${call.institutionName} · ${call.unitName} · ${call.groupName}',
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
            currentIndex: 2,
            steps: const [
              SuperadminFormStep(label: 'Contexto', status: SuperadminFormStepStatus.complete),
              SuperadminFormStep(label: 'Rotina diária', status: SuperadminFormStepStatus.complete),
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
                if (_commandError != null) ...[
                  _AttendanceCommandErrorBanner(
                    message: _commandError is AttendanceVersionConflictException
                        ? 'A chamada foi atualizada em outro acesso.'
                        : 'Não foi possível salvar a alteração.',
                    actionLabel: 'Recarregar chamada',
                    onAction: _loadCall,
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                ],
                if (_commandInFlight) const LinearProgressIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('attendance-call-scroll'),
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      '${DateUtils.isSameDay(call.date, DateTime.now()) ? 'Hoje · ' : ''}'
                                      '${_attendanceDate(call.date)}',
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
                                        canUndo: _lastBulkReceipt != null,
                                        onMarkRemaining: () => _toggleBulk(call),
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
                                          final notice = participant.notice;
                                          return _ParticipantCard(
                                            participant: participant,
                                            notice: notice,
                                            focused: participant.id == widget.focusedParticipantId,
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
                                            onSave: (state) => _applyCall(
                                              () => widget.repository.setParticipantState(
                                                call.id,
                                                participant.id,
                                                state,
                                                expectedVersion: call.version,
                                              ),
                                            ),
                                            onConfirmNotice:
                                                notice != null && notice.pending && writable
                                                ? () => _applyCall(
                                                    () => widget.repository.confirmNotice(
                                                      notice.id,
                                                      expectedVersion: call.version,
                                                    ),
                                                  )
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
                if (canWrite)
                  SuperadminFormActionFooter(
                    surfaceKey: const Key('attendance-call-footer'),
                    tertiaryAction: TextButton(
                      onPressed: widget.onBack,
                      child: const Text('Voltar para Assiduidade'),
                    ),
                    continuationActions: [
                      if (concluded && call.participants.isNotEmpty)
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
                              : () => _applyCall(
                                  () => widget.repository.completeCall(
                                    call.id,
                                    expectedVersion: call.version,
                                  ),
                                ),
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
    );
  }

  Widget _shell({required Widget child}) => SuperadminShell(
    logout: widget.logout,
    title: 'Lançar chamada',
    subtitle: 'Consulte o registro autorizado da chamada.',
    currentDestination: 'attendance',
    activityController: widget.activityController,
    child: child,
  );

  Future<bool> _applyCall(Future<AttendanceCall> Function() operation) async {
    if (_commandInFlight) return false;
    setState(() {
      _commandInFlight = true;
      _commandError = null;
    });
    try {
      final updated = await operation();
      if (!mounted) return true;
      setState(() {
        _call = updated;
        _lastBulkReceipt = null;
      });
      return true;
    } catch (error) {
      if (mounted) setState(() => _commandError = error);
      return false;
    } finally {
      if (mounted) setState(() => _commandInFlight = false);
    }
  }

  Future<void> _toggleBulk(AttendanceCall call) async {
    if (_commandInFlight) return;
    setState(() {
      _commandInFlight = true;
      _commandError = null;
    });
    try {
      if (!call.hasUnmarked) {
        final receipt = _lastBulkReceipt;
        if (receipt == null) return;
        final updated = await widget.repository.undoBulk(receipt);
        if (mounted) setState(() => _call = updated);
        if (mounted) setState(() => _lastBulkReceipt = null);
        return;
      }
      final result = await widget.repository.markRemainingPresent(
        call.id,
        expectedVersion: call.version,
      );
      if (mounted) {
        setState(() {
          _call = result.call;
          _lastBulkReceipt = result.receipt;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _commandError = error);
    } finally {
      if (mounted) setState(() => _commandInFlight = false);
    }
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
            onPressed: () async {
              if (reason.text.trim().isEmpty) return;
              final succeeded = await _applyCall(
                () => widget.repository.correctParticipant(
                  callId: call.id,
                  participantId: call.participants.first.id,
                  state: state,
                  reason: reason.text.trim(),
                  expectedVersion: call.version,
                ),
              );
              if (dialogContext.mounted && succeeded) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Registrar correção'),
          ),
        ),
      ),
    );
    reason.dispose();
  }
}

class _AttendanceCommandErrorBanner extends StatelessWidget {
  const _AttendanceCommandErrorBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: colors.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(child: Text(message)),
            if (actionLabel != null && onAction != null)
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCallToolbar extends StatelessWidget {
  const _AttendanceCallToolbar({
    required this.call,
    required this.writable,
    required this.canUndo,
    required this.onMarkRemaining,
  });

  final AttendanceCall call;
  final bool writable;
  final bool canUndo;
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
        onPressed: writable && (call.hasUnmarked || canUndo) ? onMarkRemaining : null,
        icon: Icon(call.hasUnmarked ? Icons.done_all_rounded : Icons.remove_done_rounded),
        label: Text(
          call.hasUnmarked ? 'Marcar todos restantes como presentes' : 'Desfazer último lote',
        ),
      );
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      if (constraints.maxWidth < 900 || textScale >= 1.5) {
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final isNegative = state == AttendancePresenceState.absent;
    final isAttention =
        state == AttendancePresenceState.late || state == AttendancePresenceState.lateAndEarly;
    final usesSemanticTone = isNegative || isAttention;
    final semanticForeground = isNegative ? colors.error : statusColors.warning;
    final semanticContainer = isNegative ? colors.errorContainer : statusColors.warningContainer;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label para presença',
      child: OutlinedButton(
        onPressed: enabled ? () => onSelected(state) : null,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
          foregroundColor: WidgetStatePropertyAll(
            usesSemanticTone
                ? semanticForeground
                : selected
                ? colors.primary
                : colors.onSurface,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final highlighted =
                selected ||
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused);
            if (usesSemanticTone && highlighted) {
              return semanticContainer;
            }
            return highlighted ? colors.primaryContainer : colors.surface;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: usesSemanticTone
                  ? semanticForeground
                  : selected
                  ? colors.primary
                  : colors.outlineVariant,
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final label = state == AttendancePresenceState.absent ? 'Falta' : state.label;
    final (backgroundColor, foregroundColor) = switch (state) {
      AttendancePresenceState.unmarked => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      AttendancePresenceState.absent => (colors.errorContainer, colors.error),
      AttendancePresenceState.late || AttendancePresenceState.lateAndEarly => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
      ),
      AttendancePresenceState.present ||
      AttendancePresenceState.earlyDeparture => (colors.primaryContainer, colors.primary),
    };
    return Semantics(
      label: 'Estado de presença: $label',
      child: DecoratedBox(
        key: Key('attendance-status-${state.name}'),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space3,
            vertical: CoeloSpacing.space2,
          ),
          child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: foregroundColor)),
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
    required this.onSave,
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
  final Future<bool> Function(AttendancePresenceState state) onSave;
  final VoidCallback? onConfirmNotice;

  @override
  State<_ParticipantCard> createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<_ParticipantCard> {
  late bool _detailsExpanded = widget.focused;
  late bool _routineExpanded = widget.routineInitiallyExpanded;
  late AttendancePresenceState _pendingState = widget.participant.state;
  DailyRoutineFeeling? _feeling;
  bool _saving = false;

  bool get _hasPendingState => _pendingState != widget.participant.state;

  Future<void> _save() async {
    if (_saving || !_hasPendingState) return;
    setState(() => _saving = true);
    await widget.onSave(_pendingState);
    if (mounted) setState(() => _saving = false);
  }

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
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stacked = constraints.maxWidth < 900 || textScale >= 1.5;
                if (stacked) {
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
            const SizedBox(height: CoeloSpacing.space3),
            Text('Sentimento (demonstração local)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: CoeloSpacing.space1),
            DailyRoutineFeelingPicker(
              keyPrefix: 'attendance-feeling-${widget.participant.id}',
              value: _feeling,
              enabled: widget.writable && !_saving,
              onChanged: (value) => setState(() => _feeling = value),
              onSuggestFeeling: () async {
                if (context.mounted) {
                  showSuperadminNotice(context, 'Indisponível nesta etapa');
                }
              },
            ),
            Text(
              'Não persistido nesta etapa.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (_hasPendingState) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Alteração de presença não salva.',
                key: Key('attendance-participant-pending-${widget.participant.id}'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.primary),
              ),
            ],
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
      key: Key('attendance-participant-identity-${widget.participant.id}'),
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
    key: Key('attendance-participant-actions-${widget.participant.id}'),
    alignment: WrapAlignment.end,
    spacing: CoeloSpacing.space2,
    runSpacing: CoeloSpacing.space2,
    children: [
      _AttendanceStateButton(
        label: 'Presente',
        state: AttendancePresenceState.present,
        selected: _pendingState == AttendancePresenceState.present,
        enabled: widget.writable && !_saving,
        onSelected: (state) => setState(() => _pendingState = state),
      ),
      _AttendanceStateButton(
        label: 'Falta',
        state: AttendancePresenceState.absent,
        selected: _pendingState == AttendancePresenceState.absent,
        enabled: widget.writable && !_saving,
        onSelected: (state) => setState(() => _pendingState = state),
      ),
      _AttendanceStateButton(
        label: 'Atraso',
        state: AttendancePresenceState.late,
        selected: _pendingState == AttendancePresenceState.late,
        enabled: widget.writable && !_saving,
        onSelected: (state) => setState(() => _pendingState = state),
      ),
      _AttendanceStateButton(
        label: 'Saída antecipada',
        state: AttendancePresenceState.earlyDeparture,
        selected: _pendingState == AttendancePresenceState.earlyDeparture,
        enabled: widget.writable && !_saving,
        onSelected: (state) => setState(() => _pendingState = state),
      ),
      _AttendanceStateButton(
        label: 'Atraso + sa\u00edda',
        state: AttendancePresenceState.lateAndEarly,
        selected: _pendingState == AttendancePresenceState.lateAndEarly,
        enabled: widget.writable && !_saving,
        onSelected: (state) => setState(() => _pendingState = state),
      ),
      FilledButton.icon(
        key: Key('attendance-participant-save-${widget.participant.id}'),
        onPressed: widget.writable && _hasPendingState && !_saving ? _save : null,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Salvando...' : 'Salvar'),
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
    AttendancePresenceState.lateAndEarly => 'Atraso + saída',
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
