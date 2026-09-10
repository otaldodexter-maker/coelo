import 'dart:async';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_detail_page.dart';
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
      home: GroupDetailPage(
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
    expect(find.byKey(const Key('group-detail-loading')), findsOneWidget);
    repository.calls.last.completeError(const GroupDetailException(GroupDetailFailure.denied));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-detail-denied')), findsOneWidget);
    expect(find.text('Nome autorizado'), findsNothing);
    expect(find.byKey(const Key('group-detail-reload')).hitTestable(), findsOneWidget);
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
        home: GroupDetailPage(
          repository: repository,
          id: 'id',
          logout: () async => const LogoutResult.success(),
          onBack: () => back++,
          reservationBuilder: (context, detail) => Text('Reservas de ${detail.id}'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('group-detail-loading')), findsOneWidget);
    repository.calls[0].complete(_detail);
    await tester.pumpAndSettle();
    expect(find.text('Nome autorizado'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Reservas de id'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('group-detail-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Reservas de id'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsNothing);
    expect(find.text('Editar'), findsNothing);
    await tester.tap(find.byKey(const Key('group-detail-reload')));
    await tester.pump();
    expect(find.text('Nome autorizado'), findsNothing);
    expect(find.text('Reservas de id'), findsNothing);
    repository.calls[1].completeError(const GroupDetailException(GroupDetailFailure.denied));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-detail-denied')), findsOneWidget);
    expect(find.text('Nome autorizado'), findsNothing);
    await tester.tap(find.byKey(const Key('group-detail-back')));
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
            home: GroupDetailPage(
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
        expect(find.byKey(const Key('group-detail-reload')).hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('group-detail-back')).hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('group-detail-reload'))).height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
}

class _Repository implements GroupDetailRepository {
  final calls = <Completer<GroupDetail>>[];
  @override
  Future<GroupDetail> fetchById(String id) {
    final completer = Completer<GroupDetail>();
    calls.add(completer);
    return completer.future;
  }
}

final _detail = GroupDetail(
  id: 'id',
  institutionId: 'institution',
  institutionName: 'Instituição A',
  unitId: 'unit',
  unitName: 'Unidade A',
  name: 'Nome autorizado',
  groupType: 'class',
  groupTypeOtherText: null,
  status: 'active',
  inheritAppearance: true,
  inheritAccess: true,
  inheritActivities: true,
  managementVersion: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
