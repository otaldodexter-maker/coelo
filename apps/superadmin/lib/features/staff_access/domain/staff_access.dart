/// Acesso contextual de funcionários (ADR 0035, Etapa 3 F7).
///
/// A regra pertence ao vínculo profissional (`institution_memberships`); o
/// servidor decide (staff_access_v1). O cliente só pede, renderiza e informa.
library;

enum StaffAccessSurface {
  web('web', 'Web'),
  mobileWeb('mobile_web', 'Celular (web)'),
  tabletWeb('tablet_web', 'Tablet (web)'),
  installedApp('installed_app', 'App instalado');

  const StaffAccessSurface(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static StaffAccessSurface? fromDatabase(String? value) => switch (value) {
    'web' => StaffAccessSurface.web,
    'mobile_web' => StaffAccessSurface.mobileWeb,
    'tablet_web' => StaffAccessSurface.tabletWeb,
    'installed_app' => StaffAccessSurface.installedApp,
    _ => null,
  };
}

/// Estado do vínculo no diretório (calculado no servidor).
enum StaffAccessState {
  free('free', 'Livre'),
  schedule('schedule', 'Com horário'),
  validity('validity', 'Com vigência'),
  leave('leave', 'Afastado'),
  blockedNow('blocked_now', 'Bloqueado agora');

  const StaffAccessState(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static StaffAccessState fromDatabase(String? value) => switch (value) {
    'schedule' => StaffAccessState.schedule,
    'validity' => StaffAccessState.validity,
    'leave' => StaffAccessState.leave,
    'blocked_now' => StaffAccessState.blockedNow,
    _ => StaffAccessState.free,
  };
}

/// Janela de horário: dia ISO (1 = segunda … 7 = domingo) e "HH:MM"; fim menor
/// ou igual ao início cruza a meia-noite e pertence ao dia de início.
final class StaffAccessWindow {
  const StaffAccessWindow({required this.weekday, required this.start, required this.end});

  final int weekday;
  final String start;
  final String end;

  bool get crossesMidnight => _minutes(end) <= _minutes(start);

  static int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static StaffAccessWindow fromJson(Map<String, dynamic> json) => StaffAccessWindow(
    weekday: (json['weekday'] as num).toInt(),
    start: json['start'] as String,
    end: json['end'] as String,
  );

  Map<String, dynamic> toJson() => {'weekday': weekday, 'start': start, 'end': end};

  static const weekdayLabels = <int, String>{
    1: 'Segunda',
    2: 'Terça',
    3: 'Quarta',
    4: 'Quinta',
    5: 'Sexta',
    6: 'Sábado',
    7: 'Domingo',
  };
  static const weekdayShortLabels = <int, String>{
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  bool operator ==(Object other) =>
      other is StaffAccessWindow &&
      other.weekday == weekday &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(weekday, start, end);
}

final class StaffAccessRule {
  const StaffAccessRule({
    required this.id,
    required this.membershipId,
    required this.surfaces,
    required this.windows,
    required this.validFrom,
    required this.validUntil,
    required this.validitySurfaces,
    required this.popupEnabled,
    required this.popupShowValidity,
    required this.version,
  });

  final String id;
  final String membershipId;
  final Set<StaffAccessSurface> surfaces;
  final List<StaffAccessWindow> windows;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final Set<StaffAccessSurface> validitySurfaces;
  final bool popupEnabled;
  final bool popupShowValidity;
  final int version;

  static StaffAccessRule fromJson(Map<String, dynamic> json) => StaffAccessRule(
    id: json['id'] as String,
    membershipId: json['membership_id'] as String,
    surfaces: _surfaces(json['surfaces']),
    windows: (json['windows'] as List<dynamic>? ?? const [])
        .map((item) => StaffAccessWindow.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false),
    validFrom: _date(json['valid_from']),
    validUntil: _date(json['valid_until']),
    validitySurfaces: _surfaces(json['validity_surfaces']),
    popupEnabled: json['popup_enabled'] == true,
    popupShowValidity: json['popup_show_validity'] == true,
    version: (json['version'] as num?)?.toInt() ?? 1,
  );
}

final class StaffLeave {
  const StaffLeave({
    required this.id,
    required this.membershipId,
    required this.startsOn,
    required this.endsOn,
    required this.popupEnabled,
    required this.internalNote,
    required this.version,
    this.membership,
  });

  final String id;
  final String membershipId;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool popupEnabled;
  final String? internalNote;
  final int version;

  /// Preenchido pelo diretório de afastamentos.
  final StaffAccessItem? membership;

