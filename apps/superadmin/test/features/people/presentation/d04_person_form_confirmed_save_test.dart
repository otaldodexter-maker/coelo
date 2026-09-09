import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  for (final create in [false, true]) {
    testWidgets('confirmed ${create ? 'create' : 'update'} retries navigation only', (
      tester,
    ) async {
      final repository = _Repository();
      var callbacks = 0;
      await _mount(
        tester,
        repository,
        create: create,
        onSaved: (_) {
          callbacks++;
          if (callbacks == 1) throw StateError('navigation failed');
        },
      );
      await _save(tester, create: create);
      repository.pending.complete(_person);
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível salvar a pessoa.'), findsNothing);
      expect(
        find.text('Pessoa salva. Não foi possível concluir a navegação. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('person-form-confirmed-save')), findsOneWidget);
      await tester.tap(find.text('Identidade').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-first-name-field')), findsNothing);
      await tester.tap(find.byKey(const Key('person-form-complete')));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(callbacks, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('repository replacement clears confirmed navigation and unlocks new form', (
    tester,
  ) async {
    final repository = _Repository();
    final replacement = _Repository();
    final inputs = ValueNotifier(repository);
    addTearDown(inputs.dispose);
    var callbacks = 0;
    await _mount(
      tester,
      repository,
      inputs: inputs,
      onSaved: (_) {
        callbacks++;
        throw StateError('navigation failed');
      },
    );
    await _save(tester);
    repository.pending.complete(_person);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-form-confirmed-save')), findsOneWidget);
    inputs.value = replacement;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-form-confirmed-save')), findsNothing);
    expect(find.byKey(const Key('person-first-name-field')), findsOneWidget);
    expect(callbacks, 1);
    expect(replacement.calls, 0);
  });
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  bool create = false,
  ValueNotifier<_Repository>? inputs,
  required ValueChanged<PersonDirectoryItem> onSaved,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Widget page(_Repository source) => PersonFormPage(
    key: const ValueKey('same-form'),
    repository: source,
    original: create ? null : _person,
    logout: () async => const LogoutResult.success(),
    onSaved: onSaved,
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => inputs == null
            ? page(repository)
            : ValueListenableBuilder(
                valueListenable: inputs,
                builder: (context, value, child) => page(value),
              ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, {bool create = false}) async {
  if (create) {
    await tester.enterText(find.byKey(const Key('person-first-name-field')), 'D04');
    await tester.enterText(find.byKey(const Key('person-last-name-field')), 'Synthetic');
    await tester.enterText(find.byKey(const Key('person-display-name-field')), 'D04 Synthetic');
  }
  for (var step = 0; step < 2; step++) {
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('person-form-save')));
  await tester.pump();
}

final _person = FakePersonDirectoryRepository.samplePeople.first;

class _Repository implements PersonDirectoryRepository {
  final pending = Completer<PersonDirectoryItem>();
  int calls = 0;
  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) {
    calls++;
    return pending.future;
  }

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) {
    calls++;
    return pending.future;
  }

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async =>
      const PersonDirectoryFilterOptions();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
