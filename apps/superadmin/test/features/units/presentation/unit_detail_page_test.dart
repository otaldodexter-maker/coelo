import 'dart:async';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('changing the route id ignores the previous pending response', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    Widget app(String id) => MaterialApp(
      theme: CoeloTheme.light,
      home: UnitDetailPage(
        repository: repository,
        id: id,
        logout: () async => const LogoutResult.success(),
        onBack: () {},
        onDestinationSelected: (_) {},
      ),
    );
    await tester.pumpWidget(app('old-id'));
    await tester.pumpWidget(app('new-id'));
    expect(repository.calls, hasLength(2));
    repository.calls.first.complete(_detail);
    await tester.pump();
    expect(find.text('Nome autorizado'), findsNothing);
    expect(find.byKey(const Key('unit-detail-loading')), findsOneWidget);
    repository.calls.last.completeError(const UnitDetailException(UnitDetailFailure.denied));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-detail-denied')), findsOneWidget);
    expect(find.text('Nome autorizado'), findsNothing);
    expect(find.byKey(const Key('unit-detail-reload')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only detail reload removes payload and keeps denial safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    var back = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDetailPage(
          repository: repository,
          id: 'id',
          logout: () async => const LogoutResult.success(),
          onBack: () => back++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('unit-detail-loading')), findsOneWidget);
    repository.calls[0].complete(_detail);
    await tester.pumpAndSettle();
    expect(find.text('Nome autorizado'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsNothing);
    expect(find.text('Editar'), findsNothing);
    await tester.tap(find.byKey(const Key('unit-detail-reload')));
    await tester.pump();
    expect(find.text('Nome autorizado'), findsNothing);
    repository.calls[1].completeError(const UnitDetailException(UnitDetailFailure.denied));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-detail-denied')), findsOneWidget);
    expect(find.text('Nome autorizado'), findsNothing);
    await tester.tap(find.byKey(const Key('unit-detail-back')));
    expect(back, 1);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('read-only $width dark=$dark text200 remains usable', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? CoeloTheme.dark : CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
              child: child!,
            ),
            home: UnitDetailPage(
              repository: repository,
              id: 'id',
              logout: () async => const LogoutResult.success(),
              onBack: () {},
            ),
          ),
        );
        repository.calls.single.complete(_detail);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('unit-detail-reload')).hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('unit-detail-back')).hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('unit-detail-reload'))).height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
}

class _Repository implements UnitDetailRepository {
  final calls = <Completer<UnitDetail>>[];
  @override
  Future<UnitDetail> fetchById(String id) {
    final completer = Completer<UnitDetail>();
    calls.add(completer);
    return completer.future;
  }
}

final _detail = UnitDetail(
  id: 'id',
  name: 'Nome autorizado',
  slug: 'unidade',
  status: 'active',
  institutionId: 'institution',
  institutionName: 'Instituição A',
  institutionType: null,
  unitType: const UnitDetailType(id: 'type', name: 'Escola'),
  address: null,
  contact: null,
  effectivePlan: null,
);
