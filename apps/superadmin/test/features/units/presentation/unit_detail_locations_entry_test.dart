import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _unitA = '30000000-0000-4000-8000-000000000001';
const _institutionA = '20000000-0000-4000-8000-000000000001';

final class _StubUnitDetail implements UnitDetailRepository {
  _StubUnitDetail({this.failure});

  final UnitDetailFailure? failure;

  @override
  Future<UnitDetail> fetchById(String unitId) async {
    if (failure != null) throw UnitDetailException(failure!);
    return UnitDetail(
      id: unitId,
      name: 'Unidade sintética',
      slug: 'unidade-sintetica',
      status: 'active',
      institutionId: _institutionA,
      institutionName: 'Instituição sintética',
      institutionType: null,
      unitType: const UnitDetailType(id: 'school', name: 'Escola'),
      address: null,
      contact: null,
      effectivePlan: null,
    );
  }
}

void main() {
  Widget page({required UnitDetailRepository repository, VoidCallback? onOpenLocationCatalog}) =>
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDetailPage(
          repository: repository,
          id: _unitA,
          logout: unavailableSuperadminLogout,
          onBack: () {},
          onOpenLocationCatalog: onOpenLocationCatalog,
        ),
      );

  testWidgets('the unit detail opens its catalog when a route is composed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0;
    await tester.pumpWidget(
      page(repository: _StubUnitDetail(), onOpenLocationCatalog: () => opened++),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('unit-detail-locations'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('without a composed route the detail offers no catalog control', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page(repository: _StubUnitDetail()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-detail-locations')), findsNothing);
  });

  testWidgets('a denied unit offers no catalog control either', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      page(
        repository: _StubUnitDetail(failure: UnitDetailFailure.denied),
        onOpenLocationCatalog: () {},
      ),
    );
    await tester.pumpAndSettle();
    // Without an authorized unit there is no owner, so there is nothing to open.
    expect(find.byKey(const Key('unit-detail-locations')), findsNothing);
  });
}
