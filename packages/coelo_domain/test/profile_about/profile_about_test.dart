import 'package:coelo_domain/profile_about.dart';
import 'package:test/test.dart';

void main() {
  group('ProfileAboutPolicy', () {
    test('requires an institution context for an eligible person profile', () {
      expect(
        () => ProfileAboutSubjectRef(type: ProfileAboutSubjectType.person, personId: 'person-1'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('keeps Bio outside the About domain', () {
      expect(ProfileAboutFieldKey.values.map((key) => key.name), isNot(contains('bio')));
    });

    test('uses a privacy allowlist for each supported subject', () {
      expect(
        ProfileAboutPolicy.allowedFields(ProfileAboutSubjectType.institution),
        containsAll(<ProfileAboutFieldKey>{
          ProfileAboutFieldKey.displayAddress,
          ProfileAboutFieldKey.phone,
          ProfileAboutFieldKey.website,
          ProfileAboutFieldKey.foundedOn,
          ProfileAboutFieldKey.institutionType,
        }),
      );
      expect(
        ProfileAboutPolicy.allowedFields(ProfileAboutSubjectType.unit),
        containsAll(<ProfileAboutFieldKey>{
          ProfileAboutFieldKey.displayAddress,
          ProfileAboutFieldKey.phone,
          ProfileAboutFieldKey.serviceHours,
        }),
      );
      expect(
        ProfileAboutPolicy.allowedFields(ProfileAboutSubjectType.group),
        containsAll(<ProfileAboutFieldKey>{
          ProfileAboutFieldKey.proposal,
          ProfileAboutFieldKey.generalHours,
          ProfileAboutFieldKey.unitLink,
          ProfileAboutFieldKey.activityLinks,
        }),
      );
      expect(
        ProfileAboutPolicy.allowedFields(ProfileAboutSubjectType.activity),
        containsAll(<ProfileAboutFieldKey>{
          ProfileAboutFieldKey.description,
          ProfileAboutFieldKey.objective,
          ProfileAboutFieldKey.generalHours,
          ProfileAboutFieldKey.institutionalLocation,
          ProfileAboutFieldKey.methodology,
          ProfileAboutFieldKey.generalGuidance,
        }),
      );

      final person = ProfileAboutPolicy.allowedFields(ProfileAboutSubjectType.person);
      expect(person, isNot(contains(ProfileAboutFieldKey.displayAddress)));
      expect(person, isNot(contains(ProfileAboutFieldKey.phone)));
      expect(person, isNot(contains(ProfileAboutFieldKey.email)));
      expect(person, isNot(contains(ProfileAboutFieldKey.preciseLocation)));
    });
  });

  test('copies official suggestions once and keeps later edits independent', () {
    const subject = ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.institution,
      institutionId: 'institution-1',
    );
    final page = ProfileAboutPage.empty(subject);
    const suggestion = ProfileAboutSuggestion(
      key: ProfileAboutFieldKey.phone,
      value: '+55 (11) 3250-1234',
      sourceLabel: 'Cadastro oficial',
    );

    final copied = page.copySuggestions(const [suggestion], const {ProfileAboutFieldKey.phone});
    final edited = copied.replaceField(copied.fields.single.copyWith(value: '+55 (11) 99999-0000'));

    expect(copied.fields.single.origin, ProfileAboutOrigin.copiedOfficial);
    expect(edited.fields.single.origin, ProfileAboutOrigin.editedAfterCopy);
    expect(edited.fields.single.value, '+55 (11) 99999-0000');
    expect(suggestion.value, '+55 (11) 3250-1234');
  });

  test('projects only fields and sections authorized for the requested audience', () {
    final page = ProfileAboutPage(
      subject: const ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.unit,
        institutionId: 'institution-1',
        unitId: 'unit-1',
      ),
      version: 2,
      fields: const [
        ProfileAboutField(
          key: ProfileAboutFieldKey.website,
          value: 'https://coelo.me',
          visibility: ProfileAboutVisibility.profileAccess,
        ),
        ProfileAboutField(
          key: ProfileAboutFieldKey.phone,
          value: '+551132501234',
          visibility: ProfileAboutVisibility.linked,
        ),
        ProfileAboutField(
          key: ProfileAboutFieldKey.email,
          value: 'equipe@coelo.me',
          visibility: ProfileAboutVisibility.team,
        ),
        ProfileAboutField(
          key: ProfileAboutFieldKey.serviceHours,
          value: 'Oculto',
          visibility: ProfileAboutVisibility.hidden,
        ),
      ],
      sections: const [
        ProfileAboutSection(
          id: 'history',
          type: ProfileAboutSectionType.text,
          title: 'Nossa histÃ³ria',
          body: 'Texto',
          position: 0,
          visibility: ProfileAboutVisibility.profileAccess,
        ),
        ProfileAboutSection(
          id: 'team',
          type: ProfileAboutSectionType.structuredInfo,
          title: 'Equipe',
          body: 'Texto',
          position: 1,
          visibility: ProfileAboutVisibility.team,
        ),
      ],
    );

    expect(page.project(ProfileAboutAudience.profileAccess).fields, hasLength(1));
    expect(page.project(ProfileAboutAudience.linked).fields, hasLength(2));
    expect(page.project(ProfileAboutAudience.team).fields, hasLength(3));
    expect(page.project(ProfileAboutAudience.profileAccess).sections, hasLength(1));
    expect(page.project(ProfileAboutAudience.team).sections, hasLength(2));
  });

  test('reorders sections stably and supports move up and move down', () {
    final page = ProfileAboutPage(
      subject: const ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.group,
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
      ),
      version: 1,
      fields: const [],
      sections: [
        for (var index = 0; index < 3; index++)
          ProfileAboutSection(
            id: 'section-$index',
            type: ProfileAboutSectionType.text,
            title: 'SeÃ§Ã£o $index',
            body: 'Texto',
            position: index,
          ),
      ],
    );

    final movedDown = page.moveSection('section-0', ProfileAboutMove.down);
    final movedUp = movedDown.moveSection('section-2', ProfileAboutMove.up);

    expect(movedDown.sections.map((section) => section.id), [
      'section-1',
      'section-0',
      'section-2',
    ]);
    expect(movedUp.sections.map((section) => section.id), ['section-1', 'section-2', 'section-0']);
    expect(movedUp.sections.map((section) => section.position), [0, 1, 2]);
  });

  test('location owns coordinates and its single visibility', () {
    const location = ProfileAboutField.location(
      address: 'Rua das Palmeiras, 100',
      latitude: -23.5505,
      longitude: -46.6333,
      visibility: ProfileAboutVisibility.linked,
    );

    expect(location.key, ProfileAboutFieldKey.preciseLocation);
    expect(location.visibility, ProfileAboutVisibility.linked);
    expect(location.isValid, isTrue);
    expect(
      const ProfileAboutField.location(address: 'InvÃ¡lida', latitude: 91, longitude: 0).isValid,
      isFalse,
    );
  });

  test('official update is a separate permissioned decision', () {
    const withoutPermission = ProfileAboutOfficialUpdateRequest(
      field: ProfileAboutFieldKey.phone,
      aboutValue: '+5511999990000',
      canUpdateOfficialData: false,
    );
    const withPermission = ProfileAboutOfficialUpdateRequest(
      field: ProfileAboutFieldKey.phone,
      aboutValue: '+5511999990000',
      canUpdateOfficialData: true,
    );

    expect(withoutPermission.availableDecisions, [ProfileAboutOfficialUpdateDecision.aboutOnly]);
    expect(withPermission.availableDecisions, [
      ProfileAboutOfficialUpdateDecision.aboutOnly,
      ProfileAboutOfficialUpdateDecision.aboutAndOfficial,
    ]);
  });

  test('edits, duplicates, hides and removes editorial sections independently', () {
    final page = ProfileAboutPage(
      subject: const ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.institution,
        institutionId: 'institution',
      ),
      version: 1,
      fields: const [],
      sections: const [
        ProfileAboutSection(
          id: 'history',
          type: ProfileAboutSectionType.text,
          title: 'História',
          body: 'Original',
          position: 0,
        ),
      ],
    );
    final edited = page
        .updateSection(
          'history',
          title: 'Nossa história',
          body: 'Editado',
          visibility: ProfileAboutVisibility.team,
        )
        .duplicateSection('history', 'history-copy')
        .removeSection('history');
    expect(edited.sections, hasLength(1));
    expect(edited.sections.single.id, 'history-copy');
    expect(edited.sections.single.title, 'Nossa história (cópia)');
    expect(edited.sections.single.visibility, ProfileAboutVisibility.team);
  });
}
