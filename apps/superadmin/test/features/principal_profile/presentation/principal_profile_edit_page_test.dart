import 'dart:async';

import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_edit_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proofs for `principal.profile-edit`.
///
/// Editing must load the authorized subject, persist through the server, re-read
/// after a successful save, and refuse to claim success on denial or conflict.
void main() {
  const context = PrincipalRuntimeContext(
    membershipId: 'membership-1',
    personId: 'person-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Autorizada',
    roleCode: 'staff',
    scopeKind: 'institution',
  );

  ProfileAboutPage pageWith(String body, {int version = 1}) => ProfileAboutPage(
    subject: const ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.institution,
      institutionId: 'institution-1',
    ),
    version: version,
    fields: const [],
    sections: [
      ProfileAboutSection(
        id: 'section-1',
        type: ProfileAboutSectionType.text,
        title: 'Nossa proposta',
        body: body,
        position: 0,
        state: ProfileAboutSectionState.published,
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    ProfileAboutRepository repository, {
    VoidCallback? onSaved,
    PrincipalRuntimeContext? runtimeContext,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(
          runtimeContext: runtimeContext ?? context,
          repository: repository,
          onSaved: onSaved,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads the About page of the authorized subject', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Conteúdo autorizado'));
    await pump(tester, repository);

    expect(repository.loaded.single.type, ProfileAboutSubjectType.institution);
    expect(repository.loaded.single.institutionId, 'institution-1');
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('persists through the server and re-reads the saved page', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    var confirmations = 0;
    await pump(tester, repository, onSaved: () => confirmations++);
    expect(repository.loaded, hasLength(1));

    repository.page = pageWith('Depois', version: 2);
    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.version, 1);
    // The page is re-read after the server accepts: the local draft is never
    // presented as persisted state.
    expect(repository.loaded, hasLength(2));
    expect(find.text('Sobre salvo.'), findsOneWidget);
    expect(confirmations, 1);
  });

  for (final (label, failure, stateKey) in [
    ('denied', ProfileAboutUnauthorizedException(), 'principal-profile-edit-unauthorized'),
    ('unavailable', ProfileAboutUnavailableException(), 'principal-profile-edit-error'),
  ]) {
    testWidgets('does not confirm save when its reload is $label', (tester) async {
      final repository = _StubAboutRepository(page: pageWith('Antes'));
      var confirmations = 0;
      await pump(tester, repository, onSaved: () => confirmations++);
      repository.loadError = failure;

      await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
      await tester.pumpAndSettle();

      expect(repository.saved, hasLength(1));
      expect(repository.loaded, hasLength(2));
      expect(find.byKey(Key(stateKey)), findsOneWidget);
      expect(find.text('Sobre salvo.'), findsNothing);
      expect(confirmations, 0);

      if (label == 'unavailable') {
        repository
          ..loadError = null
          ..page = pageWith('Persistido', version: 2);
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(repository.saved, hasLength(1), reason: 'read retry must not repeat the save');
        expect(repository.loaded, hasLength(3));
        expect(find.byKey(const Key('principal-profile-edit-save')), findsOneWidget);
      }
    });
  }

  testWidgets('does not confirm an old save after context changes during reload', (tester) async {
    final previous = _StubAboutRepository(page: pageWith('Contexto anterior'));
    var previousConfirmations = 0;
    var currentConfirmations = 0;
    await pump(tester, previous, onSaved: () => previousConfirmations++);
    final gate = Completer<void>();
    previous.gate = gate;

    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pump();
    expect(previous.saved, hasLength(1));
    expect(previous.loaded, hasLength(2));

    final current = _StubAboutRepository(page: pageWith('Contexto atual', version: 3));
    await pump(
      tester,
      current,
      runtimeContext: const PrincipalRuntimeContext(
        membershipId: 'membership-atual',
        personId: 'person-atual',
        institutionId: 'institution-1',
        institutionName: 'Instituição Autorizada',
        roleCode: 'staff',
        scopeKind: 'institution',
      ),
      onSaved: () => currentConfirmations++,
    );
    gate.complete();
    await tester.pumpAndSettle();

    expect(current.loaded, hasLength(1));
    expect(current.saved, isEmpty);
    expect(find.text('Sobre salvo.'), findsNothing);
    expect(previousConfirmations, 0);
    expect(currentConfirmations, 0, reason: 'the old save cannot notify the current context');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends a fresh idempotency key per save command', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pumpAndSettle();
    // Let the confirmation snack bar expire so it does not intercept the tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.requestIds, hasLength(2));
    expect(repository.requestIds.toSet(), hasLength(2));
  });

  testWidgets('does not claim success when the server reports a version conflict', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'))
      ..saveError = ProfileAboutConflictException();
    await pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-edit-conflict')), findsOneWidget);
    expect(find.text('Sobre salvo.'), findsNothing);
  });

  testWidgets('falls back to the denied state when saving is not authorized', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'))
      ..saveError = ProfileAboutUnauthorizedException();
    await pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-profile-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-edit-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-edit-save')), findsNothing);
  });

  testWidgets('fails closed when loading is denied', (tester) async {
    await pump(tester, _StubAboutRepository(loadError: ProfileAboutUnauthorizedException()));

    expect(find.byKey(const Key('principal-profile-edit-unauthorized')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('offers a retry when loading is unavailable', (tester) async {
    final repository = _StubAboutRepository(loadError: ProfileAboutUnavailableException());
    await pump(tester, repository);
    expect(find.byKey(const Key('principal-profile-edit-error')), findsOneWidget);

    repository
      ..loadError = null
      ..page = pageWith('Recuperado');
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-edit-save')), findsOneWidget);
  });

  testWidgets('drops the previous draft when the context changes', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);
    expect(repository.loaded.single.institutionId, 'institution-1');

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-2',
            personId: 'person-1',
            institutionId: 'institution-2',
            institutionName: 'Outra Instituição',
            roleCode: 'staff',
            scopeKind: 'institution',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loaded, hasLength(2));
    expect(repository.loaded.last.institutionId, 'institution-2');
  });

  testWidgets('fails closed when the context is revoked while editing', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);

    repository.loadError = ProfileAboutUnauthorizedException();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-3',
            personId: 'person-1',
            institutionId: 'institution-3',
            institutionName: 'Instituição Revogada',
            roleCode: 'staff',
            scopeKind: 'institution',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-edit-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-edit-save')), findsNothing);
  });

  testWidgets('reloads when only the membership changes inside the same scope', (tester) async {
    // Two contexts can name the same institution, unit and group and still be a
    // different actor or a different role. Authorization to manage this About
    // belongs to the membership, not to the scope, so keeping the draft alive
    // here would edit under an authorization the server never re-answered.
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);
    expect(repository.loaded, hasLength(1));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-outra',
            personId: 'person-1',
            institutionId: 'institution-1',
            institutionName: 'Instituição Autorizada',
            roleCode: 'coordinator',
            scopeKind: 'institution',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loaded, hasLength(2));
    expect(repository.loaded.last.institutionId, 'institution-1');
  });

  for (final (label, role, scope) in [
    ('roleCode', 'coordinator', 'institution'),
    ('scopeKind', 'staff', 'unit'),
  ]) {
    testWidgets('drops the draft when only $label changes', (tester) async {
      final repository = _StubAboutRepository(page: pageWith('Antes'));
      await pump(tester, repository);
      repository.loadError = ProfileAboutUnauthorizedException();

      await pump(
        tester,
        repository,
        runtimeContext: PrincipalRuntimeContext(
          membershipId: context.membershipId,
          personId: context.personId,
          institutionId: context.institutionId,
          institutionName: context.institutionName,
          roleCode: role,
          scopeKind: scope,
        ),
      );

      expect(repository.loaded, hasLength(2));
      expect(find.byKey(const Key('principal-profile-edit-unauthorized')), findsOneWidget);
      expect(find.byKey(const Key('principal-profile-edit-save')), findsNothing);
      expect(repository.saved, isEmpty);
    });
  }

  testWidgets('reloads when the person in context changes', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-1',
            personId: 'person-outra',
            institutionId: 'institution-1',
            institutionName: 'Instituição Autorizada',
            roleCode: 'staff',
            scopeKind: 'institution',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loaded, hasLength(2));
  });

  testWidgets('reload re-reads the authorized page on demand', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-profile-edit-reload')));
    await tester.pumpAndSettle();

    expect(repository.loaded, hasLength(2));
  });

  testWidgets('the reload action shows it is working and cannot be tapped twice', (tester) async {
    // While editing, the page keeps the current content on screen instead of
    // flashing a spinner. Without a busy state the action looked inert until
    // the server answered, and a second tap started another read.
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);
    expect(repository.loaded, hasLength(1));

    final gate = Completer<void>();
    repository.gate = gate;
    await tester.tap(find.byKey(const Key('principal-profile-edit-reload')));
    await tester.pump();

    final reload = find.byKey(const Key('principal-profile-edit-reload'));
    expect(find.text('Recarregando…'), findsOneWidget);
    expect(tester.widget<TextButton>(reload).onPressed, isNull);

    await tester.tap(reload, warnIfMissed: false);
    await tester.pump();
    expect(repository.loaded, hasLength(2), reason: 'the second tap must not start another read');

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Recarregar'), findsOneWidget);
    expect(tester.widget<TextButton>(reload).onPressed, isNotNull);
  });
}

final class _StubAboutRepository implements ProfileAboutRepository {
  _StubAboutRepository({this.page, this.loadError});

  ProfileAboutPage? page;
  Object? loadError;
  Object? saveError;
  Completer<void>? gate;
  final List<ProfileAboutSubjectRef> loaded = [];
  final List<ProfileAboutPage> saved = [];
  final List<String> requestIds = [];

  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    loaded.add(subject);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = loadError;
    if (failure != null) throw failure;
    return page;
  }

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) async {
    final failure = saveError;
    if (failure != null) throw failure;
    saved.add(page);
    requestIds.add(requestId);
    return ProfileAboutSaveResult(
      pageId: 'page-1',
      version: page.version + 1,
      official: const [],
    );
  }
}
