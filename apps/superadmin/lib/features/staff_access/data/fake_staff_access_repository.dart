import '../domain/staff_access.dart';

/// Repositório em memória para testes de widget e ambiente `/dev`.
/// Reproduz o contrato do servidor (estado, versão, PT409) sem autorizar nada.
final class FakeStaffAccessRepository implements StaffAccessRepository {
  FakeStaffAccessRepository({List<StaffAccessItem>? items, this.delay = Duration.zero})
    : _items = {for (final item in items ?? sampleStaffAccessItems()) item.membershipId: item};

  final Map<String, StaffAccessItem> _items;
  final Duration delay;

  /// Quando ligado, o próximo salvar responde com versão defasada.
  bool failNextSaveWithConflict = false;
  bool unauthorized = false;
  bool unavailable = false;

  /// Chamadas recebidas (para asserções nos testes).
  final List<StaffAccessRuleDraft> savedRules = [];
  final List<StaffLeaveDraft> savedLeaves = [];
  final List<StaffAccessRuleDraft> savedProfileRules = [];

  /// Regras por perfil (roleId -> regra), como `staff_access_profile_rules`.
  final Map<String, StaffAccessRule> profileRules = {
    'role-educador': StaffAccessRule(
      id: 'profile-rule-educador',
      roleId: 'role-educador',
      roleName: 'Educador(a)',
      surfaces: StaffAccessSurface.values.toSet(),
      windows: [
        for (var d = 1; d <= 5; d++) StaffAccessWindow(weekday: d, start: '07:30', end: '18:30'),
      ],
      validFrom: null,
      validUntil: null,
      validitySurfaces: StaffAccessSurface.values.toSet(),
      popupEnabled: true,
      popupShowValidity: false,
      version: 1,
    ),
  };

