import 'dart:async';

import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_pedagogical_configuration_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wizard exposes the six canonical activity steps in order', () {
    expect(ActivityFormStep.values, [
      ActivityFormStep.identity,
      ActivityFormStep.structure,
      ActivityFormStep.pedagogical,
      ActivityFormStep.links,
      ActivityFormStep.about,
      ActivityFormStep.professionals,
    ]);
  });

  test('pedagogical step validates conditionally and is preserved in the draft', () async {
    final options = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: 'institution-1',
    );
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);
    controller.name.text = 'Robótica';
    await controller.selectInstitution('institution-1');
    controller.toggleUnit('institution-1-unit-1');
    controller.goToStep(ActivityFormStep.pedagogical.index);

    expect(controller.continueFromCurrentStep(), isTrue);
    controller.goToStep(ActivityFormStep.pedagogical.index);
    controller.setPedagogicalConfiguration(
      const ActivityPedagogicalConfigurationDraft(
        enabled: true,
        model: ActivityAssessmentModel.gradeOnly,
      ),
    );

    expect(controller.continueFromCurrentStep(), isFalse);
    expect(controller.pedagogicalError, isNotNull);
    expect(controller.toDraft().pedagogicalConfiguration.enabled, isTrue);
  });

  test(
    'draft requires name institution and one unit while completion also requires a group',
    () async {
      final options = await FakeActivityDirectoryRepository().fetchFormOptions(
        institutionId: 'institution-1',
      );
      final controller = ActivityFormController.create(options);
      addTearDown(controller.dispose);

      expect(controller.validateDraft(), isFalse);
      controller.name.text = 'Robótica';
      controller.selectInstitution('institution-1');
      controller.toggleUnit('institution-1-unit-1');

      expect(controller.validateDraft(), isTrue);
      expect(controller.validateCompletion(), isFalse);

      controller.toggleGroup('institution-1-group-1');
      expect(controller.validateCompletion(), isTrue);
      expect(
        controller.toDraft().groupParticipation['institution-1-group-1'],
        ActivityParticipation.all,
      );
    },
  );

  test('taxonomy templates are chained and Other keeps a custom value', () async {
    final base = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: 'institution-1',
    );
    final options = _withTaxonomy(base);
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);

    controller.selectTaxonomy(_languagesTaxonomy);
    expect(controller.activityTemplates.map((item) => item.name), ['Inglês']);
    controller.selectTemplate(_englishTemplate);
    expect(controller.activityLabel, 'Inglês');
    controller.selectTaxonomy(_otherTaxonomy);
    controller.otherActivity.text = 'Espanhol';

    expect(controller.activityLabel, 'Espanhol');
  });

  test('create preselects a real template and its taxonomy by id', () async {
    final base = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: 'institution-1',
    );
    final options = _withTaxonomy(base);
    final controller = ActivityFormController.create(options, initialTemplateId: 'english');
    addTearDown(controller.dispose);

    expect(controller.taxonomy, _languagesTaxonomy);
    expect(controller.template, _englishTemplate);
    expect(controller.name.text, 'Inglês');
    expect(controller.description.text, 'Conversação guiada');
    expect(controller.governance, ActivityGovernance.fixed);
    controller.selectGovernance(ActivityGovernance.optional);
    expect(controller.governance, ActivityGovernance.optional);
  });

  test(
    'create scopes relations after institution selection without losing template fields',
    () async {
      const catalog = ActivityFormOptions(
        institutions: [
          ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte'),
          ActivityFormInstitutionOption(id: 'institution-2', name: 'Casa Nuvem'),
        ],
        taxonomy: [_languagesTaxonomy],
        templates: [_englishTemplate],
      );
      final controller = ActivityFormController.create(
        catalog,
        initialTemplateId: 'english',
        loadScopedOptions: (institutionId) async => ActivityFormOptions(
          institutions: catalog.institutions,
          units: [
            ActivityFormUnitOption(
              id: '$institutionId-unit-1',
              institutionId: institutionId,
              name: 'Unidade Centro',
            ),
          ],
          taxonomy: catalog.taxonomy,
          templates: catalog.templates,
        ),
      );
      addTearDown(controller.dispose);

      await controller.selectInstitution('institution-2');

      expect(controller.name.text, 'Inglês');
      expect(controller.description.text, 'Conversação guiada');
      expect(controller.template, _englishTemplate);
      expect(controller.options.institutions, hasLength(2));
      expect(controller.units.single.id, 'institution-2-unit-1');
      expect(controller.scopedOptionsLoading, isFalse);
      expect(controller.scopedOptionsError, isNull);
    },
  );

  test('create exposes an honest scoped-options error', () async {
    const catalog = ActivityFormOptions(
      institutions: [ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte')],
    );
    final controller = ActivityFormController.create(
      catalog,
      loadScopedOptions: (_) => Future.error(const ActivityDirectoryUnavailableException()),
    );
    addTearDown(controller.dispose);

    await controller.selectInstitution('institution-1');

    expect(controller.scopedOptionsLoading, isFalse);
    expect(controller.scopedOptionsError, isNotNull);
    expect(controller.units, isEmpty);
  });

  test('catalog failure stays local and retry preserves typed draft values', () async {
    var attempts = 0;
    final controller = ActivityFormController.create(
      const ActivityFormOptions(
        institutions: [ActivityFormInstitutionOption(id: 'institution-1', name: 'A')],
      ),
      initialTemplateId: 'english',
      initialCatalogError: 'Catálogo indisponível.',
      loadTemplateOptions: (_) async {
        attempts++;
        return const ActivityTemplateOptions(
          institutions: [ActivityFormInstitutionOption(id: 'institution-1', name: 'A')],
          taxonomy: [_languagesTaxonomy],
          templates: [_englishTemplate],
        );
      },
    );
    addTearDown(controller.dispose);
    controller.name.text = 'Nome digitado';

    expect(controller.catalogOptionsError, isNotNull);
    expect(controller.options.institutions, hasLength(1));
    await controller.retryCatalogOptions();

    expect(attempts, 1);
    expect(controller.catalogOptionsError, isNull);
    expect(controller.catalogOptionsLoading, isFalse);
    expect(controller.name.text, 'Nome digitado');
    expect(controller.template, _englishTemplate);
    expect(controller.taxonomy, _languagesTaxonomy);
  });

  test('catalog retry preserves unauthorized as a global failure signal', () async {
    final controller = ActivityFormController.create(
      const ActivityFormOptions(),
      initialCatalogError: 'Catálogo indisponível.',
      loadTemplateOptions: (_) => Future.error(const ActivityDirectoryUnauthorizedException()),
    );
    addTearDown(controller.dispose);

    expect(
      controller.retryCatalogOptions(),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.catalogOptionsLoading, isFalse);
  });

  test('scoped options ignore a stale A to B to A response', () async {
    const catalog = ActivityFormOptions(
      institutions: [
        ActivityFormInstitutionOption(id: 'institution-a', name: 'A'),
        ActivityFormInstitutionOption(id: 'institution-b', name: 'B'),
      ],
    );
    final requests = <String, List<Completer<ActivityFormOptions>>>{};
    final controller = ActivityFormController.create(
      catalog,
      loadScopedOptions: (institutionId) {
        final completer = Completer<ActivityFormOptions>();
        (requests[institutionId] ??= []).add(completer);
        return completer.future;
      },
    );
    addTearDown(controller.dispose);

    final firstA = controller.selectInstitution('institution-a');
    final requestB = controller.selectInstitution('institution-b');
    final latestA = controller.selectInstitution('institution-a');
    requests['institution-a']![1].complete(
      const ActivityFormOptions(
        units: [
          ActivityFormUnitOption(
            id: 'unit-a-latest',
            institutionId: 'institution-a',
            name: 'A atual',
          ),
        ],
      ),
    );
    await latestA;
    requests['institution-a']!.first.complete(
      const ActivityFormOptions(
        units: [
          ActivityFormUnitOption(
            id: 'unit-a-stale',
            institutionId: 'institution-a',
            name: 'A antiga',
          ),
        ],
      ),
    );
    requests['institution-b']!.single.complete(const ActivityFormOptions());
    await Future.wait([firstA, requestB]);

    expect(controller.units.single.id, 'unit-a-latest');
    expect(controller.scopedOptionsLoading, isFalse);
  });

  test('professional search returns no stale result and does not mutate options', () async {
    final requests = <String, Completer<List<ActivityFormProfessionalOption>>>{};
    final controller = ActivityFormController.create(
      const ActivityFormOptions(
        institutions: [ActivityFormInstitutionOption(id: 'institution-1', name: 'A')],
      ),
      initialInstitutionId: 'institution-1',
      professionalSearcher: (institutionId, query) {
        final completer = Completer<List<ActivityFormProfessionalOption>>();
        requests[query] = completer;
        return completer.future;
      },
    );
    addTearDown(controller.dispose);

    final stale = controller.searchProfessionals('mar');
    final latest = controller.searchProfessionals('maria');
    requests['maria']!.complete(const [
      ActivityFormProfessionalOption(id: 'membership-latest', name: 'Maria Atual', role: 'teacher'),
    ]);
    final latestResults = await latest;
    controller.acceptProfessionalResults(latestResults);
    requests['mar']!.complete(const [
      ActivityFormProfessionalOption(id: 'membership-stale', name: 'Maria Antiga', role: 'teacher'),
    ]);

    expect(await stale, isEmpty);
    expect(controller.options.professionals.map((item) => item.id), ['membership-latest']);
  });

  test('identity fallback and student participation are preserved in the draft', () async {
    final base = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: 'institution-1',
    );
    final options = _withStudents(base);
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);

    controller.name.text = 'Robótica';
    controller.selectInstitution('institution-1');
    controller.toggleUnit('institution-1-unit-1');
    controller.toggleGroup('institution-1-group-1');
    controller.initials.text = 'RB';
    controller.setIdentityColor('#123456');
    controller.selectIdentityIcon(ActivityIdentityIcon.science);
    controller.setGroupParticipation('institution-1-group-1', ActivityParticipation.selected);
    controller.setStudentIncluded('child-group-link-1', false);

    final draft = controller.toDraft();
    expect(draft.identityInitials, 'RB');
    expect(draft.identityColor, '#123456');
    expect(draft.identityIcon, ActivityIdentityIcon.science);
    expect(draft.groupParticipation['institution-1-group-1'], ActivityParticipation.selected);
    expect(
      draft.studentSelections.single,
      isA<ActivityStudentSelection>()
          .having((item) => item.groupId, 'groupId', 'institution-1-group-1')
          .having((item) => item.childGroupLinkId, 'childGroupLinkId', 'child-group-link-1')
          .having((item) => item.belongs, 'belongs', isFalse),
    );
  });

  test('unit changes prune groups locations and professional assignments', () async {
    final options = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: 'institution-1',
    );
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);
    controller.selectInstitution('institution-1');
    controller.toggleUnit('institution-1-unit-1');
    controller.toggleGroup('institution-1-group-1');
    controller.selectLocation('institution-1-unit-1-location-1');
    controller.toggleProfessional('institution-1-group-1', 'professional-1');
    controller.toggleProfessional(
      null,
      'professional-2',
      role: ActivityAssignmentRole.activityAdmin,
    );

    final instructor = controller.assignments.firstWhere(
      (item) => item.role == ActivityAssignmentRole.instructor,
    );
    expect(instructor.permissions.happens, ActivityProfessionalAccess.both);
    expect(instructor.permissions.now, ActivityProfessionalAccess.both);
    expect(instructor.permissions.moments, ActivityProfessionalAccess.both);
    expect(instructor.permissions.chat, ActivityProfessionalAccess.both);
    expect(instructor.permissions.attendance, ActivityProfessionalAccess.both);
    final admin = controller.assignments.firstWhere(
      (item) => item.role == ActivityAssignmentRole.activityAdmin,
    );
    expect(admin.groupId, isNull);

    controller.setPermission(
      'institution-1-group-1',
      'professional-1',
      chat: ActivityProfessionalAccess.view,
    );
    expect(
      controller.assignments
          .firstWhere((item) => item.role == ActivityAssignmentRole.instructor)
          .permissions
          .chat,
      ActivityProfessionalAccess.view,
    );

    controller.toggleUnit('institution-1-unit-1');
    expect(controller.selectedGroupIds, isEmpty);
    expect(controller.selectedLocationId, isNull);
    expect(controller.assignments, [admin]);
  });

  test('edit keeps institution fixed and preserves fixed governance', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions(institutionId: 'institution-1');
    final detail = await repository.fetchById('activity-3');
    final controller = ActivityFormController.edit(options, detail!);
    addTearDown(controller.dispose);

    expect(controller.institutionLocked, isTrue);
    expect(controller.governance, ActivityGovernance.fixed);
    final institution = controller.selectedInstitutionId;
    controller.selectInstitution('institution-2');
    expect(controller.selectedInstitutionId, institution);
  });

  test('edit hydrates the complete presentation draft without replacing relationships', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions(institutionId: 'institution-1');
    final detail = await repository.fetchById('activity-3');
    final initialDraft = ActivityFormDraft(
      name: detail!.item.name,
      description: detail.item.description ?? '',
      taxonomy: _sciencesTaxonomy,
      subtype: _roboticsSubtype,
      template: _roboticsTemplate,
      taxonomyOtherDescription: '',
      governance: detail.item.governance,
      institutionId: detail.item.institutionId,
      unitIds: {'institution-3-unit-2'},
      groupIds: {'institution-3-group-2'},
      assignments: const [
        ActivityProfessionalAssignment(
          groupId: 'institution-3-group-2',
          professionalId: 'professional-2',
          permissions: ActivityProfessionalPermissions(chat: ActivityProfessionalAccess.none),
        ),
      ],
      imageName: 'robotica.png',
    );

    final controller = ActivityFormController.edit(options, detail, initialDraft: initialDraft);
    addTearDown(controller.dispose);

    expect(controller.taxonomy, _sciencesTaxonomy);
    expect(controller.subtype, _roboticsSubtype);
    expect(controller.template, _roboticsTemplate);
    expect(controller.activityLabel, 'Rob\u00f3tica');
    expect(controller.selectedUnitIds, initialDraft.unitIds);
    expect(controller.selectedGroupIds, initialDraft.groupIds);
    expect(controller.assignments.single.permissions.chat, ActivityProfessionalAccess.none);
    expect(controller.imageName, 'robotica.png');
    expect(controller.isDirty, isFalse);
  });

  test('edit hydrates the complete remote detail without an in-memory draft', () async {
    final repository = FakeActivityDirectoryRepository();
    final baseOptions = await repository.fetchFormOptions(institutionId: 'institution-1');
    final baseDetail = (await repository.fetchById('activity-3'))!;
    final options = _withRemoteEditOptions(baseOptions);
    final detail = ActivityDetail(
      item: baseDetail.item,
      createdAt: baseDetail.createdAt,
      archivedAt: baseDetail.archivedAt,
      originUnitName: baseDetail.originUnitName,
      units: baseDetail.units,
      groups: [
        for (final group in baseDetail.groups)
          ActivityGroupLink(
            id: group.id,
            name: group.name,
            unitName: group.unitName,
            status: group.status,
            participation: ActivityParticipation.selected,
            assigneeCount: group.assigneeCount,
            participantCount: group.participantCount,
          ),
      ],
      taxonomyId: 'sciences',
      subtypeId: 'robotics',
      templateId: 'robotics-template',
      taxonomyOtherDescription: 'preservado',
      identity: const ActivityDetailIdentity(
        kind: ActivityDetailIdentityKind.photo,
        initials: 'RB',
        color: '#123456',
        icon: 'science',
        storageRef: ActivityIdentityStorageRef(
          bucket: 'coelo-identities',
          path: 'activities/activity-3/profile.webp',
        ),
      ),
      participants: const [
        ActivityDetailParticipant(
          groupId: 'institution-3-group-1',
          childGroupLinkId: 'child-group-link-3',
          belongs: false,
        ),
      ],
      professionalAssignments: const [
        ActivityDetailProfessionalAssignment(
          groupId: 'institution-3-group-1',
          membershipId: 'professional-2',
          role: ActivityDetailProfessionalRole.instructor,
          capabilities: {'now': 'view', 'chat': 'none'},
        ),
        ActivityDetailProfessionalAssignment(
          groupId: null,
          membershipId: 'professional-1',
          role: ActivityDetailProfessionalRole.activityAdmin,
          capabilities: {'chat': 'both'},
        ),
      ],
      pedagogicalConfiguration: {
        'enabled': false,
        'model': 'none',
        'timezone': 'America/Sao_Paulo',
        'concept_levels': <Object?>[],
        'periods': <Object?>[],
        'instruments': <Object?>[],
        'categories': <Object?>[],
        'recovery_rule': 'none',
        'expected_version': 4,
        'used_by_results': false,
        'change_justification': '',
      },
    );

    final controller = ActivityFormController.edit(options, detail);
    addTearDown(controller.dispose);

    expect(controller.taxonomy, _sciencesTaxonomy);
    expect(controller.subtype, _roboticsSubtype);
    expect(controller.template, _roboticsRemoteTemplate);
    expect(controller.otherActivity.text, 'preservado');
    expect(controller.initials.text, 'RB');
    expect(controller.identityColor, '#123456');
    expect(controller.identityIcon, ActivityIdentityIcon.science);
    expect(controller.identityStorageRef?.path, 'activities/activity-3/profile.webp');
    expect(controller.selectedUnitIds, isNotEmpty);
    expect(controller.selectedGroupIds, {'institution-3-group-1'});
    expect(controller.groupParticipation['institution-3-group-1'], ActivityParticipation.selected);
    expect(controller.studentSelection['child-group-link-3'], isFalse);
    expect(controller.assignments, hasLength(2));
    final instructor = controller.assignments.firstWhere(
      (item) => item.role == ActivityAssignmentRole.instructor,
    );
    expect(instructor.permissions.now, ActivityProfessionalAccess.view);
    expect(instructor.permissions.chat, ActivityProfessionalAccess.none);
    expect(
      controller.assignments
          .firstWhere((item) => item.role == ActivityAssignmentRole.activityAdmin)
          .groupId,
      isNull,
    );
    final draft = controller.toDraft();
    expect(draft.identityStorageRef, detail.identity.storageRef);
    expect(draft.studentSelections, hasLength(1));
    expect(draft.assignments, hasLength(2));
    expect(draft.pedagogicalConfiguration.expectedVersion, 4);
    expect(controller.isDirty, isFalse);
  });

  test('edit tolerates null taxonomy while preserving remote links', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions(institutionId: 'institution-1');
    final baseDetail = (await repository.fetchById('activity-3'))!;
    final detail = ActivityDetail(
      item: baseDetail.item,
      createdAt: baseDetail.createdAt,
      units: baseDetail.units,
      groups: baseDetail.groups,
    );

    final controller = ActivityFormController.edit(options, detail);
    addTearDown(controller.dispose);

    expect(controller.taxonomy, isNull);
    expect(controller.selectedUnitIds, isNotEmpty);
    expect(controller.selectedGroupIds, isNotEmpty);
    expect(controller.toDraft().unitIds, isNotEmpty);
    expect(controller.toDraft().groupIds, isNotEmpty);
  });
}

