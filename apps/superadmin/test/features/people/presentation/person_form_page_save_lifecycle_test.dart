import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_view_model.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  testWidgets('duplicate captured save callback delivers one completion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _PendingRepository();
    var savedCalls = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => PersonFormPage(
            repository: repository,
            logout: () async => const LogoutResult.success(),
            original: _person,
            onSaved: (_) => savedCalls++,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
    final callback = tester
        .widget<FilledButton>(find.byKey(const Key('person-form-save')))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(repository.updateCalls, 1);
    repository.pending.complete(_person);
    await tester.pumpAndSettle();
    expect(savedCalls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('disposed page discards ${fail ? 'error' : 'receipt'}', (tester) async {
      final repository = _PendingRepository();
      var callbacks = 0;
      await _mount(tester, repository, onSaved: (_) => callbacks++);
      await _startSave(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      if (fail) {
        repository.pending.completeError(const PersonDirectoryUnavailableException());
      } else {
        repository.pending.complete(_person);
      }
      await tester.pumpAndSettle();
      expect(callbacks, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final changeRepository in [false, true]) {
    testWidgets(
      'replacement ${changeRepository ? 'repository' : 'person'} resets state and drops old receipt',
      (tester) async {
        final repository = _PendingRepository();
        final replacementRepository = _PendingRepository();
        final nextPerson = FakePersonDirectoryRepository.samplePeople[3];
        var callbacks = 0;
        final inputs = ValueNotifier((repository: repository, person: _person));
        addTearDown(inputs.dispose);
        await _mount(tester, repository, onSaved: (_) => callbacks++, inputs: inputs);
        await _startSave(tester);
        inputs.value = (
          repository: changeRepository ? replacementRepository : repository,
          person: changeRepository ? _person : nextPerson,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('person-first-name-field')), findsOneWidget);
        final field = tester.widget<TextFormField>(
          find.byKey(const Key('person-display-name-field')),
        );
        expect(field.controller!.text, inputs.value.person.displayName);
        repository.pending.complete(_person);
        await tester.pumpAndSettle();
        expect(callbacks, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('newer identity edit suppresses old save callback without losing text', (
    tester,
  ) async {
    final repository = _PendingRepository();
    var callbacks = 0;
    await _mount(tester, repository, onSaved: (_) => callbacks++);
    await _startSave(tester);
    await tester.tap(find.text('Identidade').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('person-display-name-field')), 'Later intent');
    repository.pending.complete(_person);
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(find.text('Later intent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save releases page retry and emits one later success', (tester) async {
    final repository = _PendingRepository();
    var callbacks = 0;
    await _mount(tester, repository, onSaved: (_) => callbacks++);
    await _startSave(tester);
    repository.pending.completeError(const PersonDirectoryConflictException());
    await tester.pumpAndSettle();
    expect(find.text('A pessoa foi alterada em outra sessão. Recarregue.'), findsOneWidget);
    expect(callbacks, 0);
    repository.pending = Completer<PersonDirectoryItem>();
    await tester.tap(find.byKey(const Key('person-form-save')));
    await tester.pump();
    expect(repository.updateCalls, 2);
    repository.pending.complete(_person);
    await tester.pumpAndSettle();
    expect(callbacks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement ignores stale save error', (tester) async {
    final repository = _PendingRepository();
    final nextRepository = _PendingRepository();
    var callbacks = 0;
    final inputs = ValueNotifier((repository: repository, person: _person));
    addTearDown(inputs.dispose);
    await _mount(tester, repository, onSaved: (_) => callbacks++, inputs: inputs);
    await _startSave(tester);
    inputs.value = (repository: nextRepository, person: _person);
    await tester.pumpAndSettle();
    repository.pending.completeError(const PersonDirectoryConflictException());
    await tester.pumpAndSettle();
    expect(find.text('A pessoa foi alterada em outra sessão. Recarregue.'), findsNothing);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new contextual patch suppresses earlier receipt and remains intact', (tester) async {
    final repository = _PendingRepository();
    var callbacks = 0;
    await _mount(tester, repository, onSaved: (_) => callbacks++);
    await _startSave(tester);
    final builder = tester.widget<AnimatedBuilder>(
      find.byWidgetPredicate(
        (widget) => widget is AnimatedBuilder && widget.animation is PersonFormViewModel,
      ),
    );
    final model = builder.animation as PersonFormViewModel;
    const membership = PersonMembership(
      id: 'later',
      institutionId: 'institution',
      institutionName: 'Synthetic institution',
      role: 'guardian',
    );
    model.addMembership(membership);
    repository.pending.complete(_person);
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(model.membershipChanges.single.membership, same(membership));
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('replacement ignores old filter option ${fail ? 'failure' : 'success'}', (
      tester,
    ) async {
      final options = Completer<PersonDirectoryFilterOptions>();
      final repository = _PendingRepository(options: options);
      final replacement = _PendingRepository();
      final inputs = ValueNotifier((repository: repository, person: _person));
      addTearDown(inputs.dispose);
      await _mount(tester, repository, onSaved: (_) {}, inputs: inputs);
      inputs.value = (repository: replacement, person: _person);
      await tester.pumpAndSettle();
      if (fail) {
        options.completeError(const PersonDirectoryUnavailableException());
      } else {
        options.complete(
          const PersonDirectoryFilterOptions(
            institutions: [PersonFilterOption('stale', 'Stale institution')],
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-form-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar os vínculos'), findsNothing);
        expect(find.text('Stale institution'), findsNothing);
        expect(find.byKey(const Key('person-membership-institution')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _mount(
  WidgetTester tester,
  _PendingRepository repository, {
  required ValueChanged<PersonDirectoryItem> onSaved,
  ValueNotifier<({_PendingRepository repository, PersonDirectoryItem person})>? inputs,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Widget page(_PendingRepository source, PersonDirectoryItem person) => PersonFormPage(
    key: const ValueKey('same-form'),
    repository: source,
    original: person,
    logout: () async => const LogoutResult.success(),
    onSaved: onSaved,
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => inputs == null
            ? page(repository, _person)
            : ValueListenableBuilder(
                valueListenable: inputs,
                builder: (context, value, child) => page(value.repository, value.person),
              ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _startSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('person-form-continue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('person-form-continue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('person-form-save')));
  await tester.pump();
}

final _person = FakePersonDirectoryRepository.samplePeople.first;

class _PendingRepository implements PersonDirectoryRepository {
  _PendingRepository({this.options});
  final Completer<PersonDirectoryFilterOptions>? options;
  var pending = Completer<PersonDirectoryItem>();
  var updateCalls = 0;
  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) {
    updateCalls++;
    return pending.future;
  }

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() =>
      options?.future ?? Future.value(const PersonDirectoryFilterOptions());
  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) => throw UnimplementedError();
  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) => throw UnimplementedError();
  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => throw UnimplementedError();
}
