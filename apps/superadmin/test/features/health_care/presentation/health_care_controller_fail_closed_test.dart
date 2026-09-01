import 'package:coelo_superadmin/features/health_care/domain/health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unavailable repository remains fail closed without an actor', () async {
    final controller = HealthCareController(const UnavailableHealthCareRepository());
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, HealthCareLoadState.unavailable);
  });
}