const _languagesTaxonomy = ActivityTaxonomyOption(id: 'languages', label: 'Idiomas');
const _otherTaxonomy = ActivityTaxonomyOption(id: 'other', label: 'Outros', isOther: true);
const _roboticsSubtype = ActivityTaxonomySubtypeOption(id: 'robotics', label: 'Robótica');
const _sciencesTaxonomy = ActivityTaxonomyOption(
  id: 'sciences',
  label: 'Ciências',
  subtypes: [_roboticsSubtype],
);
const _englishTemplate = ActivityTemplateOption(
  id: 'english',
  name: 'Inglês',
  taxonomyId: 'languages',
  description: 'Conversação guiada',
  governance: ActivityGovernance.fixed,
);
const _roboticsTemplate = ActivityTemplateOption(
  id: 'robotics',
  name: 'Robótica',
  taxonomyId: 'sciences',
  subtypeId: 'robotics',
);
const _roboticsRemoteTemplate = ActivityTemplateOption(
  id: 'robotics-template',
  name: 'Robótica avançada',
  taxonomyId: 'sciences',
  subtypeId: 'robotics',
);

ActivityFormOptions _withTaxonomy(ActivityFormOptions base) => ActivityFormOptions(
  institutions: base.institutions,
  units: base.units,
  locations: base.locations,
  groups: base.groups,
  professionals: base.professionals,
  students: base.students,
  taxonomy: const [_languagesTaxonomy, _sciencesTaxonomy, _otherTaxonomy],
  templates: const [_englishTemplate, _roboticsTemplate],
);

ActivityFormOptions _withStudents(ActivityFormOptions base) => ActivityFormOptions(
  institutions: base.institutions,
  units: base.units,
  locations: base.locations,
  groups: base.groups,
  professionals: base.professionals,
  students: const [
    ActivityFormStudentOption(
      childGroupLinkId: 'child-group-link-1',
      id: 'child-1',
      groupId: 'institution-1-group-1',
      name: 'Ana Silva',
      age: 8,
      gender: 'Feminino',
    ),
  ],
  taxonomy: base.taxonomy,
  templates: base.templates,
);

ActivityFormOptions _withRemoteEditOptions(ActivityFormOptions base) => ActivityFormOptions(
  institutions: base.institutions,
  units: base.units,
  locations: base.locations,
  groups: base.groups,
  professionals: base.professionals,
  students: const [
    ActivityFormStudentOption(
      childGroupLinkId: 'child-group-link-3',
      id: 'child-3',
      groupId: 'institution-3-group-1',
      name: 'Ana Silva',
    ),
  ],
  taxonomy: const [_sciencesTaxonomy],
  templates: const [_roboticsRemoteTemplate],
);
