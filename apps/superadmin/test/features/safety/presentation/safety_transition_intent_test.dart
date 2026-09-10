import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingRepository implements ChildSafetyRepository, ChildSafetyMutationSupport {
  _RecordingRepository({this.failTransitions = 0});

  final ChildSafetyRepository _delegate = DevChildSafetyRepository.content();
  final transitions = <TransitionPickupAuthorizationCommand>[];
  int failTransitions;

  @override
  bool get mutationsEnabled => true;

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) =>
      _delegate.fetchDirectory(query);

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) => _delegate.fetchChild(childId);

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) =>
      _delegate.searchChildren(query, limit: limit);

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) =>
      _delegate.saveAuthorization(command);

  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) =>
      _delegate.suspendAuthorization(command);

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) => _delegate.requestExport(command);

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {
    transitions.add(command);
    if (failTransitions > 0) {
      failTransitions -= 1;
      throw const ChildSafetyUnavailableException();
    }
    await _delegate.transitionAuthorization(command);
  }
}

Future<String> _pendingChildId(ChildSafetyRepository repository) async {
  final page = await repository.fetchDirectory(
    ChildSafetyDirectoryQuery(segment: ChildSafetyDirectorySegment.awaitingApproval),
  );
  return page.records.first.childId;
}

/// Tapping without securing visibility is how a control that moved below the
/// fold turns into a silent failure. Content inserted above one is enough.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('retrying a failed approval repeats the same decision', (tester) async {
    final repository = _RecordingRepository(failTransitions: 1);
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);
    await controller.load();
    final childId = await _pendingChildId(repository);

    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ChildSecurityPage(
          childId: childId,
          controller: controller,
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rows list the active authorization and the pending request; only the
    // pending one offers approval, so open managers until that one appears.
    final managers = find.text('Gerenciar').evaluate().length;
    var opened = false;
    for (var index = 0; index < managers && !opened; index++) {
      await _tap(tester, find.text('Gerenciar').at(index));
      if (find.widgetWithText(FilledButton, 'Aprovar').evaluate().isNotEmpty) {
        opened = true;
      } else {
        await _tap(tester, find.widgetWithText(FilledButton, 'Concluir'));
      }
    }
    expect(opened, isTrue, reason: 'a pending authorization must offer approval');

    final approve = find.widgetWithText(FilledButton, 'Aprovar');

    await _tap(tester, approve);
    expect(repository.transitions, hasLength(1));
    expect(
      find.widgetWithText(FilledButton, 'Aprovar'),
      findsOneWidget,
      reason: 'the failed command leaves the dialog open, so the retry is one tap away',
    );

    await _tap(tester, find.widgetWithText(FilledButton, 'Aprovar'));

    expect(repository.transitions, hasLength(2));
    expect(
      repository.transitions.first.requestId,
      repository.transitions.last.requestId,
      reason: 'approving the same authorization twice is one decision retried, not two decisions',
    );
  });

  testWidgets('rejecting after a failed approval is a different decision', (tester) async {
    final repository = _RecordingRepository(failTransitions: 2);
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);
    await controller.load();
    final childId = await _pendingChildId(repository);

    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ChildSecurityPage(
          childId: childId,
          controller: controller,
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final managers = find.text('Gerenciar').evaluate().length;
    var opened = false;
    for (var index = 0; index < managers && !opened; index++) {
      await _tap(tester, find.text('Gerenciar').at(index));
      if (find.widgetWithText(FilledButton, 'Aprovar').evaluate().isNotEmpty) {
        opened = true;
      } else {
        await _tap(tester, find.widgetWithText(FilledButton, 'Concluir'));
      }
    }
    expect(opened, isTrue);

    await _tap(tester, find.widgetWithText(FilledButton, 'Aprovar'));
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Rejeitar'));

    expect(repository.transitions, hasLength(2));
    expect(
      repository.transitions.first.requestId,
      isNot(repository.transitions.last.requestId),
      reason: 'changing the decision must not reuse the key of the one abandoned',
    );
  });
}
