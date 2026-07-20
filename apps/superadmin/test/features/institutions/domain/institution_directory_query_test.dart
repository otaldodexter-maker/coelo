import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('models dependent municipality and district filters', () {
    const query = InstitutionDirectoryQuery(state: 'SP', city: 'Campinas', district: 'Cambuí');

    expect(query.city, 'Campinas');
    expect(query.district, 'Cambuí');
    expect(query.hasActiveFilters, isTrue);
    expect(
      query,
      const InstitutionDirectoryQuery(state: 'SP', city: 'Campinas', district: 'Cambuí'),
    );
  });
}