  static StaffLeave fromJson(Map<String, dynamic> json) => StaffLeave(
    id: json['id'] as String,
    membershipId: json['membership_id'] as String,
    startsOn: _date(json['starts_on'])!,
    endsOn: _date(json['ends_on'])!,
    popupEnabled: json['popup_enabled'] == true,
    internalNote: json['internal_note'] as String?,
    version: (json['version'] as num?)?.toInt() ?? 1,
    membership: json['membership'] is Map
        ? StaffAccessItem.fromJson(Map<String, dynamic>.from(json['membership'] as Map))
        : null,
  );
}

/// Uma linha do diretório: o vínculo profissional e sua configuração.
final class StaffAccessItem {
  const StaffAccessItem({
    required this.membershipId,
    required this.personId,
    required this.personName,
    required this.roleCode,
    required this.roleName,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
    required this.timezone,
    required this.state,
    required this.rule,
    required this.currentLeave,
    required this.leavesCount,
    required this.canManage,
    this.leaves = const [],
  });

  final String membershipId;
  final String personId;
  final String personName;
  final String roleCode;
  final String roleName;
  final String institutionId;
  final String institutionName;
  final String? unitId;
  final String? unitName;
  final String? groupId;
  final String? groupName;
  final String timezone;
  final StaffAccessState state;
  final StaffAccessRule? rule;
  final StaffLeave? currentLeave;
  final int leavesCount;
  final bool canManage;

  /// Só no detalhe (`staff_access_rule_get_v1`).
  final List<StaffLeave> leaves;

  String get scopeLabel =>
      [groupName, unitName, institutionName].whereType<String>().join(' · ');

  String get initials {
    final parts = personName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static StaffAccessItem fromJson(Map<String, dynamic> json) => StaffAccessItem(
    membershipId: json['membership_id'] as String,
    personId: json['person_id'] as String,
    personName: json['person_name'] as String? ?? '',
    roleCode: json['role_code'] as String? ?? '',
    roleName: json['role_name'] as String? ?? json['role_code'] as String? ?? '',
    institutionId: json['institution_id'] as String,
    institutionName: json['institution_name'] as String? ?? '',
    unitId: json['unit_id'] as String?,
    unitName: json['unit_name'] as String?,
    groupId: json['group_id'] as String?,
    groupName: json['group_name'] as String?,
    timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
    state: StaffAccessState.fromDatabase(json['state'] as String?),
    rule: json['rule'] is Map
        ? StaffAccessRule.fromJson(Map<String, dynamic>.from(json['rule'] as Map))
        : null,
    currentLeave: json['current_leave'] is Map
        ? StaffLeave.fromJson(Map<String, dynamic>.from(json['current_leave'] as Map))
        : null,
    leavesCount: (json['leaves_count'] as num?)?.toInt() ?? 0,
    canManage: json['can_manage'] == true,
    leaves: (json['leaves'] as List<dynamic>? ?? const [])
        .map((item) => StaffLeave.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false),
  );
}

final class StaffAccessFilterOption {
  const StaffAccessFilterOption({required this.id, required this.label, this.institutionId});
  final String id;
  final String label;
  final String? institutionId;
}

final class StaffAccessFilterOptions {
  const StaffAccessFilterOptions({this.institutions = const [], this.units = const []});
  final List<StaffAccessFilterOption> institutions;
  final List<StaffAccessFilterOption> units;
}

final class StaffAccessQuery {
  const StaffAccessQuery({
    this.search = '',
    this.institutionId,
    this.unitId,
    this.states = const {},
    this.page = 0,
    this.pageSize = 11,
  });

  final String search;
  final String? institutionId;
  final String? unitId;
  final Set<StaffAccessState> states;
  final int page;
  final int pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty || institutionId != null || unitId != null || states.isNotEmpty;

  StaffAccessQuery copyWith({
    String? search,
    String? Function()? institutionId,
    String? Function()? unitId,
    Set<StaffAccessState>? states,
    int? page,
    int? pageSize,
  }) => StaffAccessQuery(
    search: search ?? this.search,
    institutionId: institutionId == null ? this.institutionId : institutionId(),
    unitId: unitId == null ? this.unitId : unitId(),
    states: states ?? this.states,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );
}

final class StaffAccessPage {
  const StaffAccessPage({
    required this.items,
    required this.totalCount,
    required this.page,
    this.filterOptions = const StaffAccessFilterOptions(),
  });
  final List<StaffAccessItem> items;
  final int totalCount;
  final int page;
  final StaffAccessFilterOptions filterOptions;
}

enum StaffLeavePeriod {
  current('current', 'Em curso'),
  upcoming('upcoming', 'Futuros'),
  past('past', 'Encerrados');

  const StaffLeavePeriod(this.databaseValue, this.label);
  final String databaseValue;
  final String label;
}

final class StaffLeaveQuery {
  const StaffLeaveQuery({
    this.search = '',
    this.institutionId,
    this.unitId,
    this.period,
    this.page = 0,
    this.pageSize = 11,
  });
  final String search;
  final String? institutionId;
  final String? unitId;
  final StaffLeavePeriod? period;
  final int page;
  final int pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty || institutionId != null || unitId != null || period != null;

