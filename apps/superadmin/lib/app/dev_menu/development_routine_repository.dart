import '../../features/daily_routine/domain/routine_contract.dart';

final class DevelopmentRoutineNotFoundException implements Exception {
  const DevelopmentRoutineNotFoundException();
}

final class DevelopmentRoutineRepository implements RoutineRepository {
  DevelopmentRoutineRepository.content()
    : _mode = _DevelopmentRoutineMode.content,
      _models = {'model-1': _seedModel},
      _applications = {'application-1': _seedApplication},
      _launches = {'launch-1': _seedLaunch};

  DevelopmentRoutineRepository.empty()
    : _mode = _DevelopmentRoutineMode.empty,
      _models = {},
      _applications = {},
      _launches = {};

  DevelopmentRoutineRepository.failure()
    : _mode = _DevelopmentRoutineMode.failure,
      _models = {},
      _applications = {},
      _launches = {};

  DevelopmentRoutineRepository.unauthorized()
    : _mode = _DevelopmentRoutineMode.unauthorized,
      _models = {},
      _applications = {},
      _launches = {};

  final _DevelopmentRoutineMode _mode;
  final Map<String, RoutineModel> _models;
  final Map<String, RoutineApplication> _applications;
  final Map<String, RoutineLaunch> _launches;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    _guard();
    final all = switch (query.kind) {
      RoutineEntryKind.model => _models.values.toList().reversed.map(_modelItem),
      RoutineEntryKind.application => _applications.values.toList().reversed.map(_applicationItem),
      RoutineEntryKind.launch => _launches.values.toList().reversed.map(_launchItem),
    };
    final search = query.search.trim().toLowerCase();
    final filtered = all
        .where((item) => search.isEmpty || item.name.toLowerCase().contains(search))
        .where((item) => query.status == null || item.status == query.status)
        .toList(growable: false);
    final start = ((query.page - 1).clamp(0, 1 << 20)) * query.pageSize;
    final items = start >= filtered.length
        ? const <RoutineDirectoryItem>[]
        : filtered.sublist(start, (start + query.pageSize).clamp(0, filtered.length));
    return RoutineDirectoryPage(
      items: items,
      page: query.page,
      pageSize: query.pageSize,
      totalCount: filtered.length,
      canManage: true,
    );
  }

  @override
  Future<RoutineFormOptions> fetchFormOptions(RoutineFormOptionsQuery query) async {
    _guard();
    return const RoutineFormOptions(
      canManage: true,
      institutions: [RoutineInstitutionOption(id: 'institution-1', label: 'Instituto Horizonte')],
      units: [
        RoutineUnitOption(
          id: 'unit-1',
          institutionId: 'institution-1',
          label: 'Unidade Centro',
        ),
      ],
      groups: [
        RoutineGroupOption(
          id: 'group-1',
          institutionId: 'institution-1',
          unitId: 'unit-1',
          label: 'Turma Sol',
        ),
      ],
      memberships: [
        RoutineMembershipOption(
          id: 'membership-1',
          institutionId: 'institution-1',
          label: 'Prof. Marina',
        ),
      ],
      models: [
        RoutineModelOption(id: 'model-1', institutionId: 'institution-1', label: 'Rotina diária'),
      ],
      modelVersions: [
        RoutineModelVersionOption(id: 'model-version-1', modelId: 'model-1', version: 1, label: 'v1'),
      ],
      applications: [
        RoutineApplicationOption(
          id: 'application-1',
          revisionId: 'revision-1',
          institutionId: 'institution-1',
          unitId: 'unit-1',
          groupId: 'group-1',
          label: 'Rotina · Turma Sol',
        ),
      ],
    );
  }

  @override
  Future<RoutineModel> fetchModel(String id) async {
    _guard();
    return _models[id] ?? (throw const DevelopmentRoutineNotFoundException());
  }

  @override
  Future<RoutineApplication> fetchApplication(String id) async {
    _guard();
    return _applications[id] ?? (throw const DevelopmentRoutineNotFoundException());
  }

  @override
  Future<RoutineLaunch> fetchLaunch(String id) async {
    _guard();
    return _launches[id] ?? (throw const DevelopmentRoutineNotFoundException());
  }

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async {
    _guard();
    model.validate();
    _models[model.id] = model;
    return model.id;
  }

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    _guard();
    application.validate();
    _applications[application.id] = application;
    return application.id;
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    final current = await fetchApplication(applicationId);
    _applications[applicationId] = _applicationWith(
      current,
      inheritanceMode: RoutineInheritanceMode.inherited,
    );
    return applicationId;
  }

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async {
    _guard();
    _launches[launch.id] = launch;
    return launch.id;
  }

  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async {
    final current = await fetchLaunch(launchId);
    _launches[launchId] = _launchWith(current, status: RoutineLaunchStatus.published);
  }

  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    final current = await fetchLaunch(launchId);
    _launches[launchId] = _launchWith(current, status: RoutineLaunchStatus.corrected);
  }

  void _guard() {
    switch (_mode) {
      case _DevelopmentRoutineMode.content || _DevelopmentRoutineMode.empty:
        return;
      case _DevelopmentRoutineMode.failure:
        throw StateError('Rotina diária indisponível na fixture local.');
      case _DevelopmentRoutineMode.unauthorized:
        throw StateError('Rotina diária não autorizada na fixture local.');
    }
  }
}

