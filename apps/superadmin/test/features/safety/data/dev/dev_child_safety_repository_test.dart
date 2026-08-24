import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supports stateful authorization lifecycle and reset', () async {
    final seed = ChildSafetyRecord(childId: 'child-1', childName: 'Ana', internalId: 'A1', institutionName: 'Coelo', unitName: 'Infantil', authorizations: const []);
    final repository = DevChildSafetyRepository(records: [seed]);
    await repository.saveAuthorization(const SavePickupAuthorizationCommand(
      requestId: 'request-1', childId: 'child-1', childContextId: 'context-1', unitId: 'unit-1', personId: 'person-1',
      relationshipCode: 'responsavel', capabilityCodes: {'pickup'}, requestReason: 'Saída',
    ));
    final created = await repository.fetchChild('child-1');
    expect(created!.authorizations, hasLength(1));
    await repository.transitionAuthorization(TransitionPickupAuthorizationCommand(
      requestId: 'request-2', childId: 'child-1', authorizationId: created.authorizations.single.id,
      status: PickupAuthorizationStatus.approved, reason: 'Validado',
    ));
    expect((await repository.fetchChild('child-1'))!.authorizations.single.status, PickupAuthorizationStatus.approved);
    repository.resetSession();
    expect((await repository.fetchChild('child-1'))!.authorizations, isEmpty);
  });
}
