enum RoutineEntryKind { model, application, launch }

enum RoutineFieldKind { shortText, longText, number, boolean, singleChoice, multipleChoice }

enum RoutineModelStatus { draft, active, inactive, archived }

enum RoutineApplicationStatus { draft, active, inactive, archived }

enum RoutineApplicationResponsibility { record, review, publish }

enum RoutineLaunchStatus { draft, published, corrected, cancelled }

enum RoutineInheritanceMode { inherited, customized }

enum RoutineDirectoryStatus {
  loading,
  data,
  empty,
  noResults,
  failure,
  unauthorized,
  notFound,
  conflict,
}

final class RoutineFieldOption {
  const RoutineFieldOption({required this.id, required this.label, required this.sortOrder});

  final String id;
  final String label;
  final int sortOrder;
}

final class RoutineCondition {
  const RoutineCondition({
    required this.id,
    required this.parentFieldId,
    required this.targetFieldId,
    required this.depth,
    this.optionId,
    this.booleanValue,
  }) : assert((optionId == null) != (booleanValue == null));

  final String id;
  final String parentFieldId;
  final String targetFieldId;
  final String? optionId;
  final bool? booleanValue;
  final int depth;
}

final class RoutineField {
  const RoutineField({
    required this.id,
    required this.label,
    required this.kind,
    required this.sortOrder,
    this.isRequired = false,
    this.initialValue,
    this.minimumValue,
    this.maximumValue,
    this.options = const [],
    this.conditions = const [],
  });

  final String id;
  final String label;
  final RoutineFieldKind kind;
  final int sortOrder;
  final bool isRequired;
  final Object? initialValue;
  final num? minimumValue;
  final num? maximumValue;
  final List<RoutineFieldOption> options;
  final List<RoutineCondition> conditions;

  void validate() {
    if (label.trim().isEmpty) throw const FormatException('Informe o nome do campo.');
    if (minimumValue != null && maximumValue != null && minimumValue! > maximumValue!) {
      throw const FormatException('O valor minimo nao pode superar o valor maximo.');
    }
    if (kind != RoutineFieldKind.number && (minimumValue != null || maximumValue != null)) {
      throw const FormatException('Limites numericos so se aplicam a campos numericos.');
    }
    final optionIds = options.map((option) => option.id).toSet();
    if (optionIds.length != options.length ||
        options.any((option) => option.label.trim().isEmpty)) {
      throw const FormatException('As opcoes devem ter identificadores unicos e rotulos validos.');
    }
    final optionKinds =
        kind == RoutineFieldKind.singleChoice || kind == RoutineFieldKind.multipleChoice;
    if (optionKinds && options.length < 2) {
      throw const FormatException('Cadastre pelo menos duas opcoes.');
    }
    if (!optionKinds && options.isNotEmpty) {
      throw const FormatException('Este tipo de campo nao aceita opcoes.');
    }
    if (initialValue == null) return;
    final valid = switch (kind) {
      RoutineFieldKind.shortText || RoutineFieldKind.longText => initialValue is String,
      RoutineFieldKind.number =>
        initialValue is num &&
            (minimumValue == null || (initialValue! as num) >= minimumValue!) &&
            (maximumValue == null || (initialValue! as num) <= maximumValue!),
      RoutineFieldKind.boolean => initialValue is bool,
      RoutineFieldKind.singleChoice => initialValue is String && optionIds.contains(initialValue),
      RoutineFieldKind.multipleChoice =>
        initialValue is Iterable && (initialValue! as Iterable).every(optionIds.contains),
    };
    if (!valid) throw const FormatException('O valor inicial nao corresponde ao tipo do campo.');
  }
}

