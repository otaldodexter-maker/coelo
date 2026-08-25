import 'package:coelo_superadmin/features/units/domain/unit_backend_commands.dart';
import 'package:coelo_superadmin/features/units/domain/unit_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds deterministic storage paths and parses them back', () {
    final path = UnitIdentityStoragePath.build(
      institutionId: '11111111-1111-4111-8111-111111111111',
      unitId: '22222222-2222-4222-8222-222222222222',
      kind: UnitIdentityMediaKind.profile,
      mediaId: '33333333-3333-4333-8333-333333333333',
      mimeType: 'image/jpeg',
    );

    expect(
      path.value,
      'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/33333333-3333-4333-8333-333333333333.jpg',
    );
    expect(UnitIdentityStoragePath.parse(path.value).kind, UnitIdentityMediaKind.profile);
    expect(UnitIdentityMediaKindValues.fileExtensionForMimeType('image/png'), 'png');
  });

  test('normalizes requested handles and keeps file job states typed', () {
    final command = UnitHandleChangeCommand(
      requestId: '44444444-4444-4444-8444-444444444444',
      unitId: '22222222-2222-4222-8222-222222222222',
      expectedVersion: 4,
      requestedHandle: '@Nova-Unidade',
    );

    expect(command.normalizedHandle, 'nova-unidade');
    expect(UnitFileFormat.csv.databaseValue, 'csv');
    expect(UnitFileJobStatus.success.isTerminal, isTrue);
    expect(UnitFileJobStatus.processing.isTerminal, isFalse);
  });

  test('keeps transfer preview blocking explicit and type request statuses stable', () {
    final preview = UnitTransferPreview(
      unitId: '22222222-2222-4222-8222-222222222222',
      sourceInstitutionId: '11111111-1111-4111-8111-111111111111',
      destinationInstitutionId: '99999999-9999-4999-8999-999999999999',
      dependencies: const {'groups': 2, 'invitations': 0},
      incompatibleDependencies: const ['groups'],
    );

    expect(preview.canTransfer, isFalse);
    expect(preview.dependencies['groups'], 2);
    expect(UnitTypeRequestStatus.pending.databaseValue, 'pending');
    expect(UnitTypeRequestStatus.rejected.databaseValue, 'rejected');
    expect(UnitStatus.values.map((status) => status.databaseValue), contains('active'));
  });
}
