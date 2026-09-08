import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail hides the previous child while the next child is loading', (tester) async {
    await _surface(tester);
    final repository = _Repository('Escopo A');
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_detail(controller, 'child-a'));
    await tester.pumpAndSettle();
    expect(find.text('child-a · Escopo A'), findsOneWidget);

    final pending = Completer<ChildSafetyRecord?>();
    repository.pending = pending.future;
    await tester.pumpWidget(_detail(controller, 'child-b'));
    await tester.pump();

    expect(find.text('child-a · Escopo A'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is CoeloStatePanel && widget.loading),
      findsOneWidget,
    );
    expect(repository.childReads, ['child-a', 'child-b']);
    pending.complete(repository.record('child-b'));
    await tester.pumpAndSettle();
    expect(find.text('child-b · Escopo A'), findsOneWidget);
  });

  testWidgets('detail ignores a late result from the replaced controller', (tester) async {
    await _surface(tester);
    final oldRepository = _Repository('Escopo A');
    final pending = Completer<ChildSafetyRecord?>();
    oldRepository.pending = pending.future;
    final oldController = ChildSafetyController(oldRepository);
    final newRepository = _Repository('Escopo B');
    final newController = ChildSafetyController(newRepository);
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);

    await tester.pumpWidget(_detail(oldController, 'child-a'));
    await tester.pump();
    await tester.pumpWidget(_detail(newController, 'child-a'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('child-a · Escopo B'), findsOneWidget);

    pending.complete(oldRepository.record('child-a'));
    await tester.pumpAndSettle();
    expect(find.text('child-a · Escopo A'), findsNothing);
    expect(find.text('child-a · Escopo B'), findsOneWidget);
  });

  testWidgets('detail moves its refresh listener to the new controller', (tester) async {
    await _surface(tester);
    final oldRepository = _Repository('Escopo A');
    final oldController = ChildSafetyController(oldRepository);
    final newRepository = _Repository('Escopo B');
    final newController = ChildSafetyController(newRepository);
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);

    await tester.pumpWidget(_detail(oldController, 'child-a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_detail(newController, 'child-a'));
    await tester.pumpAndSettle();
    final readsBefore = newRepository.childReads.length;
    await newController.load();
    await tester.pumpAndSettle();
    expect(newRepository.childReads.length, readsBefore + 1);

    await oldController.load();
    await tester.pumpAndSettle();
    expect(newRepository.childReads.length, readsBefore + 1);
  });

  for (final denied in [true, false]) {
    testWidgets('detail clears cached context after directory failure: $denied', (tester) async {
      await _surface(tester);
      final repository = _Repository('Escopo A');
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(_detail(controller, 'child-a'));
      await tester.pumpAndSettle();
      expect(find.text('child-a · Escopo A'), findsOneWidget);

      repository.directoryFailure = denied
          ? const ChildSafetyUnauthorizedException()
          : const ChildSafetyUnavailableException();
      await controller.retry();
      await tester.pumpAndSettle();
      expect(find.text('child-a · Escopo A'), findsNothing);
      expect(find.text('Contexto indisponível'), findsOneWidget);
      expect(repository.childReads, ['child-a']);

      repository.directoryFailure = null;
      await controller.retry();
      await tester.pumpAndSettle();
      expect(find.text('child-a · Escopo A'), findsOneWidget);
      expect(repository.childReads, ['child-a', 'child-a']);
    });
  }

  testWidgets('directory loads the replacement controller and clears the old search', (
    tester,
  ) async {
    await _surface(tester);
    final oldController = ChildSafetyController(
      _Repository('Escopo A'),
      searchDebounce: Duration.zero,
    );
    final repository = _Repository('Escopo B');
    final controller = ChildSafetyController(repository);
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_directory(oldController));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(CoeloSearchField).last,
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Busca anterior');
    await tester.pumpAndSettle();
    await tester.pumpWidget(_directory(controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.directoryReads, 1);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('child-a · Escopo B'), findsOneWidget);
    expect(find.text('child-a · Escopo A'), findsNothing);
  });

  testWidgets('wizard clears prior fields and reloads when its controller changes', (tester) async {
    await _surface(tester);
    final oldController = ChildSafetyController(_Repository('Escopo A'));
    final repository = _Repository('Escopo B');
    final controller = ChildSafetyController(repository);
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(oldController, 'child-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Motivo do contexto anterior');

    await tester.pumpWidget(_wizard(controller, 'child-a'));
    await tester.pumpAndSettle();
    expect(repository.childReads, ['child-a']);
    expect(find.text('child-a · Escopo B'), findsWidgets);
    expect(find.text('Motivo do contexto anterior'), findsNothing);
    expect(find.text('child-a · Escopo A'), findsNothing);
  });

  testWidgets('wizard rejects late initial context after controller replacement', (tester) async {
    await _surface(tester);
    final oldRepository = _Repository('Escopo A');
    final pending = Completer<ChildSafetyRecord?>();
    oldRepository.pending = pending.future;
    final oldController = ChildSafetyController(oldRepository);
    final controller = ChildSafetyController(_Repository('Escopo B'));
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(oldController, 'child-a'));
    await tester.pump();
    await tester.pumpWidget(_wizard(controller, 'child-b'));
    await tester.pumpAndSettle();
    pending.complete(oldRepository.record('child-a'));
    await tester.pumpAndSettle();
    expect(find.text('child-a · Escopo A'), findsNothing);
    expect(find.text('child-b · Escopo B'), findsWidgets);
  });

  testWidgets('wizard reloads when the child changes on the same controller', (tester) async {
    await _surface(tester);
    final repository = _Repository('Escopo A');
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(controller, 'child-a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wizard(controller, 'child-b'));
    await tester.pumpAndSettle();
    expect(repository.childReads, ['child-a', 'child-b']);
    expect(find.text('child-a · Escopo A'), findsNothing);
    expect(find.text('child-b · Escopo A'), findsWidgets);
  });

  testWidgets('wizard clears selected context and disables continuation after denial', (
    tester,
  ) async {
    await _surface(tester);
    final repository = _Repository('Escopo A');
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_wizard(controller, 'child-a'));
    await tester.pumpAndSettle();
    repository.directoryFailure = const ChildSafetyUnauthorizedException();
    await controller.retry();
    await tester.pumpAndSettle();
    expect(find.text('child-a · Escopo A'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
  });

  testWidgets('wizard rejects late search results after controller replacement', (tester) async {
    await _surface(tester);
    final repository = _Repository('Escopo A');
    final pending = Completer<List<ChildSafetyChildOption>>();
    repository.pendingSearch = pending.future;
    final oldController = ChildSafetyController(repository);
    final controller = ChildSafetyController(_Repository('Escopo B'));
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(oldController, null));
    await tester.enterText(find.byType(TextField).last, 'Criança');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    await tester.pumpWidget(_wizard(controller, null));
    await tester.pump();
    pending.complete(const [
      ChildSafetyChildOption(
        id: 'child-a',
        name: 'Criança anterior',
        internalId: 'a',
        institutionName: 'Escopo A',
        unitName: 'Unidade A',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Criança anterior'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, isEmpty);
  });

  testWidgets('wizard ignores the replaced controller listener', (tester) async {
    await _surface(tester);
    final oldRepository = _Repository('Escopo A');
    final oldController = ChildSafetyController(oldRepository);
    final controller = ChildSafetyController(_Repository('Escopo B'));
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wizard(oldController, 'child-a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wizard(controller, 'child-b'));
    await tester.pumpAndSettle();
    oldRepository.directoryFailure = const ChildSafetyUnauthorizedException();
    await oldController.load();
    await tester.pumpAndSettle();
    expect(find.text('child-b · Escopo B'), findsWidgets);
    expect(find.text('Não foi possível carregar o contexto solicitado.'), findsNothing);
  });

  for (final replacement in ['unchanged', 'replaced', 'replaced-and-restored']) {
    testWidgets('wizard save cannot navigate through a $replacement completion handler', (
      tester,
    ) async {
      await _surface(tester);
      final repository = _Repository('Escopo A');
      final pending = Completer<void>();
      repository.pendingSave = pending.future;
      final controller = ChildSafetyController(repository);
      addTearDown(controller.dispose);
      final navigator = GlobalKey<NavigatorState>();
      void original() => navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Destino original'))),
      );
      void replacementHandler() => navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Destino novo'))),
      );
      Widget page(VoidCallback onSaved) => MaterialApp(
        navigatorKey: navigator,
        theme: CoeloTheme.light,
        home: ChildSafetyWizardPage(
          controller: controller,
          childId: 'child-a',
          logout: _logout,
          onCancel: () {},
          onSaved: onSaved,
        ),
      );
      await tester.pumpWidget(page(original));
      await tester.pumpAndSettle();
      final primary = find.byKey(const Key('safety-wizard-primary'));
      await tester.tap(primary);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'person-a');
      await tester.enterText(find.byType(TextField).last, 'Solicitação sintética');
      await tester.tap(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pump();
      expect(repository.savedCommands, hasLength(1));
      if (replacement != 'unchanged') {
        await tester.pumpWidget(page(replacementHandler));
        await tester.pump();
        if (replacement == 'replaced-and-restored') {
          await tester.pumpWidget(page(original));
          await tester.pump();
        }
      }
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Destino novo'), findsNothing);
      expect(
        find.text('Destino original'),
        replacement == 'unchanged' ? findsOneWidget : findsNothing,
      );
      expect(repository.savedCommands, hasLength(1));
      if (replacement != 'unchanged') {
        expect(find.byType(ChildSafetyWizardPage), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
        await tester.pumpAndSettle();
        expect(find.text('Solicitação sintética'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wizard never reports an old save through the new context callback', (tester) async {
    await _surface(tester);
    final repository = _Repository('Escopo A');
    final pending = Completer<void>();
    repository.pendingSave = pending.future;
    final oldController = ChildSafetyController(repository);
    final controller = ChildSafetyController(_Repository('Escopo B'));
    addTearDown(oldController.dispose);
    addTearDown(controller.dispose);
    var oldSaved = 0;
    var newSaved = 0;
    await tester.pumpWidget(_wizard(oldController, 'child-a', onSaved: () => oldSaved++));
    await tester.pumpAndSettle();
    final primary = find.byKey(const Key('safety-wizard-primary'));
    await tester.tap(primary);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'person-a');
    await tester.enterText(find.byType(TextField).last, 'Solicitação sintética');
    await tester.tap(primary);
    await tester.pumpAndSettle();
    await tester.tap(primary);
    await tester.pumpAndSettle();
    await tester.tap(primary);
    await tester.pump();
    expect(repository.savedCommands, hasLength(1));
    await tester.pumpWidget(_wizard(controller, 'child-b', onSaved: () => newSaved++));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(oldSaved, 0);
    expect(newSaved, 0);
    expect(find.text('child-b · Escopo B'), findsWidgets);
  });
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Widget _detail(ChildSafetyController controller, String childId) => MaterialApp(
  theme: CoeloTheme.light,
  home: ChildSecurityPage(childId: childId, controller: controller, logout: _logout, onBack: () {}),
);

Widget _directory(ChildSafetyController controller) => MaterialApp(
  theme: CoeloTheme.light,
  home: SafetyLandingPage(controller: controller, logout: _logout, onOpenChild: (_) {}),
);

Widget _wizard(ChildSafetyController controller, String? childId, {VoidCallback? onSaved}) =>
    MaterialApp(
      theme: CoeloTheme.light,
      home: ChildSafetyWizardPage(
        controller: controller,
        childId: childId,
        logout: _logout,
        onCancel: () {},
        onSaved: onSaved ?? () {},
      ),
    );

final class _Repository implements ChildSafetyRepository {
  _Repository(this.scope);
  final String scope;
  final childReads = <String>[];
  int directoryReads = 0;
  Exception? directoryFailure;
  Future<ChildSafetyRecord?>? pending;
  Future<List<ChildSafetyChildOption>>? pendingSearch;
  Future<void>? pendingSave;
  final savedCommands = <SavePickupAuthorizationCommand>[];

  ChildSafetyRecord record(String id) => ChildSafetyRecord(
    childId: id,
    childName: '$id · $scope',
    internalId: id,
    institutionName: scope,
    unitName: 'Unidade sintética',
    authorizations: const [],
    childContextId: 'context-$id',
    institutionId: 'institution-$scope',
    unitId: 'unit-$scope',
  );

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    childReads.add(childId);
    return pending == null ? record(childId) : await pending;
  }

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    directoryReads++;
    if (directoryFailure case final failure?) throw failure;
    return ChildSafetyDirectoryPage(
      records: [record('child-a')],
      totalCount: 1,
      canCreate: false,
      segmentCounts: const ChildSafetySegmentCounts(all: 1),
    );
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async =>
      pendingSearch == null ? [] : await pendingSearch!;
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    savedCommands.add(command);
    await pendingSave;
  }

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) => throw UnimplementedError();
}
