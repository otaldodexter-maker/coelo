import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [StateError('private-token'), TypeError()]) {
    testWidgets('search hides old results and recovers explicitly after ${failure.runtimeType}', (
      tester,
    ) async {
      await _surface(tester);
      final repository = _Repository();
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wizard(controller));
      await tester.enterText(find.byType(TextField).last, 'Ana');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      final card = tester.widget<CoeloAdminInteractiveCard>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CoeloAdminInteractiveCard &&
              widget.semanticLabel == 'Selecionar Criança child-a',
        ),
      );
      final oldSelection = card.onPressed!;
      oldSelection();
      repository.searchFailure = failure;
      await tester.enterText(find.byType(TextField).last, 'Bia');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Não foi possível buscar crianças.'), findsOneWidget);
      expect(find.text('Criança child-a'), findsNothing);
      expect(find.textContaining('private-token'), findsNothing);
      oldSelection();
      await tester.pump();
      await tester.tap(find.byKey(const Key('safety-wizard-primary')));
      await tester.pumpAndSettle();
      expect(find.text('Busque e selecione uma criança.'), findsOneWidget);
      repository.searchFailure = null;
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('Criança child-a'), findsOneWidget);
      expect(find.text('Não foi possível buscar crianças.'), findsNothing);
      expect(repository.searches, 3);
      expect(repository.queries, ['Ana', 'Bia', 'Bia']);
    });
  }

  testWidgets('a new pending search clears old options before its result arrives', (tester) async {
    await _surface(tester);
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(controller));
    await tester.enterText(find.byType(TextField).last, 'Criança');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    final pending = Completer<List<ChildSafetyChildOption>>();
    repository.searchResult = pending.future;
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    expect(find.text('Criança child-a'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final failure in [StateError('private-token'), TypeError()]) {
    testWidgets('initial context offers a guarded read retry after ${failure.runtimeType}', (
      tester,
    ) async {
      await _surface(tester);
      final repository = _Repository()..childFailure = failure;
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wizard(controller, childId: 'child-a'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Não foi possível carregar o contexto solicitado.'), findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
        isNull,
      );
      final retry = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Recarregar contexto'))
          .onPressed!;
      repository.childFailure = null;
      final pending = Completer<ChildSafetyRecord?>();
      repository.childResult = pending.future;
      retry();
      retry();
      await tester.pump();
      expect(repository.childReads, 2);
      pending.complete(repository.record('child-a'));
      await tester.pumpAndSettle();
      expect(find.text('Recarregar contexto'), findsNothing);
      expect(find.text('Criança child-a'), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('late initial Error is ignored after replacing the child context', (tester) async {
    await _surface(tester);
    final pending = Completer<ChildSafetyRecord?>();
    final repository = _Repository()..childResult = pending.future;
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(controller, childId: 'child-a'));
    repository.childResult = null;
    await tester.pumpWidget(_wizard(controller, childId: 'child-b'));
    await tester.pumpAndSettle();
    pending.completeError(StateError('private-old-context'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Criança child-b'), findsWidgets);
    expect(find.text('Recarregar contexto'), findsNothing);
    expect(find.text('Não foi possível carregar o contexto solicitado.'), findsNothing);
  });

  testWidgets('initial denial clears context without offering an authorization bypass', (
    tester,
  ) async {
    await _surface(tester);
    final repository = _Repository()..childFailure = const ChildSafetyUnauthorizedException();
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(controller, childId: 'child-a'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Criança child-a'), findsNothing);
    expect(find.text('Recarregar contexto'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
    repository.childFailure = null;
    await controller.retry();
    await tester.pumpAndSettle();
    expect(controller.state, ChildSafetyLoadState.ready);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Buscar'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
    await tester.pumpWidget(_wizard(controller, childId: 'child-b'));
    await tester.pumpAndSettle();
    expect(find.text('Criança child-b'), findsWidgets);
  });

  testWidgets('search denial survives a successful directory reload', (tester) async {
    await _surface(tester);
    final repository = _Repository()..searchFailure = const ChildSafetyUnauthorizedException();
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(controller));
    await tester.enterText(find.byType(TextField).last, 'Criança');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    repository.searchFailure = null;
    await controller.retry();
    await tester.pumpAndSettle();
    expect(controller.state, ChildSafetyLoadState.ready);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Buscar'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
    expect(repository.searches, 1);
    expect(find.text('Criança child-a'), findsNothing);
  });

  testWidgets(
    'context retry first restores an unavailable directory and stays retryable after another failure',
    (tester) async {
      await _surface(tester);
      final repository = _Repository();
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wizard(controller, childId: 'child-a'));
      await tester.pumpAndSettle();
      repository.directoryFailure = const ChildSafetyUnavailableException();
      await controller.retry();
      await tester.pumpAndSettle();
      expect(find.text('Criança child-a'), findsNothing);
      expect(find.text('Recarregar contexto'), findsOneWidget);
      await tester.tap(find.text('Recarregar contexto'));
      await tester.pumpAndSettle();
      expect(find.text('Recarregar contexto'), findsOneWidget);
      expect(find.text('Criança child-a'), findsNothing);
      repository.directoryFailure = null;
      await tester.tap(find.text('Recarregar contexto'));
      await tester.pumpAndSettle();
      expect(find.text('Recarregar contexto'), findsNothing);
      expect(find.text('Criança child-a'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final denied in [false, true]) {
    testWidgets('confirmed save keeps data hidden on recovery failure (denied: $denied)', (
      tester,
    ) async {
      await _surface(tester);
      final repository = _Repository();
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      var saved = 0;
      await tester.pumpWidget(_wizard(controller, childId: 'child-a', onSaved: () => saved++));
      await tester.pumpAndSettle();
      final primary = find.byKey(const Key('safety-wizard-primary'));
      await tester.tap(primary);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'person-a');
      await tester.enterText(find.byType(TextField).last, 'Motivo sintético');
      await tester.tap(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      repository.directoryFailure = const ChildSafetyUnavailableException();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      repository.directoryFailure = null;
      repository.childFailure = denied ? const ChildSafetyUnauthorizedException() : TypeError();
      await tester.tap(find.text('Recarregar dados'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          denied
              ? 'Não foi possível carregar o contexto solicitado.'
              : 'Não foi possível atualizar os dados. Recarregue para continuar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Motivo sintético'), findsNothing);
      expect(find.text('Criança child-a'), findsNothing);
      expect(saved, 0);
      repository.childFailure = null;
      if (denied) {
        expect(find.text('Recarregar dados'), findsNothing);
        await controller.retry();
        await tester.pumpAndSettle();
        expect(controller.state, ChildSafetyLoadState.ready);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Buscar'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);
        expect(repository.saves, 1);
        expect(saved, 0);
        return;
      }
      await tester.tap(find.text('Recarregar dados'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(repository.saves, 1);
    });
  }
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _wizard(ChildSafetyController controller, {String? childId, VoidCallback? onSaved}) =>
    MaterialApp(
      theme: CoeloTheme.light,
      home: ChildSafetyWizardPage(
        controller: controller,
        childId: childId,
        logout: () async => const LogoutResult.success(),
        onCancel: () {},
        onSaved: onSaved ?? () {},
      ),
    );

final class _Repository implements ChildSafetyRepository {
  final queries = <String>[];
  Object? searchFailure, childFailure, directoryFailure;
  Future<List<ChildSafetyChildOption>>? searchResult;
  Future<ChildSafetyRecord?>? childResult;
  int searches = 0, childReads = 0, saves = 0;
  ChildSafetyRecord record(String id) => ChildSafetyRecord(
    childId: id,
    childName: 'Criança $id',
    internalId: id,
    institutionName: 'Instituição',
    unitName: 'Unidade',
    childContextId: 'context-$id',
    institutionId: 'institution',
    unitId: 'unit',
    authorizations: [],
  );
  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    searches++;
    queries.add(query);
    if (searchFailure case final failure?) throw failure;
    return searchResult == null
        ? const [
            ChildSafetyChildOption(
              id: 'child-a',
              name: 'Criança child-a',
              internalId: 'a',
              childContextId: 'context-child-a',
              institutionId: 'institution',
              institutionName: 'Instituição',
              unitId: 'unit',
              unitName: 'Unidade',
            ),
          ]
        : await searchResult!;
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String id) async {
    childReads++;
    if (childFailure case final failure?) throw failure;
    return childResult == null ? record(id) : await childResult!;
  }

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    if (directoryFailure case final failure?) throw failure;
    return ChildSafetyDirectoryPage(
      records: [record('child-a')],
      totalCount: 1,
      canCreate: true,
      segmentCounts: const ChildSafetySegmentCounts(all: 1),
    );
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    saves++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
