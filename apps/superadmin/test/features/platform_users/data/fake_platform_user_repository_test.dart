import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakePlatformUserRepository', () {
    test('default roster exposes 42 team members with 30 shared identities', () {
      final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
      final repository = FakePlatformUserRepository.content(catalog: catalog);
      final guardianIds = catalog.guardians.map((adult) => adult.id).toSet();

      expect(repository.records, hasLength(42));
      expect(repository.records.map((record) => record.id).toSet(), hasLength(42));
      expect(repository.records.where((record) => guardianIds.contains(record.id)), hasLength(30));
      expect(repository.records.where((record) => !guardianIds.contains(record.id)), hasLength(12));
      expect(
        repository.records.expand((record) => record.membership.scopeIds),
        everyElement(isIn(catalog.institutionIds)),
      );
      for (final record in repository.records.skip(1)) {
        final institution = demoInstitutionRecords.singleWhere(
          (item) => item.id == record.membership.scopeIds.single,
        );
        expect(record.membership.scopeNames.single, institution.publicName);
        expect(
          institution.units.map((unit) => unit.name),
          contains(record.identity.internalFunction),
        );
      }
    });

    test('roster search, filters and pagination operate on linked data', () async {
      final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
      final repository = FakePlatformUserRepository.content(catalog: catalog);
      final target = repository.records[17];

      final search = await repository.fetchPage(
        PlatformUserQuery(search: target.fullName, pageSize: 11),
      );
      final emailSearch = await repository.fetchPage(
        PlatformUserQuery(search: target.email, pageSize: 11),
      );
      final filtered = await repository.fetchPage(
        PlatformUserQuery(
          profileIds: {target.profile.id},
          statuses: {target.status},
          scopes: {target.scope},
          pageSize: 100,
        ),
      );
      final fourthPage = await repository.fetchPage(const PlatformUserQuery(page: 4, pageSize: 11));

      expect(search.items.map((record) => record.id), contains(target.id));
      expect(emailSearch.items.map((record) => record.id), contains(target.id));
      expect(
        filtered.items,
        everyElement(
          isA<PlatformUserRecord>()
              .having((record) => record.profile.id, 'profile', target.profile.id)
              .having((record) => record.status, 'status', target.status)
              .having((record) => record.scope, 'scope', target.scope),
        ),
      );
      expect(fourthPage.totalCount, 42);
      expect(fourthPage.items, hasLength(9));
    });

    test('limited user update accepts every catalog institution', () async {
      final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
      final repository = FakePlatformUserRepository.content(catalog: catalog);
      final target = repository.records.firstWhere(
        (record) => !record.profile.isOwner && record.status != PlatformMembershipStatus.revoked,
      );
      final institutionIds = catalog.institutionIds.toList()..sort();

      final updated = await repository.update(
        target.id,
        PlatformUserDraft(
          identity: target.identity,
          profile: target.profile,
          scope: PlatformUserScope.limited,
          scopeIds: institutionIds,
          scopeNames: institutionIds,
        ),
      );

      expect(updated.membership.scopeIds, institutionIds);
      expect(updated.membership.scopeIds, hasLength(12));
    });

    test('filters own masked identity, profile, membership and scope', () async {
      final repository = FakePlatformUserRepository();
      final source = repository.records.first;

      final page = await repository.fetchPage(
        PlatformUserQuery(
          search: source.maskedEmail,
          profileIds: {source.profile.id},
          statuses: {source.status},
          scopes: {source.scope},
          pageSize: 8,
        ),
      );

      expect(page.items, isNotEmpty);
      expect(page.items.every((item) => item.profile.id == source.profile.id), isTrue);
      expect(page.items.every((item) => item.status == source.status), isTrue);
      expect(page.items.every((item) => item.scope == source.scope), isTrue);
    });

    test('creates separate local identity, membership, invitation and credential', () async {
      final repository = FakePlatformUserRepository();

      final result = await repository.create(_draft());

      expect(result.record.identity.id, isNotEmpty);
      expect(result.record.memberships, hasLength(1));
      expect(result.record.status, PlatformMembershipStatus.invited);
      expect(result.record.invitationStatus, PlatformInvitationStatus.pending);
      expect(result.record.credentialStatus, SuperadminCredentialStatus.noAccess);
      expect(result.record.maskedEmail, 'l***@coelo.me');
      expect(result.invitationSent, isFalse);
      expect(result.message, 'Cadastro salvo.');
    });

    test('normalizes and rejects duplicate CPF', () async {
      final repository = FakePlatformUserRepository();
      await repository.create(_draft());

      expect(
        () => repository.create(_draft(email: 'outra@coelo.me', cpf: '529.982.247-25')),
        throwsA(
          isA<PlatformUserConflictException>().having((error) => error.field, 'field', 'cpf'),
        ),
      );
    });

    test('normalizes and rejects duplicate professional email', () async {
      final repository = FakePlatformUserRepository();
      await repository.create(_draft());

      expect(
        () => repository.create(_draft(email: ' LIA@COELO.ME ', cpf: '11144477735')),
        throwsA(
          isA<PlatformUserConflictException>().having((error) => error.field, 'field', 'email'),
        ),
      );
    });

    test('requires a scope when profile access is limited', () {
      final repository = FakePlatformUserRepository();

      expect(
        () => repository.create(
          _draft(
            profile: PlatformAccessProfiles.values.firstWhere((profile) => !profile.allowsGlobal),
            scope: PlatformUserScope.limited,
            scopeIds: const [],
          ),
        ),
        throwsA(
          isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'scope-required'),
        ),
      );
    });

    test('profile that disallows global blocks global scope', () {
      final repository = FakePlatformUserRepository();
      final limitedProfile = repository.profiles.firstWhere((profile) => !profile.allowsGlobal);

      expect(
        () => repository.create(_draft(profile: limitedProfile, scope: PlatformUserScope.platform)),
        throwsA(
          isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'scope-profile'),
        ),
      );
    });

    test('partially filled address is rejected coherently', () {
      final repository = FakePlatformUserRepository();
      final base = _draft();

      expect(
        () => repository.create(
          PlatformUserDraft(
            identity: base.identity.copyWith(postalCode: '01001-000'),
            profile: base.profile,
            scope: base.scope,
            scopeIds: base.scopeIds,
            scopeNames: base.scopeNames,
          ),
        ),
        throwsA(
          isA<PlatformUserRuleException>().having(
            (error) => error.code,
            'code',
            'address-required',
          ),
        ),
      );
    });

    test('suspension is reversible', () async {
      final repository = FakePlatformUserRepository();
      final active = repository.records.firstWhere(
        (record) => record.status == PlatformMembershipStatus.active && !record.profile.isOwner,
      );

      final suspended = await repository.suspend(active.id);
      final reactivated = await repository.reactivate(active.id);

      expect(suspended.status, PlatformMembershipStatus.suspended);
      expect(reactivated.status, PlatformMembershipStatus.active);
      expect(reactivated.history.last.title, 'Acesso reativado');
    });

    test('revocation is terminal and replacement preserves old cycle', () async {
      final repository = FakePlatformUserRepository();
      final target = repository.records.firstWhere((record) => !record.profile.isOwner);

      final revoked = await repository.revoke(target.id);
      expect(revoked.status, PlatformMembershipStatus.revoked);
      expect(revoked.credentialStatus, SuperadminCredentialStatus.noAccess);
      await expectLater(
        repository.reactivate(target.id),
        throwsA(isA<PlatformUserRuleException>()),
      );

      final replacement = await repository.createReplacementMembership(target.id);
      expect(replacement.memberships, hasLength(revoked.memberships.length + 1));
      expect(replacement.memberships.first.status, PlatformMembershipStatus.revoked);
      expect(replacement.status, PlatformMembershipStatus.invited);
      expect(replacement.invitationStatus, PlatformInvitationStatus.pending);
    });

    test('revoking an invited membership also closes its pending invitation', () async {
      final repository = FakePlatformUserRepository();
      final invited = repository.records.firstWhere(
        (record) => record.status == PlatformMembershipStatus.invited,
      );

      final revoked = await repository.revoke(invited.id);

      expect(revoked.status, PlatformMembershipStatus.revoked);
      expect(revoked.invitationStatus, PlatformInvitationStatus.revoked);
    });

    test('last active Owner is protected by repository commands', () async {
      final repository = FakePlatformUserRepository();
      final owner = repository.records.firstWhere((record) => record.profile.isOwner);

      await expectLater(
        repository.suspend(owner.id),
        throwsA(
          isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'last-owner'),
        ),
      );
      await expectLater(
        repository.revoke(owner.id),
        throwsA(
          isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'last-owner'),
        ),
      );
      await expectLater(
        repository.update(
          owner.id,
          PlatformUserDraft(
            identity: owner.identity,
            profile: repository.profiles.firstWhere((profile) => !profile.isOwner),
            scope: PlatformUserScope.limited,
            scopeIds: const ['institution-1'],
            scopeNames: const ['Instituição 1'],
          ),
        ),
        throwsA(
          isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'last-owner'),
        ),
      );
    });

    test('catalog includes base and custom Superadmin profiles', () {
      final repository = FakePlatformUserRepository();

      expect(repository.profiles.where((profile) => profile.baseRole != null), hasLength(5));
      expect(repository.profiles.any((profile) => profile.baseRole == null), isTrue);
      expect(repository.profiles.every((profile) => profile.permissions.isNotEmpty), isTrue);
      expect(
        repository.records.any(
          (record) => record.invitationStatus == PlatformInvitationStatus.expired,
        ),
        isTrue,
      );
      expect(
        repository.records.any(
          (record) => record.credentialStatus == SuperadminCredentialStatus.recoveryPending,
        ),
        isTrue,
      );
    });

    test('uses eleven cards and eight table rows per page', () {
      expect(PlatformUserQuery.cardsPageSize, 11);
      expect(PlatformUserQuery.tablePageSize, 8);
    });
  });
}

PlatformUserDraft _draft({
  String email = 'lia@coelo.me',
  String cpf = '52998224725',
  PlatformAccessProfile? profile,
  PlatformUserScope scope = PlatformUserScope.limited,
  List<String> scopeIds = const ['institution-1'],
}) => PlatformUserDraft(
  identity: InternalUserIdentity(
    id: '',
    firstName: 'Lia',
    lastName: 'Coelo',
    cpf: cpf,
    professionalEmail: email,
    mobile: '(11) 99999-9999',
    jobTitle: 'Analista',
  ),
  profile: profile ?? PlatformAccessProfiles.values[1],
  scope: scope,
  scopeIds: scopeIds,
  scopeNames: scopeIds.map((id) => id == 'institution-1' ? 'Instituição 1' : id).toList(),
);
