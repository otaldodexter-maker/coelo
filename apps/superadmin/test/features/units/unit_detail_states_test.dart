import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _unitA = '30000000-0000-4000-8000-000000000001';
const _institutionA = '20000000-0000-4000-8000-000000000001';

/// The unit detail renders three distinct failure surfaces and keys them from
/// the state's own name. That is convenient and slightly dangerous: the key
/// keeps passing while the title and message ternaries beside it are inverted,
/// because those are written out by hand. These tests drive each state through
/// the repository and assert the words the operator actually reads.
final class _ControlledUnitDetail implements UnitDetailRepository {
  final calls = <Completer<UnitDetail>>[];

  @override
  Future<UnitDetail> fetchById(String unitId) {
    final result = Completer<UnitDetail>();
    calls.add(result);
    return result.future;
  }
}

UnitDetail _unit() => UnitDetail(
  id: _unitA,
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

void main() {
  late _ControlledUnitDetail repository;

  setUp(() => repository = _ControlledUnitDetail());

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDetailPage(
          repository: repository,
          id: _unitA,
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a failed read says it failed, and says how to recover', (tester) async {
    // This is the branch the key unit-detail-unavailable exists for. Before this
    // test it was reachable in production and asserted nowhere.
    await pumpDetail(tester);
    repository.calls.single.completeError(
      const UnitDetailException(UnitDetailFailure.unavailable),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-detail-unavailable')), findsOneWidget);
    expect(find.text('Não foi possível carregar os detalhes'), findsOneWidget);
    expect(find.text('Tente recarregar os dados.'), findsOneWidget);
    // A failure is not a denial, and saying the wrong one is worse than saying
    // nothing: it sends the operator to ask for permission they already have.
    expect(find.text('Acesso não autorizado'), findsNothing);
    expect(find.byKey(const Key('unit-detail-denied')), findsNothing);
  });

  testWidgets('a malformed id is answered as a denial, on purpose', (tester) async {
    // The controller folds invalidId into denied rather than into unavailable,
    // and that is right: if a bad id answered differently from a forbidden one,
    // the screen would become an oracle for which ids exist. Pinning it here so
    // nobody "fixes" it into a more informative message.
    await pumpDetail(tester);
    repository.calls.single.completeError(
      const UnitDetailException(UnitDetailFailure.invalidId),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-detail-denied')), findsOneWidget);
    expect(find.text('Você não tem permissão para consultar este registro.'), findsOneWidget);
    expect(find.byKey(const Key('unit-detail-unavailable')), findsNothing);
  });

  testWidgets('a denial says permission, in those words', (tester) async {
    await pumpDetail(tester);
    repository.calls.single.completeError(const UnitDetailException(UnitDetailFailure.denied));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-detail-denied')), findsOneWidget);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Você não tem permissão para consultar este registro.'), findsOneWidget);
    expect(find.text('Não foi possível carregar os detalhes'), findsNothing);
  });

  testWidgets('a failure never leaves the previous unit on screen', (tester) async {
    await pumpDetail(tester);
    repository.calls.single.complete(_unit());
    await tester.pumpAndSettle();
    expect(find.text('Unidade sintética'), findsWidgets);

    await tester.tap(find.byKey(const Key('unit-detail-reload')));
    await tester.pump();
    repository.calls.last.completeError(
      const UnitDetailException(UnitDetailFailure.unavailable),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-detail-unavailable')), findsOneWidget);
    // Showing a record that the last read could not confirm is the failure mode
    // worth guarding: it looks like data and is not.
    expect(find.text('Unidade sintética'), findsNothing);
  });

  testWidgets('reload reads again rather than only looking like it does', (tester) async {
    await pumpDetail(tester);
    repository.calls.single.completeError(
      const UnitDetailException(UnitDetailFailure.unavailable),
    );
    await tester.pumpAndSettle();
    expect(repository.calls.length, 1);

    final reload = find.byKey(const Key('unit-detail-reload'));
    await tester.ensureVisible(reload);
    await tester.pumpAndSettle();
    await tester.tap(reload);
    await tester.pump();
    expect(repository.calls.length, 2);

    repository.calls.last.complete(_unit());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-detail-unavailable')), findsNothing);
    expect(find.text('Unidade sintética'), findsWidgets);
  });

  testWidgets('reload cannot be pressed while a read is in flight', (tester) async {
    await pumpDetail(tester);
    // Bounded pumps, not pumpAndSettle: the loading panel animates for as long
    // as the read is pending, so settling would wait for a future this test is
    // deliberately holding open.
    await tester.pump(const Duration(milliseconds: 100));
    final reload = find.byKey(const Key('unit-detail-reload'));
    expect(tester.widget<OutlinedButton>(reload).onPressed, isNull);
    repository.calls.single.complete(_unit());
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reload).onPressed, isNotNull);
  });
}