  StaffLeaveQuery copyWith({
    String? search,
    String? Function()? institutionId,
    String? Function()? unitId,
    StaffLeavePeriod? Function()? period,
    int? page,
    int? pageSize,
  }) => StaffLeaveQuery(
    search: search ?? this.search,
    institutionId: institutionId == null ? this.institutionId : institutionId(),
    unitId: unitId == null ? this.unitId : unitId(),
    period: period == null ? this.period : period(),
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );
}

final class StaffLeavePage {
  const StaffLeavePage({required this.items, required this.totalCount, required this.page});
  final List<StaffLeave> items;
  final int totalCount;
  final int page;
}

/// Rascunho enviado ao servidor; `clear` remove a regra (tudo liberado).
final class StaffAccessRuleDraft {
  const StaffAccessRuleDraft({
    required this.surfaces,
    required this.windows,
    required this.validFrom,
    required this.validUntil,
    required this.validitySurfaces,
    required this.popupEnabled,
    required this.popupShowValidity,
    this.clear = false,
  });

  final Set<StaffAccessSurface> surfaces;
  final List<StaffAccessWindow> windows;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final Set<StaffAccessSurface> validitySurfaces;
  final bool popupEnabled;
  final bool popupShowValidity;
  final bool clear;

  Map<String, dynamic> toJson() => clear
      ? {'clear': true}
      : {
          'surfaces': surfaces.map((s) => s.databaseValue).toList(),
          'windows': windows.map((w) => w.toJson()).toList(),
          'valid_from': _dateText(validFrom),
          'valid_until': _dateText(validUntil),
          'validity_surfaces': validitySurfaces.map((s) => s.databaseValue).toList(),
          'popup_enabled': popupEnabled,
          'popup_show_validity': popupShowValidity,
        };
}

final class StaffLeaveDraft {
  const StaffLeaveDraft({
    required this.startsOn,
    required this.endsOn,
    required this.popupEnabled,
    this.internalNote,
    this.remove = false,
  });
  final DateTime startsOn;
  final DateTime endsOn;
  final bool popupEnabled;
  final String? internalNote;
  final bool remove;

  Map<String, dynamic> toJson() => remove
      ? {'remove': true}
      : {
          'starts_on': _dateText(startsOn),
          'ends_on': _dateText(endsOn),
          'popup_enabled': popupEnabled,
          'internal_note': internalNote,
        };
}

abstract interface class StaffAccessRepository {
  Future<StaffAccessPage> fetchPage(StaffAccessQuery query);
  Future<StaffAccessItem> fetchDetail(String membershipId);
  Future<StaffAccessItem> saveRule(String membershipId, int? expectedVersion, StaffAccessRuleDraft draft);
  Future<StaffLeavePage> fetchLeaves(StaffLeaveQuery query);
  Future<StaffLeave?> saveLeave({
    String? leaveId,
    required String membershipId,
    int? expectedVersion,
    required StaffLeaveDraft draft,
  });
}

final class UnavailableStaffAccessRepository implements StaffAccessRepository {
  const UnavailableStaffAccessRepository();

  @override
  Future<StaffAccessPage> fetchPage(StaffAccessQuery query) =>
      Future.error(const StaffAccessUnavailableException());
  @override
  Future<StaffAccessItem> fetchDetail(String membershipId) =>
      Future.error(const StaffAccessUnavailableException());
  @override
  Future<StaffAccessItem> saveRule(String membershipId, int? expectedVersion, StaffAccessRuleDraft draft) =>
      Future.error(const StaffAccessUnavailableException());
  @override
  Future<StaffLeavePage> fetchLeaves(StaffLeaveQuery query) =>
      Future.error(const StaffAccessUnavailableException());
  @override
  Future<StaffLeave?> saveLeave({
    String? leaveId,
    required String membershipId,
    int? expectedVersion,
    required StaffLeaveDraft draft,
  }) => Future.error(const StaffAccessUnavailableException());
}

final class StaffAccessUnauthorizedException implements Exception {
  const StaffAccessUnauthorizedException();
}

/// Versão defasada (PT409 / STAFF_ACCESS_STALE_VERSION): mostrar "Recarregar".
final class StaffAccessConflictException implements Exception {
  const StaffAccessConflictException();
}

final class StaffAccessUnavailableException implements Exception {
  const StaffAccessUnavailableException();
}

final class StaffAccessValidationException implements Exception {
  const StaffAccessValidationException(this.code);
  final String code;
}

Set<StaffAccessSurface> _surfaces(Object? value) => {
  for (final item in (value as List<dynamic>? ?? const []))
    ?StaffAccessSurface.fromDatabase(item as String?),
};

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? _dateText(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// Formata a data como dd/mm/aaaa.
String staffAccessDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
