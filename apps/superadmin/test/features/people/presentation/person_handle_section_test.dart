import 'package:coelo_superadmin/features/people/domain/person_handle.dart';
import 'package:coelo_superadmin/features/people/presentation/person_handle_section.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regra do @ (ADR 0034, Decisão 16): o detalhe mostra o @, verifica
// disponibilidade enquanto digita e troca com motivo.
final class _FakeHandles implements PersonHandleRepository {
  _FakeHandles({required this.current});

  PersonHandle current;
  final Set<String> taken = const {'ana.souza1'};
  final List<String> changes = [];

  @override
  Future<PersonHandle?> fetch(String personId) async => current;

  @override
  Future<PersonHandleAvailability> checkAvailability(String handle, {String? personId}) async {
    if (handle.length < 3) return PersonHandleAvailability.invalidFormat;
    if (handle == 'coelo') return PersonHandleAvailability.reserved;
    if (taken.contains(handle)) return PersonHandleAvailability.taken;
    return PersonHandleAvailability.available;
  }

  @override
  Future<PersonHandle> change({
    required String requestId,
    required String personId,
    required String handle,
    required String reason,
  }) async {
    changes.add('$handle|$reason');
    return current = PersonHandle(
      personId: personId,
      handle: handle,
      canEdit: true,
      lastChangedAt: DateTime.now(),
      canChangeAt: DateTime.now().add(const Duration(days: 30)),
    );
  }
}

Widget _host(PersonHandleRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: PersonHandleSection(repository: repository, personId: 'p1'),
  ),
);

void main() {
  testWidgets('shows the handle and changes it after availability and reason', (tester) async {
    final repository = _FakeHandles(
      current: const PersonHandle(personId: 'p1', handle: 'ana.souza', canEdit: true),
    );
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    expect(find.text('ana.souza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('person-handle-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-handle-dialog')), findsOneWidget);
    FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('person-handle-save')));
    expect(save().onPressed, isNull, reason: '@ igual ao atual não salva');

    await tester.enterText(find.byKey(const Key('person-handle-field')), '@Ana.Souza1');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text(PersonHandleAvailability.taken.message), findsWidgets);
    expect(save().onPressed, isNull, reason: '@ tomado não salva');

    await tester.enterText(find.byKey(const Key('person-handle-field')), 'ana.nova');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNull, reason: 'sem motivo não salva');

    await tester.enterText(find.byKey(const Key('person-handle-reason')), 'prefiro assim');
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('person-handle-save')));
    await tester.pumpAndSettle();

    expect(repository.changes, ['ana.nova|prefiro assim']);
    expect(find.byKey(const Key('person-handle-dialog')), findsNothing);
    expect(find.text('ana.nova'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('person-handle-change'))).onPressed,
      isNull,
      reason: 'em cooldown de 30 dias o botão fica desabilitado',
    );
  });

  testWidgets('read-only viewer sees the handle without the change action', (tester) async {
    await tester.pumpWidget(
      _host(
        _FakeHandles(
          current: const PersonHandle(personId: 'p1', handle: 'jose.avila', canEdit: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('jose.avila'), findsOneWidget);
    expect(find.byKey(const Key('person-handle-change')), findsNothing);
  });
}
