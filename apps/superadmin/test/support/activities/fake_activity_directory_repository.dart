import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';

/// Deterministic data used only by development previews and visual tests.

class FakeActivityDirectoryRepository implements ActivityDirectoryRepository {
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
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    final institutions = <String, String>{
      for (final detail in _details) detail.item.institutionId: detail.item.institutionName,
    };
    final institutionOptions =
        institutions.entries
            .map((entry) => ActivityFormInstitutionOption(id: entry.key, name: entry.value))
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    return ActivityFormOptions(
      institutions: institutionOptions,
      units: [
        for (final institution in institutionOptions)
          for (final index in [1, 2])
            ActivityFormUnitOption(
              id: '${institution.id}-unit-$index',
              institutionId: institution.id,
              name: index == 1 ? 'Unidade Centro' : 'Unidade Norte',
            ),
      ],
      locations: [
        for (final institution in institutionOptions)
          ActivityFormLocationOption(
            id: '${institution.id}-unit-1-location-1',
            unitId: '${institution.id}-unit-1',
            name: 'Laboratório de informática',
          ),
      ],
      groups: [
        for (final institution in institutionOptions)
          for (final index in [1, 2])
            ActivityFormGroupOption(
              id: '${institution.id}-group-$index',
              unitId: '${institution.id}-unit-${index == 1 ? 1 : 2}',
              name: 'Turma $index',
              participantCount: 14 + index,
            ),
      ],
      professionals: const [
        ActivityFormProfessionalOption(
          id: 'professional-1',
          name: 'Marina Costa',
          role: 'Professora',
        ),
        ActivityFormProfessionalOption(
          id: 'professional-2',
          name: 'Rafael Lima',
          role: 'Administrador',
        ),
      ],
      taxonomy: const [
        ActivityTaxonomyOption(
          id: 'taxonomy-sciences',
          label: 'Ciências e tecnologia',
          subtypes: [ActivityTaxonomySubtypeOption(id: 'subtype-robotics', label: 'Robótica')],
        ),
      ],
      templates: [
        const ActivityTemplateOption(
          id: 'template-robotics',
          name: 'Robótica',
          description: 'Modelo Coelo para atividades de robótica.',
          taxonomyId: 'taxonomy-sciences',
          subtypeId: 'subtype-robotics',
          governance: ActivityGovernance.optional,
        ),
        ActivityTemplateOption(
          id: 'template-robotics-institution',
          name: 'Robótica da instituição',
          description: 'Cópia institucional editável.',
          taxonomyId: 'taxonomy-sciences',
          subtypeId: 'subtype-robotics',
          scopeKind: ActivityTemplateScopeKind.institution,
          institutionId: institutionId,
          governance: ActivityGovernance.mandatory,
        ),
      ],
    );
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    final form = await fetchFormOptions(institutionId: institutionId ?? 'institution-1');
    return ActivityTemplateOptions(
      institutions: form.institutions,
      taxonomy: form.taxonomy,
      templates: form.templates
          .where(
            (template) =>
                template.scopeKind == ActivityTemplateScopeKind.platform ||
                template.institutionId == institutionId,
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async {
    final options = await fetchFormOptions(institutionId: institutionId);
    final normalized = query.trim().toLowerCase();
    return options.professionals
        .where(
          (professional) =>
              normalized.isEmpty || professional.name.toLowerCase().contains(normalized),
        )
        .take(limit.clamp(1, 20))
        .toList(growable: false);
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
          name: 'Turma ${group + 1}',
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
