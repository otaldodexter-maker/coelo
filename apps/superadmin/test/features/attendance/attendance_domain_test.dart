import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk receipt records only participants changed by the operation', () {
    const receipt = AttendanceBulkReceipt(
      operationId: 'operation-1',
      callId: 'call-1',
      affectedParticipantIds: {'participant-1', 'participant-3'},
      previousVersion: 4,
      currentVersion: 5,
    );

    expect(receipt.affectedParticipantIds, {'participant-1', 'participant-3'});
    expect(receipt.canUndoAtVersion(5), isTrue);
    expect(receipt.canUndoAtVersion(6), isFalse);
  });
}
