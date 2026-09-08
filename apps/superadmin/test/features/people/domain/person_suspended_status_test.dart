import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('person status preserves suspended instead of converting it to inactive', () {
    final status = PersonStatus.fromDatabase('suspended');
    expect(status.databaseValue, 'suspended');
    expect(status.label, 'Suspensa');
    expect(status, isNot(PersonStatus.inactive));
    expect(status, isNot(PersonStatus.archived));
  });

  for (final type in PersonType.values) {
    test('v2 detail represents suspended ${type.name} without changing type or auth', () {
      const id = '10000000-0000-4000-8000-000000000001';
      final person = decodePersonDetailV2({
        'ok': true,
        'data': {
          'id': id,
          'first_name': 'Synthetic',
          'last_name': 'Person',
          'display_name': 'Synthetic person',
          'legal_name': null,
          'type': type.databaseValue,
          'status': 'suspended',
          'auth_link': 'unlinked',
          'memberships': <Object>[],
          'child_contexts': <Object>[],
          'updated_at': '2026-09-07T12:00:00Z',
        },
        'error': null,
      }, requestedId: id);
      expect(person.status.databaseValue, 'suspended');
      expect(person.type, type);
      expect(person.authLink, AuthLinkStatus.unlinked);
      expect(person.isEditable, type != PersonType.service);
    });
  }
}
