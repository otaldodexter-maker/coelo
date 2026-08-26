import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = UnavailableGroupDirectoryRepository();
  final record = GroupRecord(
    id: 'group-1',
    institutionId: 'institution-1',
    institutionName: 'Institution',
    unitId: 'unit-1',
    unitName: 'Unit',
    name: 'Group',
    groupType: 'class',
    status: GroupStatus.active,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('fails closed for the synchronous id operation', () {
    expect(
      () => repository.createId('institution-1', 'unit-1', 'Group'),
      throwsA(isA<GroupDirectoryUnavailableException>()),
    );
  });

  test('fails closed for all asynchronous directory operations', () async {
    final request = GroupDirectorySaveRequest(requestId: 'request-1', record: record);
    final calls = <Future<Object?>>[
      repository.findById(record.id),
      repository.upsert(record),
      repository.saveComposition(request),
      repository.fetchPage(GroupDirectoryQuery()),
      repository.fetchFilterOptions(),
      repository.fetchFormContext(),
      repository.requestExport(GroupDirectoryQuery()),
    ];

    for (final call in calls) {
      await expectLater(call, throwsA(isA<GroupDirectoryUnavailableException>()));
    }
  });
}