final class RoutineSection {
  const RoutineSection({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.fields,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<RoutineField> fields;
}

/// Models are owned by an institution, optionally narrowed to a unit.
/// There is no platform-wide default: authorization always starts with membership.
enum RoutineModelOriginScope { institution, unit }

final class RoutineModel {
  const RoutineModel({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.status,
    required this.sections,
    required this.expectedVersion,
    this.originScope = RoutineModelOriginScope.institution,
    this.institutionId,
    this.originUnitId,
    this.canManage = false,
  });

  final String id;
  final String name;
  final String description;
  final int version;
  final RoutineModelStatus status;
  final List<RoutineSection> sections;
  final int expectedVersion;
  final RoutineModelOriginScope originScope;
  final String? institutionId;
  final String? originUnitId;
  final bool canManage;

  void validate() {
    if (name.trim().isEmpty) throw const FormatException('Informe o nome do modelo.');
    switch (originScope) {
      case RoutineModelOriginScope.institution:
        if (institutionId == null || institutionId!.trim().isEmpty || originUnitId != null) {
          throw const FormatException('Informe a instituicao de origem do modelo.');
        }
      case RoutineModelOriginScope.unit:
        if (institutionId == null ||
            institutionId!.trim().isEmpty ||
            originUnitId == null ||
            originUnitId!.trim().isEmpty) {
          throw const FormatException('Informe a instituicao e a unidade de origem do modelo.');
        }
    }
    final fields = sections.expand((section) => section.fields).toList(growable: false);
    for (final field in fields) {
      field.validate();
    }
    _validateConditionGraph(fields);
  }
}

final class RoutineApplication {
  const RoutineApplication({
    required this.id,
    required this.modelVersionId,
    required this.institutionId,
    required this.status,
    required this.inheritanceMode,
    required this.effectiveVersion,
    required this.expectedVersion,
    this.unitId,
    this.groupId,
    this.parentApplicationId,
    this.activityId,
    this.validFrom,
    this.validUntil,
    this.startsAt,
    this.endsAt,
    this.visibility = 'institution',
    this.assignees = const [],
    this.canManage = false,
  });

  final String id;
  final String modelVersionId;
  final String institutionId;
  final String? unitId;
  final String? groupId;
  final String? parentApplicationId;
  final String? activityId;
  final RoutineApplicationStatus status;
  final RoutineInheritanceMode inheritanceMode;
  final int effectiveVersion;
  final int expectedVersion;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? startsAt;
  final String? endsAt;
  final String visibility;
  final List<RoutineApplicationAssignee> assignees;
  final bool canManage;

  @Deprecated('Use assignees to preserve responsibility.')
  List<String> get assigneeMembershipIds =>
      assignees.map((assignee) => assignee.membershipId).toList(growable: false);

  void validate() {
    if (modelVersionId.trim().isEmpty || institutionId.trim().isEmpty) {
      throw const FormatException(
        'Modelo e instituicao sao obrigatorios para uma rotina aplicada.',
      );
    }
    if (validFrom != null && validUntil != null && validFrom!.isAfter(validUntil!)) {
      throw const FormatException('O inicio da validade nao pode ser posterior ao fim.');
    }
    if (startsAt != null && !_isClockTime(startsAt!)) {
      throw const FormatException('Informe o horario inicial no formato HH:MM.');
    }
    if (endsAt != null && !_isClockTime(endsAt!)) {
      throw const FormatException('Informe o horario final no formato HH:MM.');
    }
    if (startsAt != null && endsAt != null && startsAt!.compareTo(endsAt!) >= 0) {
      throw const FormatException('O horario inicial deve ser anterior ao final.');
    }
    final keys = assignees
        .map((value) => '${value.membershipId}:${value.responsibility.name}')
        .toSet();
    if (keys.length != assignees.length ||
        assignees.any((value) => value.membershipId.trim().isEmpty)) {
      throw const FormatException('Responsaveis devem ser vinculos unicos e validos.');
    }
  }
}

final class RoutineApplicationAssignee {
  const RoutineApplicationAssignee({required this.membershipId, required this.responsibility});

  final String membershipId;
  final RoutineApplicationResponsibility responsibility;
}

final class RoutineAnswerDraft {
  const RoutineAnswerDraft({required this.fieldId, required this.value});
  final String fieldId;
  final Object? value;
}

final class RoutineChildEntryDraft {
  const RoutineChildEntryDraft({
    required this.childContextId,
    required this.childGroupLinkId,
    this.entryId,
    this.status = 'draft',
    this.answers = const [],
  });
  final String? entryId;
  final String childContextId;
  final String childGroupLinkId;
  final String status;
  final List<RoutineAnswerDraft> answers;
}

final class RoutineAnswerCorrection {
  const RoutineAnswerCorrection({required this.answerId, required this.value});
  final String answerId;
  final Object? value;
}

final class RoutineLaunch {
  const RoutineLaunch({
    required this.id,
    required this.applicationId,
    required this.applicationRevisionId,
    required this.institutionId,
    required this.unitId,
    required this.groupId,
    required this.authorMembershipId,
    required this.serviceDate,
    required this.status,
    required this.expectedVersion,
    this.activityId,
    this.children = const [],
    this.canManage = false,
  });
  final String id;
  final String applicationId;
  final String applicationRevisionId;
  final String institutionId;
  final String unitId;
  final String groupId;
  final String? activityId;
  final String authorMembershipId;
  final DateTime serviceDate;
  final RoutineLaunchStatus status;
  final int expectedVersion;
  final List<RoutineChildEntryDraft> children;
  final bool canManage;
}

final class RoutineDirectoryQuery {
  const RoutineDirectoryQuery({
    required this.kind,
    this.search = '',
    this.status,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.page = 1,
    this.pageSize = 20,
  });

  final RoutineEntryKind kind;
  final String search;
  final String? status;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final int page;
  final int pageSize;
}

final class RoutineDirectoryItem {
  const RoutineDirectoryItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.status,
    required this.version,
    this.originLabel,
    this.effectiveLabel,
  });

