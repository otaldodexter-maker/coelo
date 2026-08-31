import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../auth/domain/logout_action.dart';
import 'assessment.dart';
import 'assessment_controller.dart';

const _entrySteps = ['Contexto', 'Notas e competências', 'Comentários', 'Revisão e envio'];
const _configurationSteps = [
  'Escopo e período',
  'Escala e instrumentos',
  'Categorias e competências',
  'Revisão e ativação',
];

final class AssessmentEntryPage extends StatefulWidget {
  const AssessmentEntryPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    this.gradebookId,
    this.onSubmitted,
    this.onDestinationSelected,
    super.key,
  });
  final AssessmentRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final String? gradebookId;
  final ValueChanged<AssessmentGradebook>? onSubmitted;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<AssessmentEntryPage> createState() => _AssessmentEntryPageState();
}

final class _AssessmentEntryPageState extends State<AssessmentEntryPage> {
  late AssessmentController _controller;
  late final SuperadminActivityController _activities;
  AssessmentContextOptions? _options;
  Object? _contextError;
  AssessmentContext? _selectedContext;
  AssessmentPeriodOption? _selectedPeriod;
  bool _configurationMissing = false;
  final _studentSearch = TextEditingController();
  AssessmentStudentState? _studentStateFilter;
  bool _batch = true;
  double _footerHeight = 0;
  int _pageGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = AssessmentController(widget.repository);
    _activities = SuperadminActivityController();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AssessmentEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.gradebookId == widget.gradebookId) {
      return;
    }
    _pageGeneration++;
    _controller.dispose();
    _controller = AssessmentController(widget.repository);
    _clearLocalState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _pageGeneration++;
    _controller.dispose();
    _activities.dispose();
    _studentSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_pageGeneration;
    final controller = _controller;
    final repository = widget.repository;
    final gradebookId = widget.gradebookId;
    if (gradebookId case final id?) {
      await controller.loadGradebook(id);
      if (!_isCurrent(generation, controller, repository, gradebookId)) return;
      if (controller.recoveredDraft) {
        controller.goToStep(1);
      }
      return;
    }
    if (mounted) {
      setState(() => _contextError = null);
    }
    try {
      final options = await repository.fetchContextOptions();
      if (!_isCurrent(generation, controller, repository, gradebookId)) return;
      setState(() {
        _contextError = null;
        _options = options;
        _selectedContext = options.assignments.firstOrNull;
        _selectedPeriod =
            options.periods.where((item) => item.isOpen).firstOrNull ?? options.periods.firstOrNull;
      });
    } on AssessmentUnauthorizedException {
      if (_isCurrent(generation, controller, repository, gradebookId)) {
        setState(() => _contextError = const AssessmentUnauthorizedException());
      }
    } on Exception catch (error) {
      if (_isCurrent(generation, controller, repository, gradebookId)) {
        setState(() => _contextError = error);
      }
    }
  }

  Future<void> _start() async {
    final selected = _selectedContext, period = _selectedPeriod;
    if (selected == null || period == null) {
      return;
    }
    final generation = _pageGeneration;
    final controller = _controller;
    final repository = widget.repository;
    final gradebookId = widget.gradebookId;
    final config = await repository.fetchConfiguration(
      selected.activityId,
      unitId: selected.unitId,
    );
    if (!mounted) return;
    if (!_isCurrent(generation, controller, repository, gradebookId)) return;
    if (config == null) {
      setState(() => _configurationMissing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Instituição ou Unidade precisa configurar esta Atividade antes do lançamento.',
          ),
        ),
      );
      return;
    }
    setState(() => _configurationMissing = false);
    await controller.start(
      AssessmentContext(
        activityGroupLinkId: selected.activityGroupLinkId,
        institutionId: selected.institutionId,
        institutionName: selected.institutionName,
        unitId: selected.unitId,
        unitName: selected.unitName,
        groupId: selected.groupId,
        groupName: selected.groupName,
        activityId: selected.activityId,
        activityName: selected.activityName,
        periodId: period.id,
        periodName: period.name,
      ),
      config,
    );
    if (!_isCurrent(generation, controller, repository, gradebookId)) return;
    if (controller.gradebook != null) {
      controller.goToStep(1);
    }
  }

  Future<void> _reloadCurrent() async {
    if (widget.gradebookId case final id?) {
      await _controller.loadGradebook(id);
      return;
    }
    await _load();
  }

  Future<void> _primary(bool compact) async {
    final generation = _pageGeneration;
    final controller = _controller;
    final repository = widget.repository;
    final gradebookId = widget.gradebookId;
    try {
      if (controller.gradebook == null) {
        await _start();
        return;
      }
      if (controller.step == 3) {
        final saved = await controller.submit();
        if (!mounted) return;
        if (_isCurrent(generation, controller, repository, gradebookId)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Período enviado para fechamento.')));
          widget.onSubmitted?.call(saved);
        }
        return;
      }
      if (compact && controller.step == 1) {
        await controller.saveDraft();
        if (_isCurrent(generation, controller, repository, gradebookId)) {
          controller.nextStudent();
        }
        return;
      }
      controller.nextStep();
    } on Exception {
      // The controller exposes conflict, authorization, offline and failure states.
    }
  }

  bool _isCurrent(
    int generation,
    AssessmentController controller,
    AssessmentRepository repository,
    String? gradebookId,
  ) =>
      mounted &&
      generation == _pageGeneration &&
      identical(controller, _controller) &&
      identical(repository, widget.repository) &&
      gradebookId == widget.gradebookId;

  void _clearLocalState() {
    _options = null;
    _contextError = null;
    _selectedContext = null;
    _selectedPeriod = null;
    _configurationMissing = false;
    _studentSearch.clear();
    _studentStateFilter = null;
    _batch = true;
    _footerHeight = 0;
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activities,
    title: 'Lançar avaliações',
    subtitle: 'Registre resultados e acompanhe as pendências da turma.',
    currentDestination: 'assessments',
    onDestinationSelected: widget.onDestinationSelected,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: AnimatedBuilder(animation: _controller, builder: (context, _) => _body()),
  );
  Widget _body() {
    final state = _controller.state;
    if (state is AssessmentLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is AssessmentUnauthorized) {
      return const CoeloStatePanel(
        title: 'Acesso negado',
        message: 'Você não possui atribuição ativa para este diário.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (state is AssessmentConflict) {
      return CoeloStatePanel(
        title: 'Conflito de versão',
        message: 'Outra pessoa alterou este diário. Recarregue antes de continuar.',
        icon: Icons.sync_problem_rounded,
        actionLabel: 'Recarregar',
        onAction: _reloadCurrent,
      );
    }
    if (state is AssessmentOffline) {
      return CoeloStatePanel(
        title: 'Você está offline',
        message: 'A edição desta sessão foi mantida. Reconecte e tente salvar novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: state.gradebook == null ? _reloadCurrent : _retryOfflineSave,
      );
    }
    if (state is AssessmentFailure) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Verifique sua conexão e tente novamente.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    if (state is AssessmentEmpty) {
      return const CoeloStatePanel(
        title: 'Diário não encontrado',
        message: 'O vínculo pode ter sido revogado ou o diário não está disponível.',
        icon: Icons.search_off_rounded,
      );
    }
    if (widget.gradebookId == null && _contextError is AssessmentUnauthorizedException) {
      return const CoeloStatePanel(
        title: 'Acesso negado',
        message: 'Você não possui atribuição ativa para lançar avaliações.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (widget.gradebookId == null && _contextError != null) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Verifique sua conexão e tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    if (widget.gradebookId == null && _options == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < CoeloBreakpoints.medium.minWidth;
    return SuperadminFormFrame(
      viewportWidth: width,
      navigation: _navigation(),
      scrollKey: const Key('assessment-entry-scroll'),
      body: _stepBody(compact),
      footer: _footer(compact),
    );
  }

  Future<void> _retryOfflineSave() async {
    try {
      await _controller.saveDraft();
    } on AssessmentOfflineException {
      // The controller keeps the in-memory draft and the offline state visible.
    } on AssessmentUnauthorizedException {
      // The controller exposes the revoked-access state.
    } on AssessmentVersionConflictException {
      // The controller exposes the conflict state and its reload action.
    }
  }

  Widget _navigation() => SuperadminFormStepNavigation(
    steps: [
      for (var index = 0; index < _entrySteps.length; index++)
        SuperadminFormStep(
          label: _entrySteps[index],
          status: index == _controller.step
              ? SuperadminFormStepStatus.current
              : index < _controller.step
              ? SuperadminFormStepStatus.complete
              : SuperadminFormStepStatus.incomplete,
          enabled: index <= _controller.step || _controller.gradebook != null,
        ),
    ],
    currentIndex: _controller.step,
    onStepSelected: _controller.goToStep,
  );
  Widget _stepBody(bool compact) => switch (_controller.step) {
    0 => _contextStep(),
    1 => _gradesStep(compact),
    2 => _commentsStep(),
    _ => _reviewStep(),
  };
  Widget _contextStep() {
    final options = _options;
    if (options == null) return const Center(child: CircularProgressIndicator());
    if (options.isEmpty) {
      return const CoeloStatePanel(
        title: 'Sem atribuições',
        message: 'Não há Atividades atribuídas ao seu vínculo profissional.',
        icon: Icons.assignment_ind_outlined,
      );
    }
    final assignments = options.assignments;
    final periods = options.periods
        .where(
          (item) =>
              _selectedContext == null ||
              ((item.institutionId == null ||
                      item.institutionId == _selectedContext!.institutionId) &&
                  (item.unitId == null || item.unitId == _selectedContext!.unitId)),
        )
        .toList();
    return _AssessmentSection(
      title: 'Contexto do lançamento',
      description: 'Somente Atividades e períodos autorizados são exibidos.',
      child: Column(
        children: [
          CoeloAdminSingleSelectField<AssessmentContext>(
            label: 'Instituição, unidade, turma e Atividade',
            value: _selectedContext!,
            options: assignments,
            optionLabel: (item) =>
                '${item.institutionName} · ${item.unitName} · ${item.groupName} · ${item.activityName}',
            onChanged: (value) => setState(() {
              _selectedContext = value;
              _configurationMissing = false;
              final matchingPeriods = options.periods
                  .where(
                    (period) =>
                        (period.institutionId == null ||
                            period.institutionId == value.institutionId) &&
                        (period.unitId == null || period.unitId == value.unitId),
                  )
                  .toList();
              _selectedPeriod =
                  matchingPeriods.where((period) => period.isOpen).firstOrNull ??
                  matchingPeriods.firstOrNull;
            }),
            prefixIcon: Icons.school_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (periods.isNotEmpty)
            CoeloAdminSingleSelectField<AssessmentPeriodOption>(
              label: 'Período avaliativo',
              value: periods.contains(_selectedPeriod) ? _selectedPeriod! : periods.first,
              options: periods,
              optionLabel: (item) => item.name,
              onChanged: (value) => setState(() => _selectedPeriod = value),
              prefixIcon: Icons.calendar_month_outlined,
            ),
          if (periods.isEmpty) ...[
            const SizedBox(height: CoeloSpacing.space4),
            const CoeloStatePanel(
              title: 'Nenhum período avaliativo',
              message: 'A Instituição ou Unidade precisa abrir um período para lançamento.',
              icon: Icons.event_busy_outlined,
            ),
          ],
          if (_configurationMissing) ...[
            const SizedBox(height: CoeloSpacing.space4),
            const CoeloStatePanel(
              title: 'Atividade sem configuração avaliativa',
              message:
                  'A Instituição ou Unidade precisa configurá-la. O professor não pode improvisar uma escala.',
              icon: Icons.rule_folder_outlined,
            ),
          ],
          if (_selectedPeriod?.isOpen == false) ...[
            const SizedBox(height: CoeloSpacing.space4),
            const CoeloStatePanel(
              title: 'Período fechado',
              message: 'Este período não aceita novos lançamentos.',
              icon: Icons.event_busy_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradesStep(bool compact) {
    final book = _controller.gradebook;
    if (book == null) {
      return const CoeloStatePanel(
        title: 'Selecione o contexto',
        message: 'Escolha Atividade, turma e período para iniciar.',
        icon: Icons.tune_rounded,
      );
    }
    if (book.configuration == null) {
      return const CoeloStatePanel(
        title: 'Atividade sem configuração avaliativa',
        message:
            'A Instituição ou Unidade precisa configurá-la. O professor não pode improvisar uma escala.',
        icon: Icons.rule_folder_outlined,
      );
    }
    if (book.students.isEmpty) {
      return const CoeloStatePanel(
        title: 'Turma sem alunos',
        message: 'Não há alunos ativos neste contexto.',
        icon: Icons.group_off_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progress(book),
        const SizedBox(height: CoeloSpacing.space4),
        if (!compact) _modeToolbar(),
        if (!compact && _batch) ...[
          const SizedBox(height: CoeloSpacing.space4),
          _batchTable(book),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        _studentDetail(book, compact),
      ],
    );
  }

  Widget _modeToolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final controlWidth = stacked
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space3 * 2) / 3;
      return CoeloAdminListingToolbar(
        search: SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            children: [
              SizedBox(
                width: controlWidth,
                height: CoeloSize.touchMin,
                child: CoeloSearchField(
                  key: const Key('assessment-student-search'),
                  controller: _studentSearch,
                  semanticLabel: 'Buscar aluno',
                  hintText: 'Buscar aluno',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: controlWidth,
                child: CoeloAdminSingleSelectField<AssessmentStudentState?>(
                  label: 'Situação',
                  value: _studentStateFilter,
                  options: const [null, ...AssessmentStudentState.values],
                  optionLabel: (state) => state == null ? 'Todas' : _studentStateLabel(state),
                  onChanged: (state) => setState(() => _studentStateFilter = state),
                ),
              ),
              SizedBox(
                width: controlWidth,
                child: CoeloAdminSingleSelectField<bool>(
                  label: 'Modo de lançamento',
                  value: _batch,
                  options: const [true, false],
                  optionLabel: (batch) => batch ? 'Lote' : 'Por aluno',
                  prefixIcon: _batch ? Icons.table_rows_outlined : Icons.person_outline_rounded,
                  onChanged: (batch) => setState(() => _batch = batch),
                ),
              ),
            ],
          ),
        ),
        filters: const [],
        actions: const [],
      );
    },
  );
  Widget _progress(AssessmentGradebook book) => Semantics(
    label: '${book.resolvedCount} de ${book.students.length} alunos preenchidos',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${book.resolvedCount} de ${book.students.length} alunos preenchidos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        LinearProgressIndicator(
          value: book.students.isEmpty ? 0 : book.resolvedCount / book.students.length,
        ),
      ],
    ),
  );
  Widget _batchTable(AssessmentGradebook book) => CoeloAdminResizableTable<AssessmentStudentEntry>(
    key: const Key('assessment-batch-table'),
    items: book.students.where((student) {
      final query = _studentSearch.text.trim().toLowerCase();
      return (query.isEmpty || student.name.toLowerCase().contains(query)) &&
          (_studentStateFilter == null || student.state == _studentStateFilter);
    }).toList(),
    rowKey: (student) => student.id,
    onRowPressed: (student) {
      final index = book.students.indexOf(student);
      while (_controller.selectedStudentIndex < index) {
        _controller.nextStudent();
      }
      while (_controller.selectedStudentIndex > index) {
        _controller.previousStudent();
      }
    },
    isSelected: (student) => student.id == _controller.selectedStudent?.id,
    pinnedColumn: CoeloAdminTableColumn(
      id: 'student',
      label: 'Aluno',
      initialWidth: 220,
      minWidth: 160,
      maxWidth: 360,
      cellBuilder: (_, student) => Text(student.name),
    ),
    columns: [
      for (final instrument in book.configuration!.instruments)
        CoeloAdminTableColumn(
          id: instrument.id,
          label: '${instrument.name} ${instrument.weight.toStringAsFixed(0)}%',
          initialWidth: 160,
          minWidth: 140,
          maxWidth: 220,
          cellBuilder: (_, student) => Text(_instrumentValue(student, instrument.id)),
        ),
      CoeloAdminTableColumn(
        id: 'average',
        label: 'Média sugerida',
        initialWidth: 160,
        minWidth: 140,
        maxWidth: 220,
        cellBuilder: (_, student) => Text(student.suggestedScore?.toStringAsFixed(2) ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'competencies',
        label: 'Competências',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 280,
        cellBuilder: (_, student) =>
            Text(student.competencies.isEmpty ? '—' : '${student.competencies.length} preenchidas'),
      ),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Situação',
        initialWidth: 160,
        minWidth: 140,
        maxWidth: 220,
        cellBuilder: (_, student) => _statusChip(student.state),
      ),
    ],
    headerHeight: 56,
    rowHeight: 64,
  );
  String _instrumentValue(AssessmentStudentEntry student, String id) {
    final value = student.instruments.where((item) => item.instrumentId == id).firstOrNull;
    if (value == null) {
      return '—';
    }
    if (value.absent) {
      return 'Ausente';
    }
    return value.numericValue?.toStringAsFixed(1) ??
        value.conceptCode ??
        (value.booleanValue == null
            ? '—'
            : value.booleanValue!
            ? 'Sim'
            : 'Não');
  }

  Widget _studentDetail(AssessmentGradebook book, bool compact) {
    final student = _controller.selectedStudent!;
    return _AssessmentSection(
      key: const Key('assessment-student-detail'),
      title: compact ? 'Lançamento individual' : student.name,
      description: compact
          ? '${book.context.groupName} · ${book.context.activityName}'
          : '${_controller.selectedStudentIndex + 1} de ${book.students.length}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Aluno anterior',
            onPressed: _controller.selectedStudentIndex == 0 ? null : _controller.previousStudent,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          IconButton(
            tooltip: 'Próximo aluno',
            onPressed: _controller.selectedStudentIndex == book.students.length - 1
                ? null
                : _controller.nextStudent,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            Row(
              children: [
                CoeloAvatar(
                  semanticLabel: 'Foto de ${student.name}',
                  initials: _initials(student.name),
                  size: CoeloAvatarSize.large,
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${_controller.selectedStudentIndex + 1} de ${book.students.length}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          CoeloAdminSingleSelectField<AssessmentStudentState>(
            label: 'Situação do aluno',
            value: student.state,
            options: AssessmentStudentState.values,
            optionLabel: _studentStateLabel,
            prefixIcon: Icons.fact_check_outlined,
            onChanged: (state) => _controller.updateStudent(student.copyWith(state: state)),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          for (final instrument in book.configuration!.instruments) ...[
            _ScoreField(
              key: ValueKey('${student.id}-${instrument.id}'),
              instrument: instrument,
              configuration: book.configuration!,
              value: student.instruments
                  .where((item) => item.instrumentId == instrument.id)
                  .firstOrNull,
              onChanged: (value) {
                final entries = [
                  ...student.instruments.where((item) => item.instrumentId != instrument.id),
                  value,
                ];
                _controller.updateStudent(
                  student.copyWith(instruments: entries, state: AssessmentStudentState.pending),
                );
              },
            ),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          Text(
            'Média sugerida: ${student.suggestedScore?.toStringAsFixed(2) ?? '—'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (book.configuration!.scaleKind == AssessmentScaleKind.concept)
            CoeloAdminSingleSelectField<String?>(
              label: 'Resultado final',
              value: student.finalConceptCode,
              options: [null, ...book.configuration!.concepts],
              optionLabel: (value) => value ?? 'Não informado',
              prefixIcon: Icons.verified_outlined,
              onChanged: (value) => _controller.updateStudent(
                student.copyWith(finalConceptCode: value, clearFinalConceptCode: value == null),
              ),
            )
          else if (book.configuration!.scaleKind == AssessmentScaleKind.binary)
            CoeloAdminSingleSelectField<bool?>(
              label: 'Resultado final',
              value: student.finalBooleanValue,
              options: const [null, true, false],
              optionLabel: (value) => value == null
                  ? 'Não informado'
                  : value
                  ? 'Sim'
                  : 'Não',
              prefixIcon: Icons.verified_outlined,
              onChanged: (value) => _controller.updateStudent(
                student.copyWith(finalBooleanValue: value, clearFinalBooleanValue: value == null),
              ),
            )
          else if (book.configuration!.allowFinalOverride)
            _NumericOverrideEditor(
              key: ValueKey('override-${student.id}'),
              student: student,
              onChanged: _controller.updateStudent,
            ),
          if (book.configuration!.competencies.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space4),
            Text('Competências', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            for (final competency in book.configuration!.competencies) ...[
              CoeloAdminSingleSelectField<int>(
                label: competency.name,
                value:
                    (student.competencies
                                .where((item) => item.competencyId == competency.id)
                                .firstOrNull
                                ?.score ??
                            1)
                        .round()
                        .clamp(1, 5),
                options: const [1, 2, 3, 4, 5],
                optionLabel: (score) => '$score de 5',
                prefixIcon: Icons.psychology_alt_outlined,
                onChanged: (score) {
                  final entries = [
                    ...student.competencies.where((item) => item.competencyId != competency.id),
                    AssessmentCompetencyEntry(competencyId: competency.id, score: score.toDouble()),
                  ];
                  _controller.updateStudent(
                    student.copyWith(competencies: entries, state: AssessmentStudentState.pending),
                  );
                },
              ),
              const SizedBox(height: CoeloSpacing.space2),
            ],
          ],
        ],
      ),
    );
  }

  Widget _commentsStep() {
    final book = _controller.gradebook;
    if (book == null || book.students.isEmpty) {
      return const CoeloStatePanel(
        title: 'Nenhum aluno',
        message: 'Selecione um contexto com alunos.',
        icon: Icons.group_off_outlined,
      );
    }
    return _CommentsEditor(
      key: ValueKey(_controller.selectedStudent!.id),
      student: _controller.selectedStudent!,
      position: _controller.selectedStudentIndex + 1,
      total: book.students.length,
      onPrevious: _controller.previousStudent,
      onNext: _controller.nextStudent,
      onChanged: _controller.updateStudent,
    );
  }

  Widget _reviewStep() {
    final book = _controller.gradebook;
    if (book == null) {
      return const SizedBox.shrink();
    }
    final pending = book.students.length - book.resolvedCount;
    return _AssessmentSection(
      title: 'Revisão e envio',
      description: 'Envio para fechamento não publica para a família.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReviewFact(
            label: 'Contexto',
            value:
                '${book.context.institutionName} · ${book.context.unitName} · ${book.context.groupName}',
          ),
          _ReviewFact(
            label: 'Atividade e período',
            value: '${book.context.activityName} · ${book.context.periodName}',
          ),
          _ReviewFact(
            label: 'Progresso',
            value: '${book.resolvedCount} concluídos · $pending pendentes',
          ),
          if (pending > 0) ...[
            const SizedBox(height: CoeloSpacing.space4),
            const CoeloStatePanel(
              title: 'Envio parcialmente preenchido',
              message:
                  'As pendências seguirão para a fila administrativa e poderão ser completadas pelo revisor ou devolvidas.',
              icon: Icons.pending_actions_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(bool compact) {
    final book = _controller.gradebook;
    final finalStep = _controller.step == 3;
    final primaryLabel = finalStep
        ? 'Enviar para fechamento'
        : compact && _controller.step == 1 && book != null
        ? 'Salvar e próximo aluno'
        : 'Continuar';
    return SuperadminFormActionFooter(
      surfaceKey: const Key('assessment-entry-footer'),
      onHeightChanged: (height) {
        if ((_footerHeight - height).abs() > .5) setState(() => _footerHeight = height);
      },
      tertiaryAction: TextButton(
        onPressed: _controller.saving
            ? null
            : _controller.step == 3
            ? _controller.previousStep
            : widget.onCancel,
        child: Text(_controller.step == 3 ? 'Voltar' : 'Cancelar'),
      ),
      continuationActions: [
        if (book != null)
          OutlinedButton(
            onPressed: _controller.saving ? null : () => _controller.saveDraft(),
            child: const Text('Salvar rascunho'),
          ),
        FilledButton(
          onPressed:
              _controller.saving ||
                  (_controller.step == 0 && (_selectedPeriod == null || !_selectedPeriod!.isOpen))
              ? null
              : () => _primary(compact),
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}

final class AssessmentConfigurationPage extends StatelessWidget {
  const AssessmentConfigurationPage({
    required this.repository,
    required this.logout,
    required this.activityId,
    required this.institutionId,
    required this.onCancel,
    this.unitId,
    this.onDestinationSelected,
    super.key,
  });

  final AssessmentRepository repository;
  final LogoutAction logout;
  final String activityId, institutionId;
  final String? unitId;
  final VoidCallback onCancel;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) => _LegacyAssessmentConfigurationPrototype(
    repository: repository,
    logout: logout,
    activityId: activityId,
    institutionId: institutionId,
    unitId: unitId,
    onCancel: onCancel,
    onDestinationSelected: onDestinationSelected,
    key: key,
  );
}

final class _LegacyAssessmentConfigurationPrototype extends StatefulWidget {
  const _LegacyAssessmentConfigurationPrototype({
    required this.repository,
    required this.logout,
    required this.activityId,
    required this.institutionId,
    required this.onCancel,
    required this.unitId,
    required this.onDestinationSelected,
    super.key,
  });
  final AssessmentRepository repository;
  final LogoutAction logout;
  final String activityId, institutionId;
  final String? unitId;
  final VoidCallback onCancel;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<_LegacyAssessmentConfigurationPrototype> createState() =>
      _LegacyAssessmentConfigurationPrototypeState();
}

final class _LegacyAssessmentConfigurationPrototypeState
    extends State<_LegacyAssessmentConfigurationPrototype> {
  int _step = 0;
  AssessmentConfiguration? _configuration;
  List<AssessmentCompetency> _competencyOptions = const [];
  Object? _error;
  bool _loading = true, _saving = false;
  double _footerHeight = 0;

  bool get _canActivate {
    final value = _configuration;
    return value != null &&
        value.instruments.isNotEmpty &&
        value.instruments.every((item) => item.name.trim().isNotEmpty && item.weight > 0) &&
        (value.totalWeight - 100).abs() < .0001 &&
        value.periods.isNotEmpty &&
        value.periods.every(
          (period) =>
              period.name.trim().isNotEmpty &&
              !period.endsOn.isBefore(period.startsOn) &&
              !period.familyReleaseAt.isBefore(period.entryClosesAt),
        ) &&
        (value.scaleKind != AssessmentScaleKind.concept || value.concepts.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await widget.repository.fetchConfiguration(
        widget.activityId,
        unitId: widget.unitId,
      );
      if (mounted) {
        setState(() {
          _competencyOptions = value?.availableCompetencies ?? value?.competencies ?? const [];
          _configuration =
              value ??
              AssessmentConfiguration(
                id: '',
                activityId: widget.activityId,
                institutionId: widget.institutionId,
                unitId: widget.unitId,
                periodicity: 'bimonthly',
                scaleKind: AssessmentScaleKind.numeric0To10,
                version: 0,
                status: 'draft',
                instruments: const [],
                competencies: const [],
              );
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save({bool activate = false}) async {
    final value = _configuration;
    if (value == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      var saved = await widget.repository.saveConfiguration(value);
      if (activate) saved = await widget.repository.activateConfiguration(saved);
      if (mounted) {
        setState(() => _configuration = saved);
      }
    } on AssessmentVersionConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A configuração foi alterada. Recarregue e revise.')),
        );
      }
    } on AssessmentUnauthorizedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você não tem permissão para configurar avaliações.')),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível salvar. Tente novamente.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Configuração avaliativa',
    subtitle: 'Defina a configuração vigente da Atividade.',
    currentDestination: 'activities',
    onDestinationSelected: widget.onDestinationSelected,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _configuration == null
        ? CoeloStatePanel(
            title: _error is AssessmentUnauthorizedException
                ? 'Acesso negado'
                : 'Não foi possível carregar',
            message: _error is AssessmentUnauthorizedException
                ? 'Você não possui a permissão assessments.configure.'
                : 'Verifique sua conexão e tente novamente.',
            icon: _error is AssessmentUnauthorizedException
                ? Icons.lock_outline_rounded
                : Icons.cloud_off_outlined,
            actionLabel: _error is AssessmentUnauthorizedException ? null : 'Tentar novamente',
            onAction: _error is AssessmentUnauthorizedException ? null : _load,
          )
        : SuperadminFormFrame(
            viewportWidth: MediaQuery.sizeOf(context).width,
            navigation: SuperadminFormStepNavigation(
              steps: [
                for (var index = 0; index < _configurationSteps.length; index++)
                  SuperadminFormStep(
                    label: _configurationSteps[index],
                    status: index == _step
                        ? SuperadminFormStepStatus.current
                        : index < _step
                        ? SuperadminFormStepStatus.complete
                        : SuperadminFormStepStatus.incomplete,
                  ),
              ],
              currentIndex: _step,
              onStepSelected: (value) => setState(() => _step = value),
            ),
            body: _body(),
            footer: SuperadminFormActionFooter(
              surfaceKey: const Key('assessment-configuration-footer'),
              onHeightChanged: (height) {
                if ((_footerHeight - height).abs() > .5) setState(() => _footerHeight = height);
              },
              tertiaryAction: TextButton(
                onPressed: _saving
                    ? null
                    : _step == 0
                    ? widget.onCancel
                    : () => setState(() => _step--),
                child: Text(_step == 0 ? 'Cancelar' : 'Voltar'),
              ),
              continuationActions: [
                OutlinedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar rascunho'),
                ),
                FilledButton(
                  onPressed: _saving || (_step == 3 && !_canActivate)
                      ? null
                      : () {
                          if (_step < 3) {
                            setState(() => _step++);
                          } else {
                            _save(activate: true);
                          }
                        },
                  child: Text(_step == 3 ? 'Ativar configuração' : 'Continuar'),
                ),
              ],
            ),
          ),
  );
  Widget _body() {
    final value = _configuration!;
    return switch (_step) {
      0 => _AssessmentSection(
        title: 'Escopo e período',
        description: 'A configuração da unidade prevalece sobre o padrão institucional.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReviewFact(label: 'Atividade', value: value.activityId),
            _ReviewFact(label: 'Escopo', value: value.unitId == null ? 'Instituição' : 'Unidade'),
            CoeloAdminSingleSelectField<String>(
              label: 'Periodicidade',
              value: value.periodicity,
              options: const ['bimonthly', 'trimester', 'semester', 'annual'],
              optionLabel: (item) => switch (item) {
                'bimonthly' => 'Bimestral',
                'trimester' => 'Trimestral',
                'semester' => 'Semestral',
                _ => 'Anual',
              },
              onChanged: (periodicity) =>
                  setState(() => _configuration = value.copyWith(periodicity: periodicity)),
            ),
            const SizedBox(height: CoeloSpacing.space5),
            for (var index = 0; index < value.periods.length; index++) ...[
              _ConfiguredPeriodEditor(
                key: ValueKey('assessment-period-$index-${value.periods[index].id}'),
                period: value.periods[index],
                onChanged: (period) {
                  final periods = [...value.periods]..[index] = period;
                  setState(() => _configuration = value.copyWith(periods: periods));
                },
                onRemove: () {
                  final periods = [...value.periods]..removeAt(index);
                  setState(() => _configuration = value.copyWith(periods: periods));
                },
              ),
              const SizedBox(height: CoeloSpacing.space4),
            ],
            OutlinedButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final date = DateTime(now.year, now.month, now.day);
                final deadline = DateTime(now.year, now.month, now.day, 23, 59);
                final periods = [
                  ...value.periods,
                  AssessmentConfiguredPeriod(
                    id: '',
                    name: '',
                    ordinal: value.periods.length + 1,
                    academicYear: now.year,
                    startsOn: date,
                    endsOn: date,
                    entryClosesAt: deadline,
                    familyReleaseAt: deadline,
                  ),
                ];
                setState(() => _configuration = value.copyWith(periods: periods));
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar período'),
            ),
            if (value.periods.isEmpty)
              const CoeloStatePanel(
                title: 'Nenhum período avaliativo',
                message: 'Adicione pelo menos um período antes de ativar.',
                icon: Icons.calendar_month_outlined,
              ),
          ],
        ),
      ),
      1 => _AssessmentSection(
        title: 'Escala e instrumentos',
        description: 'Os pesos devem totalizar 100%.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloAdminSingleSelectField<AssessmentScaleKind>(
              label: 'Escala',
              value: value.scaleKind,
              options: AssessmentScaleKind.values,
              optionLabel: _scaleLabel,
              onChanged: (scale) =>
                  setState(() => _configuration = value.copyWith(scaleKind: scale)),
            ),
            if (value.scaleKind == AssessmentScaleKind.concept) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _ConceptOptionsEditor(
                key: ValueKey('assessment-concepts-${value.id}'),
                concepts: value.concepts,
                onChanged: (concepts) =>
                    setState(() => _configuration = value.copyWith(concepts: concepts)),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            for (var index = 0; index < value.instruments.length; index++) ...[
              _InstrumentConfigurationEditor(
                key: ValueKey('assessment-instrument-$index-${value.instruments[index].id}'),
                instrument: value.instruments[index],
                onChanged: (instrument) {
                  final instruments = [...value.instruments]..[index] = instrument;
                  setState(() => _configuration = value.copyWith(instruments: instruments));
                },
                onRemove: () {
                  final instruments = [...value.instruments]..removeAt(index);
                  setState(() => _configuration = value.copyWith(instruments: instruments));
                },
              ),
              const SizedBox(height: CoeloSpacing.space3),
            ],
            OutlinedButton.icon(
              onPressed: () {
                final instruments = [
                  ...value.instruments,
                  AssessmentInstrument(
                    id: '',
                    name: '',
                    weight: 0,
                    sortOrder: value.instruments.length,
                  ),
                ];
                setState(() => _configuration = value.copyWith(instruments: instruments));
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar instrumento'),
            ),
            if (value.instruments.isEmpty)
              const CoeloStatePanel(
                title: 'Nenhum instrumento',
                message: 'Adicione instrumentos e pesos antes de ativar.',
                icon: Icons.playlist_add_outlined,
              ),
          ],
        ),
      ),
      2 => _AssessmentSection(
        title: 'Categorias e competências',
        description: 'A taxonomia permanece limitada ao contexto institucional.',
        child: _competencyOptions.isEmpty
            ? const CoeloStatePanel(
                title: 'Nenhuma competência',
                message:
                    'A Instituição ou Unidade precisa cadastrar a taxonomia antes da ativação.',
                icon: Icons.psychology_alt_outlined,
              )
            : CoeloAdminMultiSelectField<AssessmentCompetency>(
                label: 'Competências avaliadas',
                options: _competencyOptions,
                selectedValues: value.competencies.toSet(),
                optionLabel: (competency) => '${competency.category} · ${competency.name}',
                onChanged: (selected) => setState(
                  () => _configuration = value.copyWith(competencies: selected.toList()),
                ),
              ),
      ),
      _ => _AssessmentSection(
        title: 'Revisão e ativação',
        description: 'Depois de ativa, esta versão não poderá ser alterada.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReviewFact(label: 'Periodicidade', value: value.periodicity),
            _ReviewFact(label: 'Escala', value: _scaleLabel(value.scaleKind)),
            _ReviewFact(
              label: 'Instrumentos',
              value: '${value.instruments.length} · ${value.totalWeight.toStringAsFixed(0)}%',
            ),
            _ReviewFact(label: 'Competências', value: '${value.competencies.length}'),
            if (value.totalWeight != 100)
              const CoeloStatePanel(
                title: 'Pesos incompletos',
                message: 'A soma dos instrumentos precisa ser 100%.',
                icon: Icons.warning_amber_rounded,
              ),
          ],
        ),
      ),
    };
  }
}

final class AssessmentClosingPage extends StatefulWidget {
  const AssessmentClosingPage({
    required this.repository,
    required this.logout,
    required this.onOpen,
    this.onDestinationSelected,
    super.key,
  });
  final AssessmentRepository repository;
  final LogoutAction logout;
  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<AssessmentClosingPage> createState() => _AssessmentClosingPageState();
}

final class _AssessmentClosingPageState extends State<AssessmentClosingPage> {
  List<AssessmentClosingItem>? _items;
  Object? _error;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await widget.repository.fetchClosingQueue();
      if (mounted) {
        setState(() => _items = items);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Fechamento de avaliações',
    subtitle: 'Revise pendências e publique resultados autorizados.',
    currentDestination: 'assessment-closing',
    onDestinationSelected: widget.onDestinationSelected,
    child: _body(),
  );
  Widget _body() {
    if (_error != null) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Tente novamente.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Nenhum envio pendente',
        message: 'Os diários enviados aparecerão aqui.',
        icon: Icons.inbox_outlined,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminListingToolbar(
            search: SizedBox(
              width: 320,
              height: CoeloSize.touchMin,
              child: CoeloSearchField(
                controller: _search,
                semanticLabel: 'Buscar fechamento',
                hintText: 'Buscar turma ou Atividade',
                onChanged: (_) => setState(() {}),
              ),
            ),
            filters: const [],
            actions: const [],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminResizableTable<AssessmentClosingItem>(
            items: items.where((item) {
              final query = _search.text.trim().toLowerCase();
              return query.isEmpty ||
                  item.groupName.toLowerCase().contains(query) ||
                  item.activityName.toLowerCase().contains(query);
            }).toList(),
            rowKey: (item) => item.id,
            onRowPressed: (item) => widget.onOpen(item.id),
            pinnedColumn: CoeloAdminTableColumn(
              id: 'activity',
              label: 'Atividade',
              initialWidth: 220,
              minWidth: 160,
              maxWidth: 360,
              cellBuilder: (_, item) => Text(item.activityName),
            ),
            columns: [
              CoeloAdminTableColumn(
                id: 'context',
                label: 'Turma',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 280,
                cellBuilder: (_, item) => Text('${item.unitName} · ${item.groupName}'),
              ),
              CoeloAdminTableColumn(
                id: 'period',
                label: 'Período',
                initialWidth: 160,
                minWidth: 140,
                maxWidth: 220,
                cellBuilder: (_, item) => Text(item.periodName),
              ),
              CoeloAdminTableColumn(
                id: 'pending',
                label: 'Pendências',
                initialWidth: 160,
                minWidth: 140,
                maxWidth: 220,
                cellBuilder: (_, item) => Text('${item.pendingCount}'),
              ),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Situação',
                initialWidth: 160,
                minWidth: 140,
                maxWidth: 220,
                cellBuilder: (_, item) => _bookStatusChip(item.status),
              ),
            ],
            headerHeight: 56,
            rowHeight: 64,
          ),
        ],
      ),
    );
  }
}

final class AssessmentClosingDetailPage extends StatefulWidget {
  const AssessmentClosingDetailPage({
    required this.repository,
    required this.logout,
    required this.gradebookId,
    required this.onBack,
    this.onDestinationSelected,
    super.key,
  });

  final AssessmentRepository repository;
  final LogoutAction logout;
  final String gradebookId;
  final VoidCallback onBack;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<AssessmentClosingDetailPage> createState() => _AssessmentClosingDetailPageState();
}

final class _AssessmentClosingDetailPageState extends State<AssessmentClosingDetailPage> {
  late final AssessmentController _controller;
  double _footerHeight = 0;
  bool _reviewEditsDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = AssessmentController(widget.repository);
    unawaited(_controller.loadGradebook(widget.gradebookId));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _action(AssessmentClosingAction action) async {
    if (action == AssessmentClosingAction.publish) {
      final book = _controller.gradebook;
      if (book == null) return;
      final decision = await showDialog<(DateTime, String)>(
        context: context,
        builder: (context) => _AssessmentPublicationDialog(
          plannedAt: book.familyReleaseAt ?? book.publishScheduledAt,
        ),
      );
      if (decision == null || !mounted) return;
      try {
        await _controller.schedulePublication(decision.$1, decision.$2);
      } on Exception {
        return;
      }
      if (!mounted) return;
      final immediate = !decision.$1.isAfter(DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            immediate
                ? 'Resultados publicados agora.'
                : 'Publicação agendada para a data e hora configuradas.',
          ),
        ),
      );
      return;
    }
    final reason = await _reason(action);
    if (reason == null || !mounted) {
      return;
    }
    try {
      await _controller.transition(action, reason);
    } on Exception {
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fechamento atualizado.')));
  }

  Future<String?> _reason(AssessmentClosingAction action) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AssessmentReasonDialog(
        title: switch (action) {
          AssessmentClosingAction.review => 'Revisar diário',
          AssessmentClosingAction.returnToTeacher => 'Devolver ao professor',
          AssessmentClosingAction.publish => 'Publicar resultados',
        },
      ),
    );
    return result;
  }

  Future<void> _completePending() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AssessmentReasonDialog(title: 'Completar pendências'),
    );
    if (reason == null || !mounted) return;
    try {
      await _controller.saveDraft(reason: reason);
    } on Exception {
      return;
    }
    if (!mounted) return;
    setState(() => _reviewEditsDirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Complemento salvo com justificativa.')));
  }

  void _selectStudent(AssessmentGradebook book, AssessmentStudentEntry student) {
    final index = book.students.indexOf(student);
    while (_controller.selectedStudentIndex < index) {
      _controller.nextStudent();
    }
    while (_controller.selectedStudentIndex > index) {
      _controller.previousStudent();
    }
  }

  void _updateReviewStudent(AssessmentStudentEntry student) {
    _reviewEditsDirty = true;
    _controller.updateStudent(student);
  }

  Widget _reviewerCompletion(AssessmentGradebook book) {
    final pending = book.students.where((student) => !student.isResolved).toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    final selected = _controller.selectedStudent;
    final student = selected != null && pending.contains(selected) ? selected : pending.first;
    final position = pending.indexOf(student);
    final configuration = book.configuration;
    return _AssessmentSection(
      key: const Key('assessment-reviewer-completion'),
      title: 'Completar pendências',
      description: 'Toda alteração pós-envio exige justificativa e fica auditada.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminSingleSelectField<AssessmentStudentEntry>(
            label: 'Aluno pendente',
            value: student,
            options: pending,
            optionLabel: (item) => item.name,
            onChanged: (value) => _selectStudent(book, value),
            prefixIcon: Icons.person_search_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<AssessmentStudentState>(
            key: const Key('assessment-reviewer-student-state'),
            label: 'Situação do aluno',
            value: student.state,
            options: AssessmentStudentState.values,
            optionLabel: _studentStateLabel,
            onChanged: (state) => _updateReviewStudent(student.copyWith(state: state)),
            prefixIcon: Icons.fact_check_outlined,
          ),
          if (configuration == null) ...[
            const SizedBox(height: CoeloSpacing.space4),
            const CoeloStatePanel(
              title: 'Configuração indisponível',
              message: 'Recarregue o diário antes de completar as pendências.',
              icon: Icons.rule_folder_outlined,
            ),
          ] else ...[
            const SizedBox(height: CoeloSpacing.space4),
            for (final instrument in configuration.instruments) ...[
              _ScoreField(
                key: ValueKey('review-${student.id}-${instrument.id}'),
                instrument: instrument,
                configuration: configuration,
                value: student.instruments
                    .where((item) => item.instrumentId == instrument.id)
                    .firstOrNull,
                onChanged: (value) {
                  final entries = [
                    ...student.instruments.where((item) => item.instrumentId != instrument.id),
                    value,
                  ];
                  _updateReviewStudent(
                    student.copyWith(instruments: entries, state: AssessmentStudentState.pending),
                  );
                },
              ),
              const SizedBox(height: CoeloSpacing.space3),
            ],
            Text(
              'Média sugerida: ${student.suggestedScore?.toStringAsFixed(2) ?? '—'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (configuration.competencies.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Text('Competências', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CoeloSpacing.space2),
              for (final competency in configuration.competencies) ...[
                CoeloAdminSingleSelectField<int>(
                  label: competency.name,
                  value:
                      (student.competencies
                                  .where((item) => item.competencyId == competency.id)
                                  .firstOrNull
                                  ?.score ??
                              1)
                          .round()
                          .clamp(1, 5),
                  options: const [1, 2, 3, 4, 5],
                  optionLabel: (score) => '$score de 5',
                  onChanged: (score) {
                    final entries = [
                      ...student.competencies.where((item) => item.competencyId != competency.id),
                      AssessmentCompetencyEntry(
                        competencyId: competency.id,
                        score: score.toDouble(),
                      ),
                    ];
                    _updateReviewStudent(
                      student.copyWith(
                        competencies: entries,
                        state: AssessmentStudentState.pending,
                      ),
                    );
                  },
                ),
                const SizedBox(height: CoeloSpacing.space2),
              ],
            ],
            const SizedBox(height: CoeloSpacing.space4),
            _CommentsEditor(
              key: ValueKey('review-comments-${student.id}'),
              student: student,
              position: position + 1,
              total: pending.length,
              onPrevious: position == 0 ? () {} : () => _selectStudent(book, pending[position - 1]),
              onNext: position == pending.length - 1
                  ? () {}
                  : () => _selectStudent(book, pending[position + 1]),
              onChanged: _updateReviewStudent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _history(AssessmentGradebook book) => _AssessmentSection(
    key: const Key('assessment-closing-history'),
    title: 'Histórico',
    description: 'Eventos imutáveis do ciclo de fechamento.',
    child: book.events.isEmpty
        ? const Text('Nenhum evento registrado.')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final event in book.events)
                Padding(
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                  child: Semantics(
                    label: '${_eventLabel(event.kind)}, versão ${event.version}, ${event.reason}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventLabel(event.kind),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: CoeloSpacing.spaceHalf),
                        Text(event.reason.isEmpty ? 'Sem justificativa adicional.' : event.reason),
                        Text(
                          'Versão ${event.version} · ${_eventDate(event.createdAt)} · ator auditado',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Revisar fechamento',
    subtitle: 'Pendências, visibilidades e histórico do diário.',
    currentDestination: 'assessment-closing',
    onDestinationSelected: widget.onDestinationSelected,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (state is AssessmentLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is! AssessmentReady) {
          return const CoeloStatePanel(
            title: 'Diário indisponível',
            message: 'Recarregue ou verifique sua permissão.',
            icon: Icons.lock_outline_rounded,
          );
        }
        final book = state.gradebook;
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AssessmentSection(
                        title: '${book.context.activityName} · ${book.context.groupName}',
                        description: book.context.periodName,
                        child: Column(
                          children: [
                            for (final student in book.students)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(student.name),
                                          const SizedBox(height: CoeloSpacing.space1),
                                          Text(
                                            'Família: ${student.familyComment.isEmpty ? '—' : student.familyComment}',
                                          ),
                                          Text(
                                            'Interno: ${student.internalNote.isEmpty ? '—' : student.internalNote}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    _statusChip(student.state),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (book.hasPending) ...[
                        const SizedBox(height: CoeloSpacing.space6),
                        _reviewerCompletion(book),
                      ],
                      const SizedBox(height: CoeloSpacing.space6),
                      _history(book),
                    ],
                  ),
                ),
              ),
              SuperadminFormActionFooter(
                surfaceKey: const Key('assessment-closing-footer'),
                onHeightChanged: (height) {
                  if ((_footerHeight - height).abs() > .5) {
                    setState(() => _footerHeight = height);
                  }
                },
                tertiaryAction: TextButton(onPressed: widget.onBack, child: const Text('Voltar')),
                continuationActions: [
                  OutlinedButton(
                    onPressed: () => _action(AssessmentClosingAction.returnToTeacher),
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(colors.error),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.pressed)
                            ? colors.errorContainer
                            : Colors.transparent,
                      ),
                      side: WidgetStatePropertyAll(BorderSide(color: colors.error)),
                    ),
                    child: const Text('Devolver'),
                  ),
                  OutlinedButton(
                    onPressed: () => _action(AssessmentClosingAction.review),
                    child: const Text('Revisar'),
                  ),
                  if (book.hasPending || _reviewEditsDirty)
                    OutlinedButton(
                      onPressed: _controller.saving ? null : _completePending,
                      child: const Text('Completar pendências'),
                    ),
                  FilledButton(
                    onPressed: book.hasPending || _reviewEditsDirty
                        ? null
                        : () => _action(AssessmentClosingAction.publish),
                    child: const Text('Publicar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _eventLabel(String kind) => switch (kind) {
  'submitted' => 'Enviado para fechamento',
  'reviewed' => 'Revisado',
  'returned' => 'Devolvido ao professor',
  'published' => 'Publicado',
  'corrected' => 'Correção publicada',
  _ => 'Rascunho salvo',
};

String _eventDate(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

final class _AssessmentReasonDialog extends StatefulWidget {
  const _AssessmentReasonDialog({required this.title});

  final String title;

  @override
  State<_AssessmentReasonDialog> createState() => _AssessmentReasonDialogState();
}

final class _AssessmentReasonDialogState extends State<_AssessmentReasonDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: widget.title,
    body: CoeloFormTextField(
      key: const Key('assessment-closing-reason'),
      controller: _reason,
      labelText: 'Justificativa',
      prefixIcon: Icons.notes_rounded,
      maxLines: 3,
      errorText: _attempted && _reason.text.trim().isEmpty
          ? 'Informe a justificativa obrigatória.'
          : null,
      onChanged: (_) {
        if (_attempted) setState(() {});
      },
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
  );
}

final class _AssessmentPublicationDialog extends StatefulWidget {
  const _AssessmentPublicationDialog({this.plannedAt});

  final DateTime? plannedAt;

  @override
  State<_AssessmentPublicationDialog> createState() => _AssessmentPublicationDialogState();
}

final class _AssessmentPublicationDialogState extends State<_AssessmentPublicationDialog> {
  final TextEditingController _reason = TextEditingController();
  late bool _publishNow = widget.plannedAt == null;
  late DateTime? _publishAt = widget.plannedAt;
  bool _attempted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reason.text.trim();
    final publishAt = _publishNow ? DateTime.now() : _publishAt;
    if (reason.isEmpty || publishAt == null) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.pop(context, (publishAt, reason));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return CoeloAdminDialogShell(
      title: 'Publicar resultados',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminSingleSelectField<bool>(
            key: const Key('assessment-publication-mode'),
            label: 'Momento da publicação',
            value: _publishNow,
            options: const [false, true],
            optionLabel: (value) => value ? 'Publicar agora' : 'Na data configurada',
            onChanged: (value) => setState(() => _publishNow = value),
            prefixIcon: Icons.publish_outlined,
          ),
          if (!_publishNow) ...[
            const SizedBox(height: CoeloSpacing.space4),
            CoeloDateTimeField(
              key: const Key('assessment-publication-at'),
              value: _publishAt,
              onChanged: (value) => setState(() => _publishAt = value),
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 10, 12, 31),
              currentDate: now,
              labelText: 'Data e hora da publicação',
            ),
            if (_attempted && _publishAt == null) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Defina a data e a hora planejadas.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            key: const Key('assessment-publication-reason'),
            controller: _reason,
            labelText: _publishNow ? 'Motivo da publicação imediata' : 'Justificativa',
            prefixIcon: Icons.notes_rounded,
            maxLines: 3,
            errorText: _attempted && _reason.text.trim().isEmpty
                ? 'Informe o motivo obrigatório.'
                : null,
            onChanged: (_) {
              if (_attempted) setState(() {});
            },
          ),
          if (_publishNow) ...[
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'Publicar agora exige permissão de publicação, AAL2 e auditoria. A data planejada será preservada.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(onPressed: _confirm, child: const Text('Confirmar publicação')),
    );
  }
}

final class _AssessmentSection extends StatelessWidget {
  const _AssessmentSection({
    required this.title,
    required this.description,
    required this.child,
    this.trailing,
    super.key,
  });
  final String title, description;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey(title),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          if (trailing == null) {
            return heading;
          }
          final stack =
              constraints.maxWidth < CoeloBreakpoints.medium.minWidth ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: CoeloSpacing.space2),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              trailing!,
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space5),
      child,
    ],
  );
}

final class _ScoreField extends StatefulWidget {
  const _ScoreField({
    required this.instrument,
    required this.configuration,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final AssessmentInstrument instrument;
  final AssessmentConfiguration configuration;
  final AssessmentInstrumentEntry? value;
  final ValueChanged<AssessmentInstrumentEntry> onChanged;
  @override
  State<_ScoreField> createState() => _ScoreFieldState();
}

final class _ConfiguredPeriodEditor extends StatefulWidget {
  const _ConfiguredPeriodEditor({
    required this.period,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final AssessmentConfiguredPeriod period;
  final ValueChanged<AssessmentConfiguredPeriod> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ConfiguredPeriodEditor> createState() => _ConfiguredPeriodEditorState();
}

final class _ConfiguredPeriodEditorState extends State<_ConfiguredPeriodEditor> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.period.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CoeloFormTextField(
              controller: _name,
              labelText: 'Nome do período',
              prefixIcon: Icons.calendar_view_month_outlined,
              onChanged: (name) => widget.onChanged(widget.period.copyWith(name: name)),
            ),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          IconButton(
            tooltip: 'Remover período',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space3),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
          return Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space3,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: CoeloDateRangeField(
                  value: DateTimeRange(start: widget.period.startsOn, end: widget.period.endsOn),
                  onChanged: (range) {
                    if (range == null) return;
                    widget.onChanged(
                      widget.period.copyWith(
                        startsOn: range.start,
                        endsOn: range.end,
                        academicYear: range.start.year,
                      ),
                    );
                  },
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                  labelText: 'Início e término',
                  showQuickRanges: false,
                ),
              ),
              SizedBox(
                width: width,
                child: CoeloDateTimeField(
                  value: widget.period.entryClosesAt,
                  onChanged: (date) {
                    if (date != null) {
                      widget.onChanged(widget.period.copyWith(entryClosesAt: date));
                    }
                  },
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                  labelText: 'Fechamento do lançamento',
                ),
              ),
              SizedBox(
                width: width,
                child: CoeloDateTimeField(
                  value: widget.period.familyReleaseAt,
                  onChanged: (date) {
                    if (date != null) {
                      widget.onChanged(widget.period.copyWith(familyReleaseAt: date));
                    }
                  },
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                  labelText: 'Disponível à família em',
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

// ignore: unused_element
final class _AssessmentDateField extends StatefulWidget {
  const _AssessmentDateField({required this.label, required this.value, required this.onPressed});

  final String label;
  final DateTime value;
  final VoidCallback onPressed;

  @override
  State<_AssessmentDateField> createState() => _AssessmentDateFieldState();
}

final class _AssessmentDateFieldState extends State<_AssessmentDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatAssessmentDate(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AssessmentDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _formatAssessmentDate(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    controller: _controller,
    labelText: widget.label,
    prefixIcon: Icons.calendar_month_outlined,
    suffixIcon: IconButton(
      tooltip: widget.label,
      onPressed: widget.onPressed,
      icon: const Icon(Icons.edit_calendar_outlined),
    ),
  );
}

final class _ConceptOptionsEditor extends StatefulWidget {
  const _ConceptOptionsEditor({required this.concepts, required this.onChanged, super.key});

  final List<String> concepts;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ConceptOptionsEditor> createState() => _ConceptOptionsEditorState();
}

final class _ConceptOptionsEditorState extends State<_ConceptOptionsEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.concepts.join(', '));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloFormTextField(
        controller: _controller,
        labelText: 'Conceitos permitidos',
        prefixIcon: Icons.label_outline_rounded,
        onChanged: (value) => widget.onChanged(
          value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space1),
      const Text('Separe os conceitos por vírgula.'),
    ],
  );
}

final class _InstrumentConfigurationEditor extends StatefulWidget {
  const _InstrumentConfigurationEditor({
    required this.instrument,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final AssessmentInstrument instrument;
  final ValueChanged<AssessmentInstrument> onChanged;
  final VoidCallback onRemove;

  @override
  State<_InstrumentConfigurationEditor> createState() => _InstrumentConfigurationEditorState();
}

final class _InstrumentConfigurationEditorState extends State<_InstrumentConfigurationEditor> {
  late final TextEditingController _name;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.instrument.name);
    _weight = TextEditingController(
      text: widget.instrument.weight == 0 ? '' : widget.instrument.weight.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    AssessmentInstrument(
      id: widget.instrument.id,
      name: _name.text.trim(),
      weight: double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0,
      sortOrder: widget.instrument.sortOrder,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final name = CoeloFormTextField(
        controller: _name,
        labelText: 'Instrumento',
        prefixIcon: Icons.assignment_outlined,
        onChanged: (_) => _emit(),
      );
      final weight = CoeloFormTextField(
        controller: _weight,
        labelText: 'Peso (%)',
        prefixIcon: Icons.percent_rounded,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
        onChanged: (_) => _emit(),
      );
      final remove = IconButton(
        tooltip: 'Remover instrumento',
        onPressed: widget.onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            name,
            const SizedBox(height: CoeloSpacing.space2),
            weight,
            remove,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: name),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: weight),
          const SizedBox(width: CoeloSpacing.space2),
          remove,
        ],
      );
    },
  );
}

final class _ScoreFieldState extends State<_ScoreField> {
  late final TextEditingController _field;
  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.value?.numericValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.instrument.name} · ${widget.instrument.weight.toStringAsFixed(0)}%';
    return switch (widget.configuration.scaleKind) {
      AssessmentScaleKind.concept => CoeloAdminSingleSelectField<String?>(
        label: label,
        value: widget.value?.conceptCode,
        options: [null, ...widget.configuration.concepts],
        optionLabel: (value) => value ?? 'Não informado',
        prefixIcon: Icons.grade_outlined,
        onChanged: (value) => widget.onChanged(
          AssessmentInstrumentEntry(instrumentId: widget.instrument.id, conceptCode: value),
        ),
      ),
      AssessmentScaleKind.binary => CoeloAdminSingleSelectField<bool?>(
        label: label,
        value: widget.value?.booleanValue,
        options: const [null, true, false],
        optionLabel: (value) => value == null
            ? 'Não informado'
            : value
            ? 'Sim'
            : 'Não',
        prefixIcon: Icons.grade_outlined,
        onChanged: (value) => widget.onChanged(
          AssessmentInstrumentEntry(instrumentId: widget.instrument.id, booleanValue: value),
        ),
      ),
      AssessmentScaleKind.numeric1To5 ||
      AssessmentScaleKind.stars0To5 => CoeloAdminSingleSelectField<int?>(
        label: label,
        value: widget.value?.numericValue?.round(),
        options: widget.configuration.scaleKind == AssessmentScaleKind.numeric1To5
            ? const [null, 1, 2, 3, 4, 5]
            : const [null, 0, 1, 2, 3, 4, 5],
        optionLabel: (value) => value?.toString() ?? 'Não informado',
        prefixIcon: widget.configuration.scaleKind == AssessmentScaleKind.stars0To5
            ? Icons.star_outline_rounded
            : Icons.grade_outlined,
        onChanged: (value) => widget.onChanged(
          AssessmentInstrumentEntry(
            instrumentId: widget.instrument.id,
            numericValue: value?.toDouble(),
          ),
        ),
      ),
      _ => CoeloFormTextField(
        controller: _field,
        labelText: label,
        prefixIcon: Icons.grade_outlined,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
        onChanged: (text) => widget.onChanged(
          AssessmentInstrumentEntry(
            instrumentId: widget.instrument.id,
            numericValue: double.tryParse(text.replaceAll(',', '.')),
          ),
        ),
      ),
    };
  }
}

final class _NumericOverrideEditor extends StatefulWidget {
  const _NumericOverrideEditor({required this.student, required this.onChanged, super.key});

  final AssessmentStudentEntry student;
  final ValueChanged<AssessmentStudentEntry> onChanged;

  @override
  State<_NumericOverrideEditor> createState() => _NumericOverrideEditorState();
}

final class _NumericOverrideEditorState extends State<_NumericOverrideEditor> {
  late final TextEditingController _value;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.student.finalNumericValue?.toString() ?? '');
    _reason = TextEditingController(text: widget.student.overrideReason);
  }

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _emit() {
    final numeric = double.tryParse(_value.text.replaceAll(',', '.'));
    widget.onChanged(
      widget.student.copyWith(
        finalNumericValue: numeric,
        clearFinalNumericValue: numeric == null,
        overrideReason: _reason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CoeloFormTextField(
        controller: _value,
        labelText: 'Média final revisada',
        prefixIcon: Icons.edit_note_rounded,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
        onChanged: (_) => _emit(),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloFormTextField(
        controller: _reason,
        labelText: 'Justificativa da alteração',
        prefixIcon: Icons.notes_rounded,
        maxLines: 3,
        onChanged: (_) => _emit(),
      ),
    ],
  );
}

final class _CommentsEditor extends StatefulWidget {
  const _CommentsEditor({
    required this.student,
    required this.position,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onChanged,
    super.key,
  });
  final AssessmentStudentEntry student;
  final int position, total;
  final VoidCallback onPrevious, onNext;
  final ValueChanged<AssessmentStudentEntry> onChanged;
  @override
  State<_CommentsEditor> createState() => _CommentsEditorState();
}

final class _CommentsEditorState extends State<_CommentsEditor> {
  late final TextEditingController _family, _internal;
  @override
  void initState() {
    super.initState();
    _family = TextEditingController(text: widget.student.familyComment);
    _internal = TextEditingController(text: widget.student.internalNote);
  }

  @override
  void dispose() {
    _family.dispose();
    _internal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AssessmentSection(
    title: widget.student.name,
    description: '${widget.position} de ${widget.total}',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Aluno anterior',
          onPressed: widget.position == 1 ? null : widget.onPrevious,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        IconButton(
          tooltip: 'Próximo aluno',
          onPressed: widget.position == widget.total ? null : widget.onNext,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    ),
    child: Column(
      children: [
        CoeloFormTextField(
          controller: _family,
          labelText: 'Comentário visível à família',
          prefixIcon: Icons.family_restroom_outlined,
          maxLines: 4,
          onChanged: (value) => widget.onChanged(widget.student.copyWith(familyComment: value)),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _internal,
          labelText: 'Observação interna',
          prefixIcon: Icons.lock_outline_rounded,
          maxLines: 4,
          onChanged: (value) => widget.onChanged(widget.student.copyWith(internalNote: value)),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: CoeloSize.iconSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: CoeloSpacing.space1),
            const Expanded(child: Text('A observação interna nunca é exibida à família.')),
          ],
        ),
      ],
    ),
  );
}

final class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: CoeloSpacing.spaceHalf),
        Text(value),
      ],
    ),
  );
}