  Future<void> _tick() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (unavailable) throw const StaffAccessUnavailableException();
    if (unauthorized) throw const StaffAccessUnauthorizedException();
  }

  @override
  Future<StaffAccessPage> fetchPage(StaffAccessQuery query) async {
    await _tick();
    final search = query.search.trim().toLowerCase();
    final filtered = _items.values
        .where((item) => search.isEmpty || item.personName.toLowerCase().contains(search))
        .where((item) => query.institutionId == null || item.institutionId == query.institutionId)
        .where((item) => query.unitId == null || item.unitId == query.unitId)
        .where((item) => query.states.isEmpty || query.states.contains(item.state))
        .where((item) => query.sources.isEmpty || query.sources.contains(item.source))
        .toList()
      ..sort((a, b) => a.institutionName.compareTo(b.institutionName) != 0
          ? a.institutionName.compareTo(b.institutionName)
          : a.personName.compareTo(b.personName));
    final start = query.page * query.pageSize;
    final pageItems = start >= filtered.length
        ? const <StaffAccessItem>[]
        : filtered.sublist(start, (start + query.pageSize).clamp(0, filtered.length));
    final institutions = <String, StaffAccessFilterOption>{};
    final units = <String, StaffAccessFilterOption>{};
    for (final item in _items.values) {
      institutions[item.institutionId] = StaffAccessFilterOption(
        id: item.institutionId,
        label: item.institutionName,
      );
      if (item.unitId != null) {
        units[item.unitId!] = StaffAccessFilterOption(
          id: item.unitId!,
          label: item.unitName ?? '',
          institutionId: item.institutionId,
        );
      }
    }
    return StaffAccessPage(
      items: pageItems,
      totalCount: filtered.length,
      page: query.page,
      filterOptions: StaffAccessFilterOptions(
        institutions: institutions.values.toList(),
        units: units.values
            .where((u) => query.institutionId == null || u.institutionId == query.institutionId)
            .toList(),
      ),
    );
  }

  @override
  Future<StaffAccessItem> fetchDetail(String membershipId) async {
    await _tick();
    final item = _items[membershipId];
    if (item == null) throw const StaffAccessUnavailableException();
    return item;
  }

  @override
  Future<StaffAccessItem> saveRule(
    String membershipId,
    int? expectedVersion,
    StaffAccessRuleDraft draft,
  ) async {
    await _tick();
    final item = _items[membershipId];
    if (item == null) throw const StaffAccessUnavailableException();
    if (failNextSaveWithConflict) {
      failNextSaveWithConflict = false;
      throw const StaffAccessConflictException();
    }
    if ((item.rule?.version) != expectedVersion) throw const StaffAccessConflictException();
    savedRules.add(draft);
    final rule = draft.clear
        ? null
        : StaffAccessRule(
            id: item.rule?.id ?? 'rule-$membershipId',
            membershipId: membershipId,
            surfaces: draft.surfaces,
            windows: draft.windows,
            validFrom: draft.validFrom,
            validUntil: draft.validUntil,
            validitySurfaces: draft.validitySurfaces,
            popupEnabled: draft.popupEnabled,
            popupShowValidity: draft.popupShowValidity,
            version: (item.rule?.version ?? 0) + 1,
          );
    final updated = _copy(item, rule: rule, state: _stateFor(rule ?? item.profileRule, item.leaves));
    _items[membershipId] = updated;
    return updated;
  }

  @override
  Future<StaffAccessProfileRule> fetchProfileRule(String roleId) async {
    await _tick();
    return _profile(roleId);
  }

  @override
  Future<StaffAccessProfileRule> saveProfileRule(
    String roleId,
    int? expectedVersion,
    StaffAccessRuleDraft draft,
  ) async {
    await _tick();
    if (failNextSaveWithConflict) {
      failNextSaveWithConflict = false;
      throw const StaffAccessConflictException();
    }
    final existing = profileRules[roleId];
    if (existing?.version != expectedVersion) throw const StaffAccessConflictException();
    savedProfileRules.add(draft);
    if (draft.clear) {
      profileRules.remove(roleId);
    } else {
      profileRules[roleId] = StaffAccessRule(
        id: existing?.id ?? 'profile-rule-$roleId',
        roleId: roleId,
        roleName: existing?.roleName ?? roleId,
        surfaces: draft.surfaces,
        windows: draft.windows,
        validFrom: draft.validFrom,
        validUntil: draft.validUntil,
        validitySurfaces: draft.validitySurfaces,
        popupEnabled: draft.popupEnabled,
        popupShowValidity: draft.popupShowValidity,
        version: (existing?.version ?? 0) + 1,
      );
    }
    // Vínculos que herdam deste perfil refletem a mudança.
    for (final entry in _items.entries.toList()) {
      final item = entry.value;
      if (item.profileRule?.roleId != roleId) continue;
      final profileRule = profileRules[roleId];
      _items[entry.key] = _copy(
        item,
        profileRule: () => profileRule,
        state: _stateFor(item.rule ?? profileRule, item.leaves),
      );
    }
    return _profile(roleId);
  }

  StaffAccessProfileRule _profile(String roleId) {
    final rule = profileRules[roleId];
    final linked = _items.values.where((i) => i.profileRule?.roleId == roleId || i.roleCode == roleId);
    return StaffAccessProfileRule(
      roleId: roleId,
      roleName: rule?.roleName ?? roleId,
      rule: rule,
      membershipCount: linked.length,
      ownRuleCount: linked.where((i) => i.rule != null).length,
    );
  }

  @override
  Future<StaffLeavePage> fetchLeaves(StaffLeaveQuery query) async {
    await _tick();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final search = query.search.trim().toLowerCase();
    final all = [
      for (final item in _items.values)
        for (final leave in item.leaves)
          StaffLeave(
            id: leave.id,
            membershipId: leave.membershipId,
            startsOn: leave.startsOn,
            endsOn: leave.endsOn,
            popupEnabled: leave.popupEnabled,
            internalNote: leave.internalNote,
            version: leave.version,
            membership: item,
          ),
    ];
    final filtered = all
        .where((l) => search.isEmpty || l.membership!.personName.toLowerCase().contains(search))
        .where((l) => query.institutionId == null || l.membership!.institutionId == query.institutionId)
        .where((l) => query.unitId == null || l.membership!.unitId == query.unitId)
        .where((l) => switch (query.period) {
          null => true,
          StaffLeavePeriod.current => !l.startsOn.isAfter(day) && !l.endsOn.isBefore(day),
          StaffLeavePeriod.upcoming => l.startsOn.isAfter(day),
          StaffLeavePeriod.past => l.endsOn.isBefore(day),
        })
        .toList()
      ..sort((a, b) => b.startsOn.compareTo(a.startsOn));
    final start = query.page * query.pageSize;
    return StaffLeavePage(
      items: start >= filtered.length
          ? const []
          : filtered.sublist(start, (start + query.pageSize).clamp(0, filtered.length)),
      totalCount: filtered.length,
      page: query.page,
    );
  }

  @override
  Future<StaffLeave?> saveLeave({
    String? leaveId,
    required String membershipId,
    int? expectedVersion,
    required StaffLeaveDraft draft,
  }) async {
    await _tick();
    final item = _items[membershipId];
    if (item == null) throw const StaffAccessUnavailableException();
    if (failNextSaveWithConflict) {
      failNextSaveWithConflict = false;
      throw const StaffAccessConflictException();
    }
    final existing = item.leaves.where((l) => l.id == leaveId).firstOrNull;
    if ((existing?.version) != expectedVersion) throw const StaffAccessConflictException();
    savedLeaves.add(draft);
    final leaves = [...item.leaves]..removeWhere((l) => l.id == leaveId);
    StaffLeave? saved;
    if (!draft.remove) {
      saved = StaffLeave(
        id: leaveId ?? 'leave-${DateTime.now().microsecondsSinceEpoch}',
        membershipId: membershipId,
        startsOn: draft.startsOn,
        endsOn: draft.endsOn,
        popupEnabled: draft.popupEnabled,
        internalNote: draft.internalNote,
        version: (existing?.version ?? 0) + 1,
      );
      leaves.add(saved);
    }
    _items[membershipId] = _copy(item, leaves: leaves, state: _stateFor(item.rule, leaves));
    return saved;
  }

  static StaffAccessState _stateFor(StaffAccessRule? rule, List<StaffLeave> leaves) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (leaves.any((l) => !l.startsOn.isAfter(day) && !l.endsOn.isBefore(day))) {
      return StaffAccessState.blockedNow;
    }
    if (leaves.any((l) => !l.endsOn.isBefore(day))) return StaffAccessState.leave;
    if (rule == null) return StaffAccessState.free;
    if (rule.validFrom != null || rule.validUntil != null) return StaffAccessState.validity;
    if (rule.windows.isNotEmpty || rule.surfaces.length < 4) return StaffAccessState.schedule;
    return StaffAccessState.free;
  }

  static StaffAccessItem _copy(
    StaffAccessItem item, {
    StaffAccessRule? rule,
    StaffAccessRule? Function()? profileRule,
    List<StaffLeave>? leaves,
    StaffAccessState? state,
  }) {
    final nextLeaves = leaves ?? item.leaves;
    final nextRule = leaves == null && rule == null && state == null ? item.rule : rule;
    final nextProfileRule = profileRule == null ? item.profileRule : profileRule();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return StaffAccessItem(
      membershipId: item.membershipId,
      personId: item.personId,
      personName: item.personName,
      roleCode: item.roleCode,
      roleName: item.roleName,
      institutionId: item.institutionId,
      institutionName: item.institutionName,
      unitId: item.unitId,
      unitName: item.unitName,
      groupId: item.groupId,
      groupName: item.groupName,
      timezone: item.timezone,
      state: state ?? item.state,
      rule: nextRule,
      profileRule: nextProfileRule,
      profileName: nextProfileRule?.roleName,
      source: nextRule != null
          ? StaffAccessSource.own
          : nextProfileRule != null
          ? StaffAccessSource.profile
          : StaffAccessSource.none,
      currentLeave: nextLeaves
          .where((l) => !l.startsOn.isAfter(day) && !l.endsOn.isBefore(day))
          .firstOrNull,
      leavesCount: nextLeaves.length,
      canManage: item.canManage,
      leaves: nextLeaves,
    );
  }
}

