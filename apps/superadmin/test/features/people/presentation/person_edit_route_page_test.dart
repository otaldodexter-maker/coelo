import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/presentation/person_edit_route_page.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('loads detail once and composes the edit form', (tester) async {
    final repository = FakePersonDirectoryRepository();
    await tester.pumpWidget(_app(repository, 'person-0'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonFormPage), findsOneWidget);
    expect(find.text('Editar pessoa'), findsWidgets);
  });

  testWidgets('shows unauthorized detail state', (tester) async {
    await tester.pumpWidget(_app(FakePersonDirectoryRepository(unauthorized: true), 'person-0'));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });
}

Widget _app(FakePersonDirectoryRepository repository, String id) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PersonEditRoutePage(
          personId: id,
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    ],
  );
  return MaterialApp.router(theme: CoeloTheme.light, routerConfig: router);
}
