import 'package:coelo_superadmin/features/safety/domain/child_safety_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directory query keeps filters immutable and uses an opaque cursor', () {
    final query = ChildSafetyDirectoryQuery(
      search: ' Ana ',
      institutionIds: {'institution-1'},
      cursor: 'opaque-cursor',
      pageIndex: 2,
      pageSize: 20,
    );

    expect(query.cursor, 'opaque-cursor');
    expect(query.pageIndex, 2);
    expect(query.search, ' Ana ');
    expect(query.institutionIds, isNot(same(<String>{'institution-1'})));
  });

  test('directory query only accepts approved page sizes', () {
    expect(() => ChildSafetyDirectoryQuery(pageSize: 7), throwsA(isA<AssertionError>()));
  });
}
