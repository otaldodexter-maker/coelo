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

  Future<void> pump(WidgetTester tester, ProfileAboutRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(runtimeContext: context, repository: repository),
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
    await pump(tester, repository);
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

  testWidgets('reload re-reads the authorized page on demand', (tester) async {
    final repository = _StubAboutRepository(page: pageWith('Antes'));
    await pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-profile-edit-reload')));
    await tester.pumpAndSettle();

    expect(repository.loaded, hasLength(2));
  });
}

final class _StubAboutRepository implements ProfileAboutRepository {
  _StubAboutRepository({this.page, this.loadError});

  ProfileAboutPage? page;
  Object? loadError;
  Object? saveError;
  final List<ProfileAboutSubjectRef> loaded = [];
  final List<ProfileAboutPage> saved = [];
  final List<String> requestIds = [];

  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    loaded.add(subject);
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