/// Massa de exemplo para `/dev` e testes.
List<StaffAccessItem> sampleStaffAccessItems() {
  StaffAccessItem item({
    required String id,
    required String name,
    required String role,
    required String institution,
    String? unit,
    String? group,
    StaffAccessState state = StaffAccessState.free,
    StaffAccessRule? rule,
    StaffAccessRule? profileRule,
    List<StaffLeave> leaves = const [],
  }) => StaffAccessItem(
    membershipId: id,
    personId: 'person-$id',
    personName: name,
    roleCode: role,
    roleName: switch (role) {
      'teacher' => 'Professor(a)',
      'coordinator' => 'Coordenação',
      'secretary' => 'Secretaria',
      _ => 'Administrador da instituição',
    },
    institutionId: 'inst-${institution.hashCode}',
    institutionName: institution,
    unitId: unit == null ? null : 'unit-${unit.hashCode}',
    unitName: unit,
    groupId: group == null ? null : 'group-${group.hashCode}',
    groupName: group,
    timezone: 'America/Sao_Paulo',
    state: state,
    rule: rule,
    profileRule: profileRule,
    profileName: profileRule?.roleName,
    source: rule != null
        ? StaffAccessSource.own
        : profileRule != null
        ? StaffAccessSource.profile
        : StaffAccessSource.none,
    currentLeave: null,
    leavesCount: leaves.length,
    canManage: true,
    leaves: leaves,
  );
  final year = DateTime.now().year + 1;
  final educadorRule = StaffAccessRule(
    id: 'profile-rule-educador',
    roleId: 'role-educador',
    roleName: 'Educador(a)',
    surfaces: StaffAccessSurface.values.toSet(),
    windows: [
      for (var d = 1; d <= 5; d++) StaffAccessWindow(weekday: d, start: '07:30', end: '18:30'),
    ],
    validFrom: null,
    validUntil: null,
    validitySurfaces: StaffAccessSurface.values.toSet(),
    popupEnabled: true,
    popupShowValidity: false,
    version: 1,
  );
  return [
    item(
      id: 'm-ana',
      name: 'Ana Ribeiro',
      role: 'teacher',
      institution: 'Colégio Horizonte',
      unit: 'Unidade Centro',
      group: 'Turma 3A',
      state: StaffAccessState.schedule,
      profileRule: educadorRule,
      rule: StaffAccessRule(
        id: 'rule-m-ana',
        membershipId: 'm-ana',
        surfaces: const {StaffAccessSurface.web, StaffAccessSurface.mobileWeb},
        windows: const [
          StaffAccessWindow(weekday: 1, start: '07:00', end: '18:00'),
          StaffAccessWindow(weekday: 2, start: '07:00', end: '18:00'),
          StaffAccessWindow(weekday: 3, start: '07:00', end: '12:00'),
          StaffAccessWindow(weekday: 3, start: '14:00', end: '18:00'),
          StaffAccessWindow(weekday: 4, start: '07:00', end: '18:00'),
          StaffAccessWindow(weekday: 5, start: '07:00', end: '18:00'),
        ],
        validFrom: null,
        validUntil: null,
        validitySurfaces: StaffAccessSurface.values.toSet(),
        popupEnabled: true,
        popupShowValidity: false,
        version: 2,
      ),
    ),
    item(
      id: 'm-bruno',
      name: 'Bruno Carvalho',
      role: 'coordinator',
      institution: 'Colégio Horizonte',
      unit: 'Unidade Centro',
      state: StaffAccessState.validity,
      rule: StaffAccessRule(
        id: 'rule-m-bruno',
        membershipId: 'm-bruno',
        surfaces: StaffAccessSurface.values.toSet(),
        windows: const [],
        validFrom: DateTime(year, 2, 1),
        validUntil: DateTime(year, 12, 20),
        validitySurfaces: StaffAccessSurface.values.toSet(),
        popupEnabled: true,
        popupShowValidity: true,
        version: 1,
      ),
    ),
    item(
      id: 'm-carla',
      name: 'Carla Mendes',
      role: 'secretary',
      institution: 'Colégio Horizonte',
      unit: 'Unidade Norte',
      state: StaffAccessState.leave,
      leaves: [
        StaffLeave(
          id: 'leave-carla-1',
          membershipId: 'm-carla',
          startsOn: DateTime(year, 1, 10),
          endsOn: DateTime(year, 1, 24),
          popupEnabled: true,
          internalNote: 'Licença médica',
          version: 1,
        ),
      ],
    ),
    item(
      id: 'm-diego',
      name: 'Diego Santos',
      role: 'teacher',
      institution: 'Escola Aurora',
      unit: 'Sede',
      group: 'Berçário II',
      state: StaffAccessState.schedule,
      profileRule: educadorRule,
    ),
    item(
      id: 'm-elisa',
      name: 'Elisa Prado',
      role: 'institution_admin',
      institution: 'Escola Aurora',
    ),
  ];
}
