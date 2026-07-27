import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('models immutable multiselect filters with value equality', () {
    final query = InstitutionDirectoryQuery(
      statuses: {InstitutionStatus.active, InstitutionStatus.onboarding},
      typeIds: {'type-school', 'type-therapy'},
      states: {'SP', 'PR'},
      cities: {'Campinas', 'Curitiba'},
      districts: {'Cambuí', 'Batel'},
      page: 2,
      pageSize: 50,
    );

    expect(query.statuses, {InstitutionStatus.active, InstitutionStatus.onboarding});
    expect(query.states, {'SP', 'PR'});
    expect(query.cities, {'Campinas', 'Curitiba'});
    expect(query.districts, {'Cambuí', 'Batel'});
    expect(query.offset, 100);
    expect(query.hasActiveFilters, isTrue);
    expect(
      query,
      InstitutionDirectoryQuery(
        statuses: {InstitutionStatus.onboarding, InstitutionStatus.active},
        typeIds: {'type-therapy', 'type-school'},
        states: {'PR', 'SP'},
        cities: {'Curitiba', 'Campinas'},
        districts: {'Batel', 'Cambuí'},
        page: 2,
        pageSize: 50,
      ),
    );
    expect(
      query.hashCode,
      InstitutionDirectoryQuery(
        statuses: {InstitutionStatus.onboarding, InstitutionStatus.active},
        typeIds: {'type-therapy', 'type-school'},
        states: {'PR', 'SP'},
        cities: {'Curitiba', 'Campinas'},
        districts: {'Batel', 'Cambuí'},
        page: 2,
        pageSize: 50,
      ).hashCode,
    );
    expect(() => query.states.add('RJ'), throwsUnsupportedError);
  });

  test('treats empty filter collections as no active filter', () {
    final query = InstitutionDirectoryQuery();

    expect(query.pageSize, InstitutionDirectoryQuery.defaultPageSize);
    expect(query.statuses, isEmpty);
    expect(query.typeIds, isEmpty);
    expect(query.states, isEmpty);
    expect(query.cities, isEmpty);
    expect(query.districts, isEmpty);
    expect(query.hasActiveFilters, isFalse);
  });

  test('distinguishes page sizes and rejects unsupported values', () {
    final pageOfTen = InstitutionDirectoryQuery(page: 2, pageSize: 10);
    final pageOfFifty = InstitutionDirectoryQuery(page: 2, pageSize: 50);

    expect(pageOfTen, isNot(pageOfFifty));
    expect(() => InstitutionDirectoryQuery(pageSize: 25), throwsA(isA<AssertionError>()));
  });
}