  final String id;
  final RoutineEntryKind kind;
  final String name;
  final String status;
  final int version;
  final String? originLabel;
  final String? effectiveLabel;
}

final class RoutineDirectoryPage {
  const RoutineDirectoryPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    this.canManage = false,
  });

  final List<RoutineDirectoryItem> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool canManage;
}

abstract interface class RoutineDirectoryRepository {
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query);
}

abstract interface class RoutineDetailRepository {
  Future<RoutineModel> fetchModel(String id);
  Future<RoutineApplication> fetchApplication(String id);
  Future<RoutineLaunch> fetchLaunch(String id);
}

abstract interface class RoutineCommandRepository {
  Future<String> saveModel(RoutineModel model, {required String requestId});
  Future<String> saveApplication(RoutineApplication application, {required String requestId});
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  });
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId});
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  });
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  });
}

abstract interface class RoutineRepository
    implements RoutineDirectoryRepository, RoutineDetailRepository, RoutineCommandRepository {}

final class UnavailableRoutineRepository implements RoutineRepository {
  const UnavailableRoutineRepository([this.message = 'Rotina diaria indisponivel neste ambiente.']);

  final String message;

  Never _unavailable() => throw StateError(message);

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async => _unavailable();

  @override
  Future<RoutineModel> fetchModel(String id) async => _unavailable();

  @override
  Future<RoutineApplication> fetchApplication(String id) async => _unavailable();

  @override
  Future<RoutineLaunch> fetchLaunch(String id) async => _unavailable();

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async => _unavailable();

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async => _unavailable();

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async =>
      _unavailable();

  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async => _unavailable();
}

bool _isClockTime(String value) => RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

void _validateConditionGraph(List<RoutineField> fields) {
  final ids = fields.map((field) => field.id).toSet();
  final edges = <String, List<String>>{};
  for (final field in fields) {
    for (final condition in field.conditions) {
      if (condition.depth < 1 || condition.depth > 4) {
        throw const FormatException('Ramificacoes aceitam no maximo quatro niveis.');
      }
      if (!ids.contains(condition.parentFieldId) || !ids.contains(condition.targetFieldId)) {
        throw const FormatException('A condicao referencia um campo inexistente.');
      }
      (edges[condition.parentFieldId] ??= []).add(condition.targetFieldId);
    }
  }
  final visiting = <String>{};
  final visited = <String>{};
  bool visit(String id) {
    if (visiting.contains(id)) return false;
    if (!visited.add(id)) return true;
    visiting.add(id);
    for (final target in edges[id] ?? const <String>[]) {
      if (!visit(target)) return false;
    }
    visiting.remove(id);
    return true;
  }

  for (final id in ids) {
    if (!visit(id)) throw const FormatException('Ramificacoes nao podem formar ciclos.');
  }
}
