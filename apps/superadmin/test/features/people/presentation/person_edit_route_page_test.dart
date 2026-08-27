import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_edit_route_page.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

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

  testWidgets('ignores stale person A when route changes to person B', (tester) async {
    final repository = _ControlledDetailRepository();
    await tester.pumpWidget(_SwitchingApp(repository: repository));

    await tester.tap(find.byKey(const Key('switch-to-person-b')));
    await tester.pump();

    repository.complete('person-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('person-form-person-1')), findsOneWidget);
    expect(tester.widget<PersonFormPage>(find.byType(PersonFormPage)).original?.id, 'person-1');

    repository.complete('person-0');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('person-form-person-0')), findsNothing);
    expect(tester.widget<PersonFormPage>(find.byType(PersonFormPage)).original?.id, 'person-1');
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

final class _SwitchingApp extends StatefulWidget {
  const _SwitchingApp({required this.repository});

  final PersonDirectoryRepository repository;

  @override
  State<_SwitchingApp> createState() => _SwitchingAppState();
}

final class _SwitchingAppState extends State<_SwitchingApp> {
  var _personId = 'person-0';

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: CoeloTheme.light,
    home: Stack(
      children: [
        PersonEditRoutePage(
          personId: _personId,
          repository: widget.repository,
          logout: () async => const LogoutResult.success(),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: TextButton(
            key: const Key('switch-to-person-b'),
            onPressed: () => setState(() => _personId = 'person-1'),
            child: const Text('Trocar'),
          ),
        ),
      ],
    ),
  );
}

final class _ControlledDetailRepository implements PersonDirectoryRepository {
  final _delegate = FakePersonDirectoryRepository();
  final _details = <String, Completer<PersonDirectoryItem>>{};

  void complete(String personId) =>
      _details[personId]!.complete(_delegate.people.firstWhere((person) => person.id == personId));

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) =>
      (_details[personId] ??= Completer<PersonDirectoryItem>()).future;

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => _delegate.fetchPage(query);

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) => _delegate.createDraft(draft);

  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) => _delegate.updatePerson(update);
}
