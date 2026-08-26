import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  testWidgets('renders the real empty state when the authorized scope has no people', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakePersonDirectoryRepository(seed: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pessoa cadastrada'), findsOneWidget);
    expect(find.text('Crie a primeira pessoa para começar.'), findsOneWidget);
  });

  testWidgets('renders no-results separately after a server-side search returns no rows', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakePersonDirectoryRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Buscar pessoas por nome'), 'sem-correspondência');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.text('Revise a busca ou os filtros aplicados.'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsWidgets);
  });
}

Widget _app(FakePersonDirectoryRepository repository) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PersonDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    ],
  );
  return MaterialApp.router(theme: CoeloTheme.light, routerConfig: router);
}
