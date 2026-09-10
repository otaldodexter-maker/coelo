import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_moments_tab.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proofs for the Momentos tab of `principal.profile-view`.
///
/// The tab was a declared pendency: the authorized projection lived on another
/// front's branch, so the Perfil showed an honest "not connected yet" panel.
/// With `SupabasePrincipalMomentsFeedRepository` composed in the integrated
/// base, the tab consumes that projection with the scope the server resolved.
/// Nothing here creates a parallel repository and nothing renders the preview
/// sprite the `/dev` Perfil uses.
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

  PrincipalMomentPreviewItem moment({
    String caption = 'Ateliê de artes',
    List<PrincipalMomentMedia> media = const [],
  }) => PrincipalMomentPreviewItem(
    author: 'Coordenação',
    context: 'Unidade Centro',
    time: 'Hoje',
    caption: caption,
    likes: 3,
    comments: 1,
    shares: 0,
    saves: 0,
    imageIndex: 0,
    media: media,
  );

  Future<void> pumpTab(WidgetTester tester, _StubMomentsRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: PrincipalProfileMomentsTab(
            repository: repository,
            scope: const PrincipalMomentsFeedScope(
              institutionId: 'institution-1',
              unitId: 'unit-1',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('projects the authorized moments of the resolved context', (tester) async {
    final repository = _StubMomentsRepository(items: [moment(), moment(caption: 'Horta')]);
    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moments-list')), findsOneWidget);
    expect(find.text('Ateliê de artes'), findsOneWidget);
    expect(find.text('Horta'), findsOneWidget);
    expect(repository.scopes.single.institutionId, 'institution-1');
    expect(repository.scopes.single.unitId, 'unit-1');
    expect(repository.scopes.single.groupId, isNull);
  });

  testWidgets('an empty feed is distinguishable from a failure', (tester) async {
    await pumpTab(tester, _StubMomentsRepository(items: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moments-empty')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-moments-error')), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('a failure offers a retry and never renders as an empty feed', (tester) async {
    final repository = _StubMomentsRepository(
      items: const [],
      failure: const PrincipalMomentsFeedUnavailable(),
    );
    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moments-error')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-moments-empty')), findsNothing);

    repository
      ..failure = null
      ..items = [moment()];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Ateliê de artes'), findsOneWidget);
  });

  testWidgets('a denial fails closed, with no content and no retry', (tester) async {
    await pumpTab(
      tester,
      _StubMomentsRepository(
        items: [moment()],
        failure: const PrincipalMomentsFeedUnauthorized(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moments-unauthorized')), findsOneWidget);
    expect(find.text('Ateliê de artes'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('media without a signed URL degrades to a neutral slot', (tester) async {
    await pumpTab(
      tester,
      _StubMomentsRepository(
        items: [
          moment(
            media: const [PrincipalMomentMedia(signedUrl: '', mimeType: 'image/jpeg', displayOrder: 0)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moment-media-placeholder')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-moment-media-image')), findsNothing);
  });

  testWidgets('a video is announced as a video instead of a broken image', (tester) async {
    await pumpTab(
      tester,
      _StubMomentsRepository(
        items: [
          moment(
            media: const [
              PrincipalMomentMedia(
                signedUrl: 'https://example.invalid/signed.mp4',
                mimeType: 'video/mp4',
                displayOrder: 0,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moment-media-video')), findsOneWidget);
  });

  testWidgets('re-reads when the resolved scope changes, not on every rebuild', (tester) async {
    final repository = _StubMomentsRepository(items: [moment()]);
    Widget tabWith(String? groupId) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: PrincipalProfileMomentsTab(
          repository: repository,
          // A fresh instance every build, as the route builds it.
          scope: PrincipalMomentsFeedScope(
            institutionId: 'institution-1',
            unitId: 'unit-1',
            groupId: groupId,
          ),
        ),
      ),
    );

    await tester.pumpWidget(tabWith(null));
    await tester.pumpAndSettle();
    expect(repository.scopes, hasLength(1));

    await tester.pumpWidget(tabWith(null));
    await tester.pumpAndSettle();
    expect(repository.scopes, hasLength(1), reason: 'the actor scope did not change');

    await tester.pumpWidget(tabWith('group-1'));
    await tester.pumpAndSettle();
    expect(repository.scopes, hasLength(2));
    expect(repository.scopes.last.groupId, 'group-1');
  });

  testWidgets('the real route mounts the tab and never the preview sprite', (tester) async {
    final repository = _StubMomentsRepository(items: [moment()]);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: context,
          embedded: true,
          momentsFeedRepository: repository,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Momentos').last);
    await tester.tap(find.text('Momentos').last);
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalProfileMomentsTab), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-moments-pending')), findsNothing);
    expect(find.text('Ateliê de artes'), findsOneWidget);
    expect(repository.scopes.single.institutionId, 'institution-1');
    expect(repository.scopes.single.unitId, 'unit-1');
  });

  testWidgets('without an authorized projection the tab keeps its honest pending state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: context,
          embedded: true,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Momentos').last);
    await tester.tap(find.text('Momentos').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-moments-pending')), findsOneWidget);
    expect(find.byType(PrincipalProfileMomentsTab), findsNothing);
  });
}

final class _StubMomentsRepository implements PrincipalMomentsFeedRepository {
  _StubMomentsRepository({required this.items, this.failure});

  List<PrincipalMomentPreviewItem> items;
  Object? failure;
  final List<PrincipalMomentsFeedScope> scopes = [];

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    scopes.add(scope);
    final error = failure;
    if (error != null) throw error;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
