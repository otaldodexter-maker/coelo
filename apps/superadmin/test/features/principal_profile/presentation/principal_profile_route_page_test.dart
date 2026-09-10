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

  testWidgets('re-reads the About when only the membership changes inside the same scope', (
    tester,
  ) async {
    // The server answers the About by the actor, not by the scope name. Two
    // contexts can carry the same institution, unit and group and still be a
    // different membership or role, so the page must ask again instead of
    // keeping content authorized for the previous one.
    final repository = _StubAboutRepository(page: null);
    await pump(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(repository.requested, hasLength(1));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: const PrincipalRuntimeContext(
            membershipId: 'membership-outra',
            personId: 'person-1',
            institutionId: 'institution-1',
            institutionName: 'Instituição Autorizada',
            roleCode: 'coordinator',
            scopeKind: 'unit',
            unitId: 'unit-1',
            unitName: 'Unidade Centro',
          ),
          aboutRepository: repository,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requested, hasLength(2));
  });

  testWidgets('never tells a real user the Perfil is a prototype', (tester) async {
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mensagem'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem ainda não está disponível.'), findsOneWidget);
    expect(find.textContaining('experiência completa'), findsNothing);
  });

  testWidgets('an About without content is distinguishable from a failure', (tester) async {
    // No published Sobre is not the same as a broken Sobre: the profile renders
    // with its authorized identity and the tab says the content is pending.
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-error')), findsNothing);
    expect(find.byKey(const Key('principal-profile-unauthorized')), findsNothing);

    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre ainda não publicado'), findsOneWidget);
  });

  testWidgets('a failure never renders as a profile without content', (tester) async {
    await pump(tester, repository: _StubAboutRepository(error: ProfileAboutUnavailableException()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-error')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-content')), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
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

  testWidgets('names every About field to assistive technology', (tester) async {
    // The Sobre tab renders each field as its bare value beside a generic icon,
    // which is the approved composition. A screen reader therefore announced
    // two contact numbers as two numbers, with nothing saying which is which:
    // for assistive technology the information was not ambiguous, it was
    // absent. The semantic label names the field without changing a pixel.
    final handle = tester.ensureSemantics();

    final page = ProfileAboutPage(
      subject: subjectOf(context),
      version: 1,
      fields: const [
        ProfileAboutField(key: ProfileAboutFieldKey.phone, value: '11 3000-0000'),
        ProfileAboutField(key: ProfileAboutFieldKey.mobile, value: '11 99999-0000'),
      ],
      sections: const [],
    );
    await pump(tester, repository: _StubAboutRepository(page: page));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sobre').last);
    await tester.tap(find.text('Sobre').last);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Telefone: 11 3000-0000'), findsOneWidget);
    expect(find.bySemanticsLabel('Celular: 11 99999-0000'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('does not offer "Ver mais" when there is no bio to expand', (tester) async {
    // The bio is the authorized `description` field and can legitimately be
    // absent. An empty paragraph followed by "Ver mais" offers to expand
    // nothing, and on the real route that reads as content that failed to
    // arrive rather than as content that does not exist.
    await pump(tester, repository: _StubAboutRepository(page: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
    expect(find.text('Ver mais'), findsNothing);
  });

  testWidgets('offers "Ver mais" once the authorized About carries a bio', (tester) async {
    final page = ProfileAboutPage(
      subject: subjectOf(context),
      version: 1,
      fields: const [
        ProfileAboutField(
          key: ProfileAboutFieldKey.description,
          value: 'Somos uma unidade de educação infantil no centro.',
        ),
      ],
      sections: const [],
    );
    await pump(tester, repository: _StubAboutRepository(page: page));
    await tester.pumpAndSettle();

    expect(find.text('Somos uma unidade de educação infantil no centro.'), findsWidgets);
    expect(find.text('Ver mais'), findsOneWidget);
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
