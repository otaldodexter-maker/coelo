import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A load that fails has to say so, whatever kind of failure it was.
///
/// The context load caught `on Exception`, which does not catch an `Error`. An
/// Error there fell through every catch and left `_loading` true, so the screen
/// kept its spinner and never said anything - a frozen product rather than a
/// failure. It is the fourth place in this round where that same catch could
/// have done it; the other three were a refused save that produced no reaction,
/// and two view models that swallowed a failure whole.
///
/// The screen it lands on matters as much as the catch. On a load failure the
/// form is not drawn at all: the build replaces it with a state panel whose only
/// action is going back. That is what makes the empty-member hazard unreachable
/// through this path - a save cannot be pressed on a form that was never drawn,
/// so an empty member set only ever travels after a load that worked, where
/// empty honestly means empty.
final class _FailingRepository implements GroupDirectoryRepository {
  _FailingRepository(this.failure);

  /// Thrown from the context read, which is the first thing the form needs.
  final Object failure;

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) async {
    throw failure;
  }

  @override
  Future<GroupRecord?> findById(String id) async => null;

  @override
  String createId(String institutionId, String unitId, String name) => 'group-1';

  @override
  Future<void> upsert(GroupRecord record) async {}

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) async =>
      throw UnimplementedError('a failed load must never reach a save');

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) async =>
      throw UnimplementedError();

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async => throw UnimplementedError();

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) async =>
      throw UnimplementedError();
}

Widget _page(Object failure) => MaterialApp(
  theme: CoeloTheme.light,
  home: GroupFormPage(
    repository: _FailingRepository(failure),
    logout: unavailableSuperadminLogout,
    onCancel: () {},
    onSaved: (_) {},
  ),
);

void main() {
  for (final failure in <({String name, Object value})>[
    (name: 'an Exception', value: const GroupDirectoryUnavailableException()),
    (name: 'an Error', value: StateError('a bug, not a backend')),
    (name: 'a plain object', value: 'nem excecao nem erro'),
  ]) {
    testWidgets('${failure.name} on the context read reaches a state a person can act on', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_page(failure.value));
      await tester.pumpAndSettle();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a spinner that never stops is how a failure looks like a freeze',
      );
      expect(find.byKey(const Key('group-form-load-error')), findsOneWidget);
      expect(find.text('Voltar às turmas'), findsOneWidget);
    });
  }

  testWidgets('the form itself is never drawn, so no save can be pressed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_page(StateError('a bug, not a backend')));
    await tester.pumpAndSettle();

    // The repository throws UnimplementedError from saveComposition, so if a
    // save were reachable the test would fail loudly rather than silently.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Salvar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
