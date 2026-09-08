import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _unitA = '30000000-0000-4000-8000-000000000001';
const _institutionA = '20000000-0000-4000-8000-000000000001';

/// Fence around the deferred people export of a unit.
///
/// The Owner deferred the operation to after the MVP and kept the promise that
/// the button stays visible and says it is unavailable. An action nobody can
/// see is an action nobody can ask about, so its absence would have been the
/// dishonest option, not the safe one.
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
  Widget page({UnitDetailFailure? failure}) => MaterialApp(
    theme: CoeloTheme.light,
    home: UnitDetailPage(
      repository: _StubUnitDetail(failure: failure),
      id: _unitA,
      logout: unavailableSuperadminLogout,
      onBack: () {},
    ),
  );

  testWidgets('an authorized unit shows the deferred export instead of hiding it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('unit-people-export'));
    expect(action, findsOneWidget);
    expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
  });

  testWidgets('pressing it says it is unavailable and nothing else happens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('unit-people-export'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Disponível depois do MVP'), findsOneWidget);
    // An honest unavailability is the whole behaviour: no dialog opened, no
    // route was pushed, nothing claims a file is coming.
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a denied unit offers no export, because there is no unit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page(failure: UnitDetailFailure.denied));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-people-export')), findsNothing);
  });

  test('nothing behind the button makes the deferred operation real', () {
    // Reading the source keeps a promise about what production composes, which
    // a widget test cannot state as directly. The counterpart for the directory
    // toolbar lives in unit_file_actions_debt_test.dart.
    final source = File(
      'lib/features/units/presentation/unit_detail_page.dart',
    ).readAsStringSync();
    expect(
      source.contains('unit-people-export'),
      isTrue,
      reason: 'the button for the deferred people export must stay visible',
    );
    for (final forbidden in const [
      'FilePicker',
      'openDownloadUrl',
      'generateExport',
      'downloadPeople',
      'exportPeople',
    ]) {
      expect(
        source.contains(forbidden),
        isFalse,
        reason: '$forbidden would make a deferred operation real',
      );
    }
  });
}
