import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart' as domain;
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

/// Two defects about a question surviving the answer, both reported by C07
/// through C06 and both verified here before changing anything.
///
/// The failure path rewrote `_query` to a blank query inside both catch blocks.
/// The retry then asked a different question from the one the operator asked,
/// while the search field still showed their term: the whole directory came
/// back under an apparently active search. The three sibling directories only
/// assign their query in setters, never in a catch.
///
/// Only the ordinary-failure branch was wrong. Revocation clears the query on
/// purpose - the filters name institutions, units and groups the actor may no
/// longer see - and an existing test already pinned that. Removing both resets
/// broke it, which is how I learned the two branches are not the same case.
///
/// And the screen offers "Limpar filtros" twice. The toolbar cleared the search
/// field first; the no-results panel did not. Same label, two results, one of
/// them leaving a term in a box that no longer filtered anything.
final class _FailingOnceRepository implements domain.PersonDirectoryRepository {
  final queries = <domain.PersonDirectoryQuery>[];
  var failNext = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.PersonDirectoryPage> fetchPage(domain.PersonDirectoryQuery query) async {
    queries.add(query);
    if (failNext) {
      failNext = false;
      throw const domain.PersonDirectoryUnavailableException();
    }
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
  testWidgets('a failed read keeps the question the operator asked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailingOnceRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PersonDirectoryPage(repository: repository, logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.bySemanticsLabel('Buscar pessoas por nome');
    await tester.enterText(search, 'ana');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'ana');

    repository.failNext = true;
    await tester.enterText(search, 'ana lima');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as pessoas'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(
      repository.queries.last.search,
      'ana lima',
      reason: 'the retry must ask what the search field still says it is asking',
    );
  });

  testWidgets('both ways of clearing the filters do the same thing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PersonDirectoryPage(repository: FakePersonDirectoryRepository(), logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    // A term that matches nobody puts the screen in the no-results state, which
    // is where the second affordance lives.
    final search = find.bySemanticsLabel('Buscar pessoas por nome');
    await tester.enterText(search, 'zzzzzz sem correspondencia');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado'), findsOneWidget);

    // Two controls carry the label now. The panel's sits below the toolbar's in
    // the tree, and it is the one that used to behave differently.
    final clear = find.text('Limpar filtros');
    expect(clear, findsNWidgets(2), reason: 'the screen offers it twice, which is the point');
    await tester.tap(clear.last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.descendant(of: search, matching: find.byType(TextField)))
          .controller
          ?.text,
      isEmpty,
      reason: 'clearing the filters has to clear the box that shows one',
    );
    expect(find.text('Nenhum resultado'), findsNothing);
  });
}
