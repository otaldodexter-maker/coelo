import 'package:coelo_superadmin/features/people/domain/person_identity.dart';
import 'package:coelo_superadmin/features/people/presentation/person_identity_lookup_gate.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps creation fail closed until a successful not-found resolution', (tester) async {
    final repository = _IdentityRepository()..results = const [];

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('person-creation-form')), findsNothing);
    await _submit(tester, 'nova@coelo.me');
    expect(find.byKey(const Key('person-creation-form')), findsOneWidget);
    expect(repository.resolveCalls, 1);
  });

  testWidgets('existing identity never exposes creation and opens the authorized record', (
    tester,
  ) async {
    final repository = _IdentityRepository()
      ..results = const [
        PersonIdentityCandidate(
          personId: 'person-1',
          displayName: 'Ana Coelho',
          personType: 'adult',
          matchedBy: PersonIdentityLookupKind.email,
          maskedMatch: 'a***@coelo.me',
          access: PersonIdentityResolutionAccess.editGlobal,
        ),
      ];
    String? opened;

    await tester.pumpWidget(_app(repository, onExistingPerson: (id) => opened = id));
    await _submit(tester, 'ana@coelo.me');

    expect(find.byKey(const Key('person-creation-form')), findsNothing);
    expect(find.text('Ana Coelho'), findsOneWidget);
    final open = find.text('Abrir pessoa');
    await tester.ensureVisible(open);
    await tester.tap(open);
    expect(opened, 'person-1');
  });

  testWidgets('access denied discloses no candidate and remains fail closed', (tester) async {
    final repository = _IdentityRepository()..error = const PersonIdentityAccessDeniedException();

    await tester.pumpWidget(_app(repository));
    await _submit(tester, 'segredo@coelo.me');

    expect(find.textContaining('não tem permissão'), findsOneWidget);
    expect(find.byKey(const Key('person-creation-form')), findsNothing);
    expect(find.byKey(const Key('person-identity-candidate-person-1')), findsNothing);
  });

  testWidgets('no-access resolution is opaque and cannot authorize creation', (tester) async {
    final repository = _IdentityRepository()
      ..results = const [
        PersonIdentityCandidate(
          personId: 'private-person',
          displayName: 'Nome privado',
          personType: 'adult',
          matchedBy: PersonIdentityLookupKind.email,
          maskedMatch: 'p***@coelo.me',
          access: PersonIdentityResolutionAccess.noAccess,
        ),
      ];

    await tester.pumpWidget(_app(repository));
    await _submit(tester, 'privado@coelo.me');

    expect(find.text('Nome privado'), findsNothing);
    expect(find.text('p***@coelo.me'), findsNothing);
    expect(find.textContaining('não tem permissão'), findsOneWidget);
    expect(find.byKey(const Key('person-creation-form')), findsNothing);
  });

  testWidgets('transient failure supports retry without bypassing resolution', (tester) async {
    final repository = _IdentityRepository()..error = const PersonIdentityUnavailableException();

    await tester.pumpWidget(_app(repository));
    await _submit(tester, 'nova@coelo.me');
    expect(find.textContaining('Tente novamente'), findsOneWidget);
    expect(find.byKey(const Key('person-creation-form')), findsNothing);

    repository
      ..error = null
      ..results = const [];
    await tester.tap(find.byKey(const Key('person-identity-lookup-submit')));
    await tester.pumpAndSettle();

    expect(repository.resolveCalls, 2);
    expect(find.byKey(const Key('person-creation-form')), findsOneWidget);
  });

  testWidgets('unavailable repository cannot be bypassed through the route surface', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const UnavailablePersonIdentityRepository()));
    await _submit(tester, 'nova@coelo.me');

    expect(find.byKey(const Key('person-creation-form')), findsNothing);
    expect(find.textContaining('Tente novamente'), findsOneWidget);
  });

  testWidgets('Escape cancels without exposing the creation form', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      _app(const UnavailablePersonIdentityRepository(), onCancel: () => cancelled = true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelled, isTrue);
    expect(find.byKey(const Key('person-creation-form')), findsNothing);
  });
}

Widget _app(
  PersonIdentityRepository repository, {
  ValueChanged<String>? onExistingPerson,
  VoidCallback? onCancel,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: PersonIdentityLookupGate(
    repository: repository,
    onExistingPerson: onExistingPerson ?? (_) {},
    onCancel: onCancel ?? () {},
    formBuilder: (_) => const SizedBox(key: Key('person-creation-form')),
  ),
);

Future<void> _submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const Key('person-identity-lookup-field')), query);
  await tester.tap(find.byKey(const Key('person-identity-lookup-submit')));
  await tester.pumpAndSettle();
}

final class _IdentityRepository implements PersonIdentityRepository {
  List<PersonIdentityCandidate> results = const [];
  Object? error;
  int resolveCalls = 0;

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) async {
    resolveCalls++;
    if (error case final error?) throw error;
    return results;
  }

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) async =>
      PersonHandleCheck(handle: handle, availability: PersonHandleAvailability.available);
}
