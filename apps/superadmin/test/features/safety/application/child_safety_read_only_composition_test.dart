import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unqualified transport never dispatches save transition suspend or export', () async {
    final repository = _UnqualifiedRepository();
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    expect(controller.mutationsEnabled, isFalse);
    expect(controller.canCreate, isFalse);
    expect(
      await controller.saveAuthorization(
        const SavePickupAuthorizationCommand(
          requestId: 'r',
          childId: 'c',
          childContextId: 'cc',
          unitId: 'u',
          personId: 'p',
          relationshipCode: 'mother',
          capabilityCodes: {'pickup'},
          requestReason: 'test',
        ),
      ),
      isFalse,
    );
    expect(
      await controller.transitionAuthorization(
        const TransitionPickupAuthorizationCommand(
          requestId: 'r',
          childId: 'c',
          authorizationId: 'a',
          status: PickupAuthorizationStatus.approved,
          reason: 'test',
        ),
      ),
      isFalse,
    );
    expect(
      await controller.suspendAuthorization(
        const SuspendPickupAuthorizationCommand(
          requestId: 'r',
          childId: 'c',
          authorizationId: 'a',
          reason: 'test',
        ),
      ),
      isFalse,
    );
    expect(await controller.requestExport(const ChildSafetyExportCommand(requestId: 'r')), isFalse);
    expect(repository.calls, 0);
    expect(controller.commandFailure, ChildSafetyCommandFailure.unavailable);
    expect(controller.isSaving, isFalse);
  });
}

// A repository alone confers no transport support. Any call is a regression.
final class _UnqualifiedRepository implements ChildSafetyRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unqualified transport was called');
  }
}
