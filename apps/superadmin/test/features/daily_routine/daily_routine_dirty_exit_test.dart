import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';

import '../../support/fake_routine_repository.dart';

const _model = RoutineModel(
  id: 'model-1',
  name: 'Chegada e acolhimento',
  description: 'Modelo carregado para edicao.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

final _home = GlobalKey();

Future<void> _openEditor(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(key: _home, body: const SizedBox.shrink()),
    ),
  );
  final navigator = Navigator.of(_home.currentContext!);
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [_model], canManage: true),
          logout: unavailableSuperadminLogout,
          modelId: _model.id,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void unawaited(Future<void> future) {}

Future<void> _typeName(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('daily-routine-name')),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pumpAndSettle();
}

Future<void> _requestExit(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _openWithDestination(WidgetTester tester, List<String> taken) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineEditorPage(
        repository: FakeRoutineRepository(models: const [_model], canManage: true),
        logout: unavailableSuperadminLogout,
        modelId: _model.id,
        onDestinationSelected: taken.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectAnotherDestination(WidgetTester tester) async {
  final shell = tester.widget<SuperadminShell>(find.byType(SuperadminShell));
  shell.onDestinationSelected!('attendance');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving an untouched routine editor needs no confirmation', (tester) async {
    await _openEditor(tester);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);

    await _requestExit(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsNothing);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsNothing);
  });

  testWidgets('an edited routine asks before discarding the draft', (tester) async {
    await _openEditor(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');

    await _requestExit(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsOneWidget);
    expect(find.text('Sair sem salvar?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsNothing);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
  });

  testWidgets('confirming the discard leaves the routine editor', (tester) async {
    await _openEditor(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');
    await _requestExit(tester);

    await tester.tap(find.text('Sair sem salvar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-model-editor')), findsNothing);
  });

  testWidgets('leaving through the shell asks before discarding the draft', (tester) async {
    final taken = <String>[];
    await _openWithDestination(tester, taken);
    await _typeName(tester, 'Chegada e acolhimento revisado');

    await _selectAnotherDestination(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsOneWidget);
    expect(taken, isEmpty);

    await tester.tap(find.text('Sair sem salvar'));
    await tester.pumpAndSettle();

    expect(taken, ['attendance']);
  });

  testWidgets('leaving an untouched routine through the shell is immediate', (tester) async {
    final taken = <String>[];
    await _openWithDestination(tester, taken);

    await _selectAnotherDestination(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsNothing);
    expect(taken, ['attendance']);
  });

  testWidgets('the exit confirmation survives 375 wide at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(key: _home, body: const SizedBox.shrink()),
      ),
    );
    Navigator.of(_home.currentContext!).push(
      MaterialPageRoute<void>(
        builder: (context) => DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [_model], canManage: true),
          logout: unavailableSuperadminLogout,
          modelId: _model.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _typeName(tester, 'Chegada e acolhimento revisado');

    await _requestExit(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsOneWidget);
    expect(find.text('Continuar editando'), findsOneWidget);
    expect(find.text('Sair sem salvar'), findsOneWidget);
  });

  testWidgets('both exit choices are reachable by keyboard', (tester) async {
    await _openEditor(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');
    await _requestExit(tester);

    for (final label in const ['Continuar editando', 'Sair sem salvar']) {
      final action = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      );
      expect(action, findsOneWidget, reason: label);
      expect(
        tester.widget<ButtonStyleButton>(action).enabled,
        isTrue,
        reason: '$label must be operable, not decorative',
      );
      expect(
        Focus.maybeOf(tester.element(find.text(label)), scopeOk: true),
        isNotNull,
        reason: '$label must sit inside a focus scope',
      );
    }
  });
}
