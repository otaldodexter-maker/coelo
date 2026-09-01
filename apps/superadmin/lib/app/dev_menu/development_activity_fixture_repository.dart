import 'package:coelo_domain/profile_about.dart';

import '../../features/activities/domain/activity_directory.dart';
import '../../features/activities/domain/activity_profile_about_repository.dart';

/// Deterministic local data used only by development routes.
final class DevelopmentActivityFixtureRepository implements ActivityDirectoryRepository {
  DevelopmentActivityFixtureRepository({List<ActivityDetail>? seed})
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
        for (var index = 0; index < _templateNames.length; index++)
          ActivityTemplateOption(
            id: 'template-${index + 1}',
            name: _templateNames[index],
            description: 'Modelo determinístico para ${_templateNames[index].toLowerCase()}.',
            taxonomyId: 'taxonomy-sciences',
            subtypeId: 'subtype-robotics',
            scopeKind: index < 5
                ? ActivityTemplateScopeKind.platform
                : ActivityTemplateScopeKind.institution,
            institutionId: index < 5 ? null : institutionId,
            governance: index.isEven ? ActivityGovernance.optional : ActivityGovernance.mandatory,
            status: index % 4 == 0
                ? ActivityStatus.draft
                : index % 5 == 0
                ? ActivityStatus.inactive
                : ActivityStatus.active,
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
    ('Psicomotricidade', 'Coordenação motora e consciência corporal.'),
    ('Contação de histórias', 'Imaginação, oralidade e vínculo.'),
    ('Educação financeira', 'Escolhas, planejamento e colaboração.'),
    ('Programação', 'Pensamento computacional para crianças.'),
    ('Futebol', 'Prática esportiva e trabalho em equipe.'),
    ('Natação', 'Segurança aquática e desenvolvimento motor.'),
    ('Judô', 'Disciplina, equilíbrio e respeito.'),
    ('Ballet', 'Técnica, musicalidade e expressão.'),
    ('Laboratório maker', 'Experimentação e prototipagem.'),
    ('Clube de ciências', 'Investigação orientada e registro.'),
    ('Espanhol', 'Vivências em língua espanhola.'),
    ('Musicalização', 'Ritmo, escuta e criação coletiva.'),
    ('Educação ambiental', 'Sustentabilidade e cuidado comunitário.'),
    ('Apoio pedagógico', 'Acompanhamento individual de aprendizagem.'),
    ('Brincar livre', 'Autonomia, convivência e imaginação.'),
    ('Fotografia', 'Olhar, composição e narrativa visual.'),
  ];
  const institutions = [
    ('demo-institution-aurora', 'Instituto Aurora'),
    ('demo-institution-horizonte', 'Centro Horizonte'),
    ('demo-institution-pontes', 'Instituição Pontes'),
    ('demo-institution-sementes', 'Sementes do Vale'),
    ('demo-institution-mare-alta', 'Colégio Maré Alta'),
    ('demo-institution-ipe', 'Núcleo Ipê'),
    ('demo-institution-caminhos', 'Escola Caminhos'),
    ('demo-institution-casa-nuvem', 'Casa Nuvem'),
    ('demo-institution-viver', 'Instituto Viver'),
    ('demo-institution-raizes', 'Colégio Raízes'),
    ('demo-institution-bem-te-vi', 'Centro Bem-Te-Vi'),
    ('demo-institution-estacao', 'Escola Estação'),
  ];
  return [
    for (var index = 0; index < names.length; index++)
      _detail(
        id: 'activity-${index + 1}',
        name: names[index].$1,
        description: names[index].$2,
        institution: institutions[index % 5],
        origin: index.isEven ? ActivityOrigin.institution : ActivityOrigin.unit,
        status: ActivityStatus.values[index % ActivityStatus.values.length],
        index: index,
      ),
  ];
}

const _templateNames = [
  'Robótica introdutória',
  'Expressão musical',
  'Movimento e dança',
  'Investigação científica',
  'Leitura compartilhada',
  'Projeto maker',
  'Esporte e convivência',
  'Arte e criação',
  'Idiomas em contexto',
  'Educação ambiental',
  'Cultura e cidadania',
  'Descobertas sensoriais',
];

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

final class DevelopmentActivityProfileAboutRepository implements ActivityProfileAboutRepository {
  final Map<String, ProfileAboutPage> _pages = {};
  final Map<String, String> _requestFingerprints = {};

  @override
  bool get isAvailable => true;

  @override
  Future<ProfileAboutPage> load({required String institutionId, String? activityId}) async {
    final id = activityId ?? 'draft';
    return _pages[id] ??
        ProfileAboutPage.empty(
          ProfileAboutSubjectRef(
            type: ProfileAboutSubjectType.activity,
            institutionId: institutionId,
            activityId: id,
          ),
        );
  }

  @override
  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  }) async {
    final fingerprint = _profileFingerprint(page, activityId);
    final previous = _requestFingerprints[requestId];
    if (previous != null && previous != fingerprint) {
      throw StateError('Conflicting development Profile About replay.');
    }
    _requestFingerprints[requestId] = fingerprint;
    final persisted = page.rebind(
      ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.activity,
        institutionId: institutionId,
        activityId: activityId,
      ),
      version: (_pages[activityId]?.version ?? 0) + 1,
    );
    _pages[activityId] = persisted;
    return persisted;
  }

  String _profileFingerprint(ProfileAboutPage page, String activityId) => [
    activityId,
    for (final field in page.fields) '${field.key.name}:${field.value}:${field.visibility.name}',
    for (final section in page.sections)
      '${section.id}:${section.title}:${section.body}:${section.position}',
  ].join('|');
}