enum _DevelopmentRoutineMode { content, empty, failure, unauthorized }

RoutineDirectoryItem _modelItem(RoutineModel value) => RoutineDirectoryItem(
  id: value.id,
  kind: RoutineEntryKind.model,
  name: value.name,
  status: value.status.name,
  version: value.version,
  originLabel: 'Instituto Horizonte',
);

RoutineDirectoryItem _applicationItem(RoutineApplication value) => RoutineDirectoryItem(
  id: value.id,
  kind: RoutineEntryKind.application,
  name: 'Rotina · Turma Sol',
  status: value.status.name,
  version: value.effectiveVersion,
  effectiveLabel: value.inheritanceMode.name,
);

RoutineDirectoryItem _launchItem(RoutineLaunch value) => RoutineDirectoryItem(
  id: value.id,
  kind: RoutineEntryKind.launch,
  name: 'Lançamento · Turma Sol',
  status: value.status.name,
  version: value.expectedVersion,
);

RoutineApplication _applicationWith(
  RoutineApplication value, {
  required RoutineInheritanceMode inheritanceMode,
}) => RoutineApplication(
  id: value.id,
  modelVersionId: value.modelVersionId,
  institutionId: value.institutionId,
  unitId: value.unitId,
  groupId: value.groupId,
  parentApplicationId: value.parentApplicationId,
  activityId: value.activityId,
  status: value.status,
  inheritanceMode: inheritanceMode,
  effectiveVersion: value.effectiveVersion,
  expectedVersion: value.expectedVersion,
  validFrom: value.validFrom,
  validUntil: value.validUntil,
  startsAt: value.startsAt,
  endsAt: value.endsAt,
  visibility: value.visibility,
  assignees: value.assignees,
  canManage: value.canManage,
);

RoutineLaunch _launchWith(RoutineLaunch value, {required RoutineLaunchStatus status}) =>
    RoutineLaunch(
      id: value.id,
      applicationId: value.applicationId,
      applicationRevisionId: value.applicationRevisionId,
      institutionId: value.institutionId,
      unitId: value.unitId,
      groupId: value.groupId,
      activityId: value.activityId,
      authorMembershipId: value.authorMembershipId,
      serviceDate: value.serviceDate,
      status: status,
      expectedVersion: value.expectedVersion,
      children: value.children,
      canManage: value.canManage,
    );

final _seedModel = RoutineModel(
  id: 'model-1',
  name: 'Rotina diária',
  description: 'Modelo local para pré-visualização.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: const [],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

const _seedApplication = RoutineApplication(
  id: 'application-1',
  modelVersionId: 'model-version-1',
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  status: RoutineApplicationStatus.active,
  inheritanceMode: RoutineInheritanceMode.inherited,
  effectiveVersion: 1,
  expectedVersion: 1,
  canManage: true,
);

final _seedLaunch = RoutineLaunch(
  id: 'launch-1',
  applicationId: 'application-1',
  applicationRevisionId: 'revision-1',
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  authorMembershipId: 'membership-1',
  serviceDate: DateTime(2026, 8, 24),
  status: RoutineLaunchStatus.draft,
  expectedVersion: 1,
  canManage: true,
);
