import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Composition root proofs for `principal.profile-view`.
///
/// The real route must render the server-authorized context, never the local
/// preview fixtures, and must fail closed when the About projection is denied.
void main() {
  const context = PrincipalRuntimeContext(
    membershipId: 'membership-1',
    personId: 'person-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Autorizada',
    roleCode: 'staff',
    scopeKind: 'unit',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
  );

  ProfileAboutSubjectRef subjectOf(PrincipalRuntimeContext value) => ProfileAboutSubjectRef(
    type: ProfileAboutSubjectType.unit,
    institutionId: value.institutionId,
    unitId: value.unitId,
  );

  Future<void> pump(
    WidgetTester tester, {
    required ProfileAboutRepository? repository,
    PrincipalRuntimeContext runtimeContext = context,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: runtimeContext,
          aboutRepository: repository,
          onOpenAgenda: () {},
        ),
      ),
    );
  }

  testWidgets('shows the authorized context identity and never the preview fixture', (
    tester,
  ) async {
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
    expect(find.text('Unidade Centro'), findsWidgets);
    expect(find.text('Instituição Autorizada · Unidade Centro'), findsWidgets);
    expect(find.text('Colégio Horizonte'), findsNothing);
    expect(find.text('128'), findsNothing);
  });

  testWidgets('does not render the Acontece preview feed on the real route', (tester) async {
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-happens-pending')), findsOneWidget);
  });

  testWidgets('projects the authorized About content into the Sobre tab', (tester) async {
    final page = ProfileAboutPage(
      subject: subjectOf(context),
      version: 3,
      fields: const [],
      sections: [
        ProfileAboutSection(
          id: 'section-1',
          type: ProfileAboutSectionType.text,
          title: 'Nossa proposta',
          body: 'Texto autorizado do Sobre.',
          position: 0,
          state: ProfileAboutSectionState.published,
        ),
      ],
    );
    await pump(tester, repository: _StubAboutRepository(page: page));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();

    expect(find.text('Nossa proposta'), findsOneWidget);
    expect(find.text('Texto autorizado do Sobre.'), findsOneWidget);
  });

  testWidgets('fails closed without retry when the About projection is denied', (tester) async {
    await pump(tester, repository: _StubAboutRepository(error: ProfileAboutUnauthorizedException()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-content')), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('offers a retry when the About projection is unavailable', (tester) async {
    final repository = _StubAboutRepository(error: ProfileAboutUnavailableException());
    await pump(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-error')), findsOneWidget);

    repository
      ..error = null
      ..page = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
  });

  testWidgets('reloads and discards the previous context when the context is revoked', (
    tester,
  ) async {
    final repository = _StubAboutRepository(page: null);
    await pump(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(find.text('Unidade Centro'), findsWidgets);

    repository.error = ProfileAboutUnauthorizedException();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-2',
            personId: 'person-1',
            institutionId: 'institution-2',
            institutionName: 'Outra Instituição',
            roleCode: 'staff',
            scopeKind: 'institution',
          ),
          aboutRepository: repository,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-unauthorized')), findsOneWidget);
    expect(find.text('Unidade Centro'), findsNothing);
  });

  testWidgets('never tells a real user the Perfil is a prototype', (tester) async {
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mensagem'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem ainda não está disponível.'), findsOneWidget);
    expect(find.textContaining('experiência completa'), findsNothing);
  });

  testWidgets('requests the About page for the authorized subject only', (tester) async {
    final repository = _StubAboutRepository(page: null);
    await pump(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(repository.requested, hasLength(1));
    expect(repository.requested.single.type, ProfileAboutSubjectType.unit);
    expect(repository.requested.single.institutionId, 'institution-1');
    expect(repository.requested.single.unitId, 'unit-1');
  });
}

final class _StubAboutRepository implements ProfileAboutRepository {
  _StubAboutRepository({this.page, this.error});

  ProfileAboutPage? page;
  Object? error;
  final List<ProfileAboutSubjectRef> requested = [];

  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    requested.add(subject);
    final failure = error;
    if (failure != null) throw failure;
    return page;
  }

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) => Future.error(UnimplementedError());
}
