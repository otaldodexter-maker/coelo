import 'dart:async';

import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_repository.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_approvals_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_requests_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('approval decision inherits local dark theme', (tester) async {
    final repository = _Repository('A');
    final current = ValueNotifier<AgendaRepository>(repository);
    addTearDown(repository.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current, localTheme: CoeloTheme.dark);
    await _open(tester);
    expect(
      Theme.of(tester.element(find.byKey(const Key('agenda-approval-reason')))).brightness,
      Brightness.dark,
    );
  });
  testWidgets('successful decision cannot pop a newer navigator route', (tester) async {
    final pending = Completer<AgendaMutationResult>();
    final repository = _Repository('A')..decision = () => pending.future;
    final current = ValueNotifier<AgendaRepository>(repository);
    addTearDown(repository.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current);
    await _open(tester);
    final navigator = Navigator.of(tester.element(find.byKey(const Key('agenda-approval-reason'))));
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
    await tester.pump();
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('New route'))),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(AgendaMutationResult.success);
    await tester.pumpAndSettle();
    expect(find.text('New route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-approval-reason')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('late ${fail ? 'error' : 'success'} cannot close a replacement decision', (
      tester,
    ) async {
      final pending = Completer<AgendaMutationResult>();
      final first = _Repository('A')..decision = () => pending.future;
      final second = _Repository('B');
      final current = ValueNotifier<AgendaRepository>(first);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(current.dispose);
      await _pump(tester, current);
      await _open(tester);
      await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
      await tester.pump();
      current.value = second;
      await tester.pumpAndSettle();
      await _open(tester);
      if (fail) {
        pending.completeError(Exception('old context transport'));
      } else {
        pending.complete(AgendaMutationResult.success);
      }
      await tester.pumpAndSettle();
      expect(find.text('Publication B · Context B'), findsOneWidget);
      expect(find.byKey(const Key('agenda-approval-reason')), findsOneWidget);
      expect(first.decisions, 1);
      expect(second.decisions, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
      await tester.pumpAndSettle();
      expect(second.decisions, 1);
      expect(find.byKey(const Key('agenda-approval-reason')), findsNothing);
    });
  }

  for (final approvals in [false, true]) {
    testWidgets('replacement repository loads ${approvals ? 'approvals' : 'requests'}', (
      tester,
    ) async {
      final first = _Repository('A');
      final second = _Repository('B');
      final current = ValueNotifier<AgendaRepository>(first);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(current.dispose);
      await _pump(tester, current, approvals: approvals);
      expect(first.loads, 1);
      current.value = second;
      await tester.pumpAndSettle();
      expect(second.loads, 1);
      expect(first.loads, 1);
    });
  }

  testWidgets('repository replacement dismisses an old approval without cross-context write', (
    tester,
  ) async {
    final first = _Repository('A');
    final second = _Repository('B');
    final current = ValueNotifier<AgendaRepository>(first);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current);
    await _open(tester);
    current.value = second;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-approval-reason')), findsNothing);
    expect(find.text('Publication A · Context A'), findsNothing);
    expect(first.decisions, 0);
    expect(second.decisions, 0);
  });

  testWidgets('authorization loss dismisses a decision from the same repository', (tester) async {
    final repository = _Repository('A');
    final current = ValueNotifier<AgendaRepository>(repository);
    addTearDown(repository.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current);
    await _open(tester);
    repository.deny();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-approval-reason')), findsNothing);
    expect(repository.decisions, 0);
  });

  testWidgets('decision is single-flight before the disabled button rebuilds', (tester) async {
    final pending = Completer<AgendaMutationResult>();
    final repository = _Repository('A')..decision = () => pending.future;
    final current = ValueNotifier<AgendaRepository>(repository);
    addTearDown(repository.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current);
    await _open(tester);
    final confirm = find.byKey(const Key('agenda-approval-confirm-approve'));
    await tester.tap(confirm);
    await tester.tap(confirm);
    expect(repository.decisions, 1);
    pending.complete(AgendaMutationResult.success);
    await tester.pumpAndSettle();
  });

  testWidgets('transport exception leaves a retryable decision without raw details', (
    tester,
  ) async {
    final repository = _Repository('A')
      ..decision = () => Future.error(Exception('private transport detail'));
    final current = ValueNotifier<AgendaRepository>(repository);
    addTearDown(repository.dispose);
    addTearDown(current.dispose);
    await _pump(tester, current);
    await _open(tester);
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Não foi possível registrar'), findsOneWidget);
    expect(find.textContaining('private transport detail'), findsNothing);
    repository.decision = () async => AgendaMutationResult.success;
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
    await tester.pumpAndSettle();
    expect(repository.decisions, 2);
    expect(find.byKey(const Key('agenda-approval-reason')), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<AgendaRepository> current, {
  bool approvals = true,
  ThemeData? localTheme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Theme(
          data: localTheme ?? CoeloTheme.light,
          child: ValueListenableBuilder<AgendaRepository>(
            valueListenable: current,
            builder: (context, repository, _) => approvals
                ? AgendaApprovalsPage(key: const Key('collection'), store: repository)
                : AgendaRequestsPage.production(key: const Key('collection'), store: repository),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  final action = find.byKey(const Key('agenda-approval-decide-request'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('agenda-approval-reason')), 'Approved scope checked');
}

class _Repository extends AgendaRepository {
  _Repository(this.label);
  final String label;
  int loads = 0;
  int decisions = 0;
  AgendaReadStatus _read = AgendaReadStatus.idle;
  Future<AgendaMutationResult> Function() decision = () async => AgendaMutationResult.success;
  @override
  AgendaReadStatus get requestsRead => _read;
  @override
  List<GuardianBirthdayRequest> get requests => [];
  @override
  List<AgendaPublicationRequest> get publicationRequests => [
    AgendaPublicationRequest(
      id: 'request',
      itemId: 'event',
      title: 'Publication $label',
      contextLabel: 'Context $label',
      requestedBy: 'Requester $label',
      requestedAt: DateTime(2026, 9, 7),
    ),
  ];
  @override
  Future<void> loadRequests() async {
    loads++;
    _read = AgendaReadStatus.ready;
  }

  void deny() {
    _read = AgendaReadStatus.unauthorized;
    notifyListeners();
  }

  @override
  Future<AgendaMutationResult> decidePublicationRequest({
    required String requestId,
    required bool approve,
    required String decidedBy,
    required String reason,
  }) {
    decisions++;
    return decision();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
