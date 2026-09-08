import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart' as domain;
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Pessoas directory has no reload button. Its only way back from a failed
/// read is the "Tentar novamente" action inside the failure panel, and no test
/// ever pressed it - the one test that reaches this state asserts the label
/// exists and stops there.
///
/// A retry that does not retry is the worst kind of dead control: the operator
/// presses it, the same screen comes back, and they conclude the data is gone
/// rather than that the button is broken.
final class _FailingThenWorkingRepository implements domain.PersonDirectoryRepository {
  _FailingThenWorkingRepository({this.failure = const domain.PersonDirectoryUnavailableException()});

  final Object failure;
  var reads = 0;
  var failUntil = 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.PersonDirectoryPage> fetchPage(domain.PersonDirectoryQuery query) async {
    reads++;
    if (reads <= failUntil) throw failure;
    return const domain.PersonDirectoryPage(
      items: <domain.PersonDirectoryItem>[],
      totalCount: 0,
      page: 1,
      pageSize: 11,
    );
  }

  @override
  Future<domain.PersonDirectoryFilterOptions> fetchFilterOptions() async =>
      const domain.PersonDirectoryFilterOptions();
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

void main() {
  Future<_FailingThenWorkingRepository> pumpFailed(
    WidgetTester tester, {
    Object failure = const domain.PersonDirectoryUnavailableException(),
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailingThenWorkingRepository(failure: failure);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PersonDirectoryPage(repository: repository, logout: _logout),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('a failed read offers a retry that genuinely reads again', (tester) async {
    final repository = await pumpFailed(tester);
    expect(find.text('Não foi possível carregar as pessoas'), findsOneWidget);
    expect(repository.reads, 1);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.reads, 2, reason: 'the control must issue a read, not just repaint');
    expect(find.text('Não foi possível carregar as pessoas'), findsNothing);
  });

  testWidgets('a retry that fails again says so instead of pretending to recover', (tester) async {
    final repository = await pumpFailed(tester)..failUntil = 5;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.reads, 2);
    expect(find.text('Não foi possível carregar as pessoas'), findsOneWidget);
    // And it stays pressable, because the next attempt may be the one that works.
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('a denial offers no retry, because retrying cannot help', (tester) async {
    await pumpFailed(tester, failure: const domain.PersonDirectoryUnauthorizedException());
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });
}