Widget _statusChip(AssessmentStudentState state) {
  return Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return CoeloStatusChip(
        label: _studentStateLabel(state),
        backgroundColor: state == AssessmentStudentState.complete
            ? colors.primaryContainer
            : state == AssessmentStudentState.absent
            ? colors.secondaryContainer
            : colors.surfaceContainerHigh,
        foregroundColor: state == AssessmentStudentState.complete
            ? colors.primary
            : state == AssessmentStudentState.absent
            ? colors.onSecondaryContainer
            : colors.onSurfaceVariant,
        icon: switch (state) {
          AssessmentStudentState.complete => Icons.check_circle_outline_rounded,
          AssessmentStudentState.absent => Icons.event_busy_outlined,
          AssessmentStudentState.pending => Icons.pending_outlined,
          AssessmentStudentState.notStarted => Icons.radio_button_unchecked_rounded,
        },
      );
    },
  );
}

Widget _bookStatusChip(AssessmentGradebookStatus status) => Builder(
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloStatusChip(
      label: switch (status) {
        AssessmentGradebookStatus.draft => 'Rascunho',
        AssessmentGradebookStatus.submitted => 'Enviado',
        AssessmentGradebookStatus.reviewed => 'Revisado',
        AssessmentGradebookStatus.published => 'Publicado',
      },
      backgroundColor: status == AssessmentGradebookStatus.published
          ? colors.primaryContainer
          : colors.surfaceContainerHigh,
      foregroundColor: status == AssessmentGradebookStatus.published
          ? colors.primary
          : colors.onSurfaceVariant,
    );
  },
);
String _studentStateLabel(AssessmentStudentState state) => switch (state) {
  AssessmentStudentState.complete => 'Completo',
  AssessmentStudentState.pending => 'Pendente',
  AssessmentStudentState.absent => 'Ausente',
  AssessmentStudentState.notStarted => 'Não iniciado',
};
String _formatAssessmentDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.year.toString().padLeft(4, '0')}';
String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part.characters.first.toUpperCase())
    .join();
String _scaleLabel(AssessmentScaleKind scale) => switch (scale) {
  AssessmentScaleKind.numeric0To10 => 'Numérica de 0 a 10',
  AssessmentScaleKind.numeric0To100 => 'Numérica de 0 a 100',
  AssessmentScaleKind.concept => 'Conceitos',
  AssessmentScaleKind.numeric1To5 => 'Numérica de 1 a 5',
  AssessmentScaleKind.binary => 'Binária',
  AssessmentScaleKind.stars0To5 => 'Estrelas de 0 a 5',
};
