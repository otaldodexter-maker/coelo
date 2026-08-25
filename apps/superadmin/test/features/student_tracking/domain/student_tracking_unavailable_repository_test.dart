import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = UnavailableStudentTrackingRepository();

  test('fails child reads with unavailable instead of offline', () async {
    await expectLater(
      repository.fetchChildren(),
      throwsA(isA<StudentTrackingUnavailableException>()),
    );
  });

  test('fails snapshot reads with unavailable instead of offline', () async {
    await expectLater(
      repository.fetchSnapshot(childContextId: 'child-1'),
      throwsA(isA<StudentTrackingUnavailableException>()),
    );
  });
}
