import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/institution_context_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapts the deterministic institution hierarchy for the context picker', () {
    final records = FakeInstitutionDirectoryRepository().records;
    final options = institutionContextOptions(records);

    expect(records.length, inInclusiveRange(2, 5));
    expect(options, hasLength(records.length));
    expect(options.first.id, records.first.id);
    expect(options.first.children, hasLength(records.first.units.length));
    expect(
      options.first.children.first.children,
      hasLength(records.first.units.first.groups.length),
    );
  });
}
