import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        cities: {'Campinas', 'Niterói'},
        districts: {'Cambuí', 'Icaraí'},
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
      cities: {'Campinas', 'Niterói'},
    );

    expect(stateOptions.cities.map((option) => option.label), ['Campinas', 'Niterói']);
    expect(cityOptions.districts.map((option) => option.label), ['Cambuí', 'Icaraí']);
  });

  test('paginates twenty institutions and reports the server total', () async {
    final items = List.generate(
      25,
      (index) => _item(id: 'institution-$index', publicName: 'Instituição $index'),
    );
    final repository = FakeInstitutionDirectoryRepository(items: items);

    final result = await repository.fetchPage(InstitutionDirectoryQuery(page: 1));

    expect(result.items, hasLength(5));
    expect(result.totalCount, 25);
    expect(result.page, 1);
    expect(result.hasPrevious, isTrue);
    expect(result.hasNext, isFalse);
  });
}

final _items = [
  _item(
    id: 'institution-1',
    publicName: 'Instituto Aurora',
    tradeName: 'Aurora',
    legalName: 'Aurora Educação LTDA',
    domain: 'instituto-aurora.coelo.me',
    status: InstitutionStatus.active,
    planId: 'plan-1',
    state: 'SP',
    city: 'Campinas',
    district: 'Cambuí',
    typeId: 'type-school',
  ),
  _item(
    id: 'institution-2',
    publicName: 'Centro Nuvem',
    tradeName: 'Nuvem',
    legalName: 'Centro Terapêutico Nuvem LTDA',
    domain: 'dominio-secreto-aurora.coelo.me',
    status: InstitutionStatus.onboarding,
    planId: 'plan-2',
    state: 'RJ',
    city: 'Niterói',
    district: 'Icaraí',
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
