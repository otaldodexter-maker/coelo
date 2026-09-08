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

final class _Repository implements ChildSafetyRepository {
  _Repository(this.scope);
  final String scope;
  final childReads = <String>[];
  int directoryReads = 0;
  Future<ChildSafetyRecord?>? pending;

  ChildSafetyRecord record(String id) => ChildSafetyRecord(
    childId: id,
    childName: '$id · $scope',
    internalId: id,
    institutionName: scope,
    unitName: 'Unidade sintética',
    authorizations: const [],
  );

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    childReads.add(childId);
    return pending == null ? record(childId) : await pending;
  }

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    directoryReads++;
    return ChildSafetyDirectoryPage(
      records: [record('child-a')],
      totalCount: 1,
      canCreate: false,
      segmentCounts: const ChildSafetySegmentCounts(all: 1),
    );
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async => [];
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) => throw UnimplementedError();
}
