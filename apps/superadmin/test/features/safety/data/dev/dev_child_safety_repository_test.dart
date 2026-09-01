import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content exposes the coherent 164-record safety distribution', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevChildSafetyRepository.content(catalog: catalog);

    final page = await repository.fetchDirectory(ChildSafetyDirectoryQuery(pageSize: 100));
    final secondPage = await repository.fetchDirectory(
      ChildSafetyDirectoryQuery(pageIndex: 1, pageSize: 100),
    );

    expect(page.totalCount, 164);
    expect(page.records, hasLength(100));
    expect(secondPage.records, hasLength(64));
    expect(page.segmentCounts.authorized, 126);
    expect(page.segmentCounts.awaitingApproval, 18);
    expect(page.segmentCounts.attention, 11);
    expect(page.segmentCounts.withoutAuthorization, 9);
    expect(
      [...page.records, ...secondPage.records].map((record) => record.childId).toSet(),
      catalog.safetyRecords.map((record) => record.childId).toSet(),
    );
  });

  test('content keeps all 180 children searchable and 16 without a record', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevChildSafetyRepository.content(catalog: catalog);
    final target = catalog.children.last;

    final allChildren = await repository.searchChildren('', limit: 200);
    final search = await repository.searchChildren(target.name, limit: 20);
    final identifierSearch = await repository.searchChildren(target.privateIdentifier, limit: 20);
    final directoryIdentifierSearch = await repository.fetchDirectory(
      ChildSafetyDirectoryQuery(search: catalog.children.first.privateIdentifier),
    );
    final withoutRecord = await Future.wait([
      for (final child in catalog.children) repository.fetchChild(child.id),
    ]);

    expect(allChildren, hasLength(180));
    expect(search.map((child) => child.id), contains(target.id));
    expect(identifierSearch.single.id, target.id);
    expect(directoryIdentifierSearch.records.single.childId, catalog.children.first.id);
    expect(withoutRecord.where((record) => record == null), hasLength(16));
  });

  test('first authorization creates a missing safety record and reset removes it', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevChildSafetyRepository.content(catalog: catalog);
    final child = catalog.children.last;
    expect(await repository.fetchChild(child.id), isNull);

    await repository.saveAuthorization(
      SavePickupAuthorizationCommand(
        requestId: 'create-missing-safety',
        childId: child.id,
        childContextId: child.groupId,
        unitId: child.unitId,
        personId: child.guardianIds.first,
        relationshipCode: 'responsavel',
        capabilityCodes: const {'pickup'},
        requestReason: 'Solicitação familiar',
      ),
    );

    final created = await repository.fetchChild(child.id);
    expect(created?.directorySegment, ChildSafetyDirectorySegment.awaitingApproval);
    expect(created?.authorizations.single.status, PickupAuthorizationStatus.pending);
    expect((await repository.fetchDirectory(ChildSafetyDirectoryQuery())).totalCount, 165);
    repository.resetSession();
    expect(await repository.fetchChild(child.id), isNull);
  });

  test('supports stateful authorization lifecycle and reset', () async {
    final seed = ChildSafetyRecord(
      childId: 'child-1',
      childName: 'Ana',
      internalId: 'A1',
      institutionName: 'Coelo',
      unitName: 'Infantil',
      authorizations: const [],
    );
    final repository = DevChildSafetyRepository(records: [seed]);
    await repository.saveAuthorization(
      const SavePickupAuthorizationCommand(
        requestId: 'request-1',
        childId: 'child-1',
        childContextId: 'context-1',
        unitId: 'unit-1',
        personId: 'person-1',
        relationshipCode: 'responsavel',
        capabilityCodes: {'pickup'},
        requestReason: 'Saída',
      ),
    );
    final created = await repository.fetchChild('child-1');
    expect(created!.authorizations, hasLength(1));
    await repository.transitionAuthorization(
      TransitionPickupAuthorizationCommand(
        requestId: 'request-2',
        childId: 'child-1',
        authorizationId: created.authorizations.single.id,
        status: PickupAuthorizationStatus.approved,
        reason: 'Validado',
      ),
    );
    expect(
      (await repository.fetchChild('child-1'))!.authorizations.single.status,
      PickupAuthorizationStatus.approved,
    );
    expect(
      (await repository.fetchChild('child-1'))!.directorySegment,
      ChildSafetyDirectorySegment.authorized,
    );
    repository.resetSession();
    expect((await repository.fetchChild('child-1'))!.authorizations, isEmpty);
  });
}
