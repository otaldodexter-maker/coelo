import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_people.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships fifteen deterministic institutions with valid hierarchy', () {
    final repository = FakeInstitutionDirectoryRepository();

    expect(repository.records, hasLength(15));
    expect(repository.records.map((record) => record.id).toSet(), hasLength(15));
    for (final record in repository.records) {
      expect(record.units.length, inInclusiveRange(1, 4));
      expect(record.units.expand((unit) => unit.groups), isNotEmpty);
      for (final unit in record.units) {
        expect(unit.groups.length, inInclusiveRange(1, 40));
      }
      expect(record.directoryItem.unitsCount, record.units.length);
      expect(
        record.directoryItem.groupsCount,
        record.units.fold<int>(0, (total, unit) => total + unit.groups.length),
      );
    }
  });

  test('finds and upserts a record in memory', () async {
    final repository = FakeInstitutionDirectoryRepository();
    final original = repository.findById('demo-institution-aurora')!;

    await repository.upsert(original.copyWith(publicName: 'Instituto Aurora Atualizado'));

    expect(
      repository.findById('demo-institution-aurora')!.publicName,
      'Instituto Aurora Atualizado',
    );
    final page = await repository.fetchPage(InstitutionDirectoryQuery(search: 'Aurora Atualizado'));
    expect(page.items.single.id, 'demo-institution-aurora');
  });

  test('fetches by id and throws not found when missing', () async {
    final repository = FakeInstitutionDirectoryRepository();

    final found = await repository.fetchById('demo-institution-aurora');
    expect(found.id, 'demo-institution-aurora');
    await expectLater(
      repository.fetchById('nao-existe'),
      throwsA(isA<InstitutionDirectoryNotFoundException>()),
    );
  });

  test('creates with deterministic id when blank and increments version', () async {
    final repository = FakeInstitutionDirectoryRepository(records: const []);
    final created = await repository.create(
      _recordForTest(id: '', slug: 'instituicao-nova', version: 0),
    );

    expect(created.id, 'local-institution-instituicao-nova');
    expect(created.version, 1);
    expect(await repository.fetchById('local-institution-instituicao-nova'), isNotNull);
  });

  test('updates with optimistic version and returns conflict on mismatch', () async {
    final base = _recordForTest(id: 'inst-1', version: 3);
    final repository = FakeInstitutionDirectoryRepository(records: [base]);

    final updated = await repository.update(
      base.copyWith(publicName: 'Atualizada'),
      expectedVersion: 3,
    );
    expect(updated.version, 4);
    expect(updated.publicName, 'Atualizada');

    await expectLater(
      repository.update(base.copyWith(publicName: 'Falha'), expectedVersion: 2),
      throwsA(isA<InstitutionDirectoryConflictException>()),
    );
  });

  test('blocks unsupported relationship payloads', () async {
    final repository = FakeInstitutionDirectoryRepository(records: const []);
    final record = _recordForTest(
      administrators: const [
        InstitutionAdministratorDraft(
          id: 'admin-1',
          person: InstitutionPersonDraft(
            firstName: 'Ana',
            lastName: 'Silva',
            displayName: 'Ana Silva',
          ),
          handle: '@ana',
          level: InstitutionAdministratorLevel.adminMaster,
          invitationStatus: InstitutionInvitationStatus.accepted,
          invitationHistory: [],
        ),
      ],
    );

    await expectLater(
      repository.create(record),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
    await expectLater(
      repository.update(record.copyWith(id: 'inst-1'), expectedVersion: 1),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
  });

  test('reserves institution and administrator handles globally, except one institution', () {
    final aurora = demoInstitutionRecords.first.copyWith(
      administrators: const [
        InstitutionAdministratorDraft(
          id: 'administrator-ana',
          person: InstitutionPersonDraft(
            firstName: 'Ana',
            lastName: 'Souza',
            displayName: 'Ana Souza',
          ),
          handle: '@Ana-Souza',
          level: InstitutionAdministratorLevel.adminMaster,
          invitationStatus: InstitutionInvitationStatus.accepted,
          invitationHistory: [],
        ),
      ],
    );
    final repository = FakeInstitutionDirectoryRepository(
      records: [aurora, demoInstitutionRecords[1]],
    );

    expect(repository.reservedHandles(), {'@aurora', '@ana-souza', '@horizonte'});
    expect(repository.reservedHandles(excludingInstitutionId: aurora.id), {'@horizonte'});
  });

  test('searches public, trade, and legal names but never the domain', () async {
    final repository = FakeInstitutionDirectoryRepository(items: _items);

    final nameResult = await repository.fetchPage(InstitutionDirectoryQuery(search: 'aurora'));
    final domainResult = await repository.fetchPage(
      InstitutionDirectoryQuery(search: 'dominio-secreto'),
    );

    expect(nameResult.items.map((item) => item.id), ['institution-1']);
    expect(domainResult.items, isEmpty);
  });

  test('uses OR inside filters and AND between multiselect filters', () async {
    final repository = FakeInstitutionDirectoryRepository(items: _items);

    final result = await repository.fetchPage(
      InstitutionDirectoryQuery(
        statuses: {InstitutionStatus.active, InstitutionStatus.onboarding},
        states: {'SP', 'RJ'},
        cities: {'Campinas', 'Niter\u00f3i'},
        districts: {'Cambu\u00ed', 'Icara\u00ed'},
        typeIds: {'type-school', 'type-therapy'},
      ),
    );

    expect(result.items.map((item) => item.id), ['institution-2', 'institution-1']);
  });

  test('returns dependent municipality and district options', () async {
    final repository = FakeInstitutionDirectoryRepository(items: _items);

    final stateOptions = await repository.fetchFilterOptions(states: {'SP', 'RJ'});
    final cityOptions = await repository.fetchFilterOptions(
      states: {'SP', 'RJ'},
      cities: {'Campinas', 'Niter\u00f3i'},
    );

    expect(stateOptions.cities.map((option) => option.label), ['Campinas', 'Niter\u00f3i']);
    expect(cityOptions.districts.map((option) => option.label), ['Cambu\u00ed', 'Icara\u00ed']);
  });

  test('returns distinct states from all records and cascades geographic options', () async {
    final repository = FakeInstitutionDirectoryRepository(
      items: [
        ..._items,
        _item(
          id: 'institution-3',
          publicName: 'Escola Sol',
          state: 'SP',
          city: 'Campinas',
          district: 'Centro',
        ),
      ],
    );

    final allOptions = await repository.fetchFilterOptions();
    final stateOptions = await repository.fetchFilterOptions(states: {'SP'});
    final cityOptions = await repository.fetchFilterOptions(states: {'SP'}, cities: {'Campinas'});

    expect(allOptions.states.map((option) => option.label), ['RJ', 'SP']);
    expect(stateOptions.cities.map((option) => option.label), ['Campinas']);
    expect(cityOptions.districts.map((option) => option.label), [_items.first.district, 'Centro']);
  });

  test('paginates every supported page size and reports the server total', () async {
    final items = List.generate(
      120,
      (index) => _item(
        id: 'institution-${index.toString().padLeft(3, '0')}',
        publicName: 'Institui\u00e7\u00e3o ${index.toString().padLeft(3, '0')}',
      ),
    );
    final repository = FakeInstitutionDirectoryRepository(items: items);

    final pageOfTen = await repository.fetchPage(InstitutionDirectoryQuery(page: 11, pageSize: 10));
    final pageOfFifty = await repository.fetchPage(
      InstitutionDirectoryQuery(page: 1, pageSize: 50),
    );
    final pageOfOneHundred = await repository.fetchPage(
      InstitutionDirectoryQuery(page: 1, pageSize: 100),
    );
    final pageOfFiveHundred = await repository.fetchPage(InstitutionDirectoryQuery(pageSize: 500));

    expect(pageOfTen.items.map((item) => item.id), [
      for (var index = 110; index < 120; index++) 'institution-${index.toString().padLeft(3, '0')}',
    ]);
    expect(pageOfTen.totalCount, 120);
    expect(pageOfTen.hasPrevious, isTrue);
    expect(pageOfTen.hasNext, isFalse);

    expect(pageOfFifty.items.map((item) => item.id).first, 'institution-050');
    expect(pageOfFifty.items.map((item) => item.id).last, 'institution-099');
    expect(pageOfFifty.items, hasLength(50));
    expect(pageOfFifty.hasNext, isTrue);

    expect(pageOfOneHundred.items.map((item) => item.id).first, 'institution-100');
    expect(pageOfOneHundred.items.map((item) => item.id).last, 'institution-119');
    expect(pageOfOneHundred.items, hasLength(20));
    expect(pageOfOneHundred.hasNext, isFalse);

    expect(pageOfFiveHundred.items, hasLength(120));
    expect(pageOfFiveHundred.hasNext, isFalse);
  });

  test('sorts before slicing with the page size from the query', () async {
    final repository = FakeInstitutionDirectoryRepository(
      items: [
        _item(id: 'institution-a', publicName: 'Alpha'),
        _item(id: 'institution-b', publicName: 'Beta'),
        _item(id: 'institution-c', publicName: 'Charlie'),
        _item(id: 'institution-d', publicName: 'Delta'),
        _item(id: 'institution-e', publicName: 'Echo'),
        _item(id: 'institution-f', publicName: 'Foxtrot'),
        _item(id: 'institution-g', publicName: 'Golf'),
        _item(id: 'institution-h', publicName: 'Hotel'),
        _item(id: 'institution-i', publicName: 'India'),
      ],
    );

    final firstPage = await repository.fetchPage(
      InstitutionDirectoryQuery(pageSize: 8, sortAscending: false),
    );
    final secondPage = await repository.fetchPage(
      InstitutionDirectoryQuery(page: 1, pageSize: 8, sortAscending: false),
    );

    expect(firstPage.items.map((item) => item.publicName), [
      'India',
      'Hotel',
      'Golf',
      'Foxtrot',
      'Echo',
      'Delta',
      'Charlie',
      'Beta',
    ]);
    expect(secondPage.items.map((item) => item.publicName), ['Alpha']);
    expect(firstPage.hasNext, isTrue);
  });

  test('breaks equal sort values directly by id', () async {
    final repository = FakeInstitutionDirectoryRepository(
      items: [
        _item(id: 'institution-z', publicName: 'Alpha'),
        _item(id: 'institution-b', publicName: 'Beta'),
        _item(id: 'institution-a', publicName: 'Alpha'),
      ],
    );

    final result = await repository.fetchPage(
      InstitutionDirectoryQuery(
        sortColumn: InstitutionDirectorySortColumn.unitsCount,
        sortAscending: false,
      ),
    );

    expect(result.items.map((item) => item.id), [
      'institution-a',
      'institution-b',
      'institution-z',
    ]);
  });

  test('sorts status by its persisted database value', () async {
    final repository = FakeInstitutionDirectoryRepository(
      items: [
        _item(id: 'institution-archived', publicName: 'Alpha', status: InstitutionStatus.archived),
        _item(id: 'institution-active', publicName: 'Zulu', status: InstitutionStatus.active),
      ],
    );

    final result = await repository.fetchPage(
      InstitutionDirectoryQuery(sortColumn: InstitutionDirectorySortColumn.status),
    );

    expect(result.items.map((item) => item.id), ['institution-active', 'institution-archived']);
  });
}

final _items = [
  _item(
    id: 'institution-1',
    publicName: 'Instituto Aurora',
    tradeName: 'Aurora',
    legalName: 'Aurora Educa\u00e7\u00e3o LTDA',
    domain: 'instituto-aurora.coelo.me',
    status: InstitutionStatus.active,
    planId: 'plan-1',
    state: 'SP',
    city: 'Campinas',
    district: 'Cambu\u00ed',
    typeId: 'type-school',
  ),
  _item(
    id: 'institution-2',
    publicName: 'Centro Nuvem',
    tradeName: 'Nuvem',
    legalName: 'Centro Terap\u00eautico Nuvem LTDA',
    domain: 'dominio-secreto-aurora.coelo.me',
    status: InstitutionStatus.onboarding,
    planId: 'plan-2',
    state: 'RJ',
    city: 'Niter\u00f3i',
    district: 'Icara\u00ed',
    typeId: 'type-therapy',
  ),
];

InstitutionDirectoryItem _item({
  required String id,
  required String publicName,
  String? tradeName,
  String? legalName,
  String? domain,
  InstitutionStatus status = InstitutionStatus.draft,
  String? planId,
  String? state,
  String? city,
  String? district,
  String? typeId,
}) {
  return InstitutionDirectoryItem(
    id: id,
    publicName: publicName,
    tradeName: tradeName,
    legalName: legalName,
    primaryDomain: domain,
    status: status,
    typeId: typeId,
    typeName: null,
    district: district,
    city: city,
    state: state,
    planId: planId,
    planName: null,
    unitsCount: 0,
    groupsCount: 0,
  );
}

InstitutionRecord _recordForTest({
  String id = 'inst-base',
  String slug = 'instituicao-base',
  String name = 'Instituicao Base',
  String typeName = 'Escola',
  int version = 1,
  List<InstitutionLegalRepresentative> legalRepresentatives = const [],
  List<InstitutionAdministratorDraft> administrators = const [],
}) {
  return InstitutionRecord(
    id: id,
    publicName: name,
    tradeName: 'TB',
    legalName: 'TB LTDA',
    typeId: 'type',
    typeName: typeName,
    documentType: 'CNPJ',
    document: '12.345.678/0001-99',
    slug: slug,
    primaryDomain: 'base.coelo.me',
    status: InstitutionStatus.active,
    locale: 'pt-BR',
    timezone: 'America/Sao_Paulo',
    postalCode: '00000-000',
    country: 'Brasil',
    state: 'SP',
    city: 'Sao Paulo',
    district: 'Centro',
    street: 'Rua Um',
    addressNumber: '100',
    complement: '',
    contactEmail: 'contato@base.coelo.me',
    contactPhone: '+55 11 3333-0000',
    contactMobilePhone: '+55 11 99999-0000',
    ownerFirstName: 'Joana',
    ownerLastName: 'Silva',
    ownerDisplayName: 'Joana Silva',
    ownerEmail: 'joana@base.coelo.me',
    ownerMobilePhone: '+55 11 99999-1111',
    plan: InstitutionPlan.essential,
    subscriptionStatus: InstitutionSubscriptionStatus.active,
    subscriptionStart: DateTime(2026, 1, 1),
    trialEnd: null,
    subscriptionJustification: '',
    brandDisplayName: 'Base',
    hasSimulatedLogo: true,
    hasSimulatedCover: false,
    accentColor: '#D63C00',
    secondaryColor: '#3F4549',
    units: const [],
    version: version,
    legalRepresentatives: legalRepresentatives,
    administrators: administrators,
  );
}
