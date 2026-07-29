import '../domain/activity_directory.dart';

final class FakeActivityDirectoryRepository implements ActivityDirectoryRepository {
  FakeActivityDirectoryRepository({List<ActivityDetail>? seed})
    : _details = seed ?? _seedActivities();

  final List<ActivityDetail> _details;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    final search = _normalized(query.search);
    final filtered =
        _details
            .map((detail) => detail.item)
            .where(
              (item) =>
                  (search.isEmpty ||
                      _normalized(item.name).contains(search) ||
                      _normalized(item.description ?? '').contains(search)) &&
                  (query.institutionIds.isEmpty ||
                      query.institutionIds.contains(item.institutionId)) &&
                  (query.statuses.isEmpty || query.statuses.contains(item.status)) &&
                  (query.origins.isEmpty || query.origins.contains(item.origin)),
            )
            .toList()
          ..sort((left, right) {
            final result = left.name.toLowerCase().compareTo(right.name.toLowerCase());
            return query.sortAscending ? result : -result;
          });
    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return ActivityDirectoryResult(
      items: filtered.sublist(start, end),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    final institutions = <String, String>{
      for (final detail in _details) detail.item.institutionId: detail.item.institutionName,
    };
    final options =
        institutions.entries
            .map((entry) => ActivityFilterOption(id: entry.key, label: entry.value))
            .toList()
          ..sort((left, right) => left.label.compareTo(right.label));
    return ActivityFilterOptions(institutions: options);
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions() async {
    final institutions = <String, String>{
      for (final detail in _details)
        detail.item.institutionId: detail.item.institutionName,
    };
    final institutionOptions = institutions.entries
        .map(
          (entry) =>
              ActivityFormInstitutionOption(id: entry.key, name: entry.value),
        )
        .toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return ActivityFormOptions(
      institutions: institutionOptions,
      units: [
        for (final institution in institutionOptions)
          ActivityFormUnitOption(
            id: '${institution.id}-unit-1',
            institutionId: institution.id,
            name: 'Unidade Centro',
          ),
      ],
    );
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) async {
    for (final detail in _details) {
      if (detail.item.id == activityId) return detail;
    }
    return null;
  }
}

List<ActivityDetail> _seedActivities() {
  const names = [
    ('Música', 'Prática musical e expressão sonora.'),
    ('Dança', 'Movimento e expressão corporal.'),
    ('Capoeira', 'Cultura, movimento e musicalidade.'),
    ('Biologia', 'Observação e investigação da vida.'),
    ('Robótica', 'Construção e raciocínio lógico.'),
    ('Teatro', 'Expressão cênica e colaboração.'),
    ('Xadrez', 'Estratégia e tomada de decisão.'),
    ('Reforço de matemática', 'Acompanhamento de aprendizagem.'),
    ('Inglês', 'Vivências em língua inglesa.'),
    ('Artes visuais', 'Criação com diferentes materiais.'),
    ('Horta', 'Cuidado e educação ambiental.'),
    ('Circo', 'Equilíbrio, coordenação e expressão.'),
    ('Culinária', 'Experiências alimentares orientadas.'),
    ('Leitura', 'Mediação e formação leitora.'),
  ];
  const institutions = [
    ('institution-1', 'Casa Nuvem'),
    ('institution-2', 'Centro Bem-Te-Vi'),
    ('institution-3', 'Colégio Maré Alta'),
  ];
  return [
    for (var index = 0; index < names.length; index++)
      _detail(
        id: 'activity-${index + 1}',
        name: names[index].$1,
        description: names[index].$2,
        institution: institutions[index % institutions.length],
        origin: index.isEven ? ActivityOrigin.institution : ActivityOrigin.unit,
        status: ActivityStatus.values[index % ActivityStatus.values.length],
        index: index,
      ),
  ];
}

ActivityDetail _detail({
  required String id,
  required String name,
  required String description,
  required (String, String) institution,
  required ActivityOrigin origin,
  required ActivityStatus status,
  required int index,
}) {
  final unitCount = index % 3 + 1;
  final groupCount = index % 4 + 1;
  final updatedAt = DateTime.utc(2026, 7, 29, 12, index);
  final item = ActivityDirectoryItem(
    id: id,
    institutionId: institution.$1,
    institutionName: institution.$2,
    name: name,
    description: description,
    status: status,
    origin: origin,
    distribution: origin == ActivityOrigin.institution
        ? ActivityDistribution.institutionStandard
        : ActivityDistribution.unitLocal,
    governance: ActivityGovernance.values[index % ActivityGovernance.values.length],
    activeUnitCount: unitCount,
    activeGroupCount: groupCount,
    updatedAt: updatedAt,
  );
  return ActivityDetail(
    item: item,
    createdAt: updatedAt.subtract(const Duration(days: 60)),
    archivedAt: status == ActivityStatus.archived ? updatedAt : null,
    originUnitName: origin == ActivityOrigin.unit ? 'Unidade Centro' : null,
    units: [
      for (var unit = 0; unit < unitCount; unit++)
        ActivityUnitLink(
          id: '$id-unit-$unit',
          name: unit == 0 ? 'Unidade Centro' : 'Unidade ${unit + 1}',
          status: ActivityStatus.active,
          startsAt: updatedAt.subtract(const Duration(days: 30)),
        ),
    ],
    groups: [
      for (var group = 0; group < groupCount; group++)
        ActivityGroupLink(
          id: '$id-group-$group',
          name: 'Grupo ${group + 1}',
          unitName: 'Unidade Centro',
          status: ActivityStatus.active,
          participation: group.isEven ? ActivityParticipation.all : ActivityParticipation.selected,
          assigneeCount: group + 1,
          participantCount: 12 + group,
        ),
    ],
  );
}

String _normalized(String value) => value.trim().toLowerCase();
