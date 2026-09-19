import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/official_profiles_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// spec 068 §4 (lote 107): publicar como perfil oficial no Acontece e retirar.
void main() {
  Widget app(_Fake fake) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: OfficialProfilesPage(profiles: fake, posts: fake, onReturn: () {}),
    ),
  );

  testWidgets('publishes a post as the chosen profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _Fake();
    await tester.pumpWidget(app(fake));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('official-posts-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('official-post-publish')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('official-post-confirm'))).onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('official-post-caption')), 'Sono tranquilo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('official-post-confirm')));
    await tester.pumpAndSettle();

    expect(fake.published, [('p-coelo', 'Sono tranquilo')]);
    expect(find.text('Publicado no Acontece como Coelo.'), findsOneWidget);
    expect(find.text('Sono tranquilo'), findsOneWidget);
  });

  testWidgets('withdraws a post with a reason and filters by profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _Fake()
      ..posts.add(
        OfficialPost(
          id: 'post-1',
          profileId: 'p-educa',
          handle: 'coelo.educa',
          profileName: 'Coelo Educa',
          caption: 'Telas à noite atrapalham o sono.',
          status: 'published',
          publishedAt: DateTime.utc(2026, 9, 20),
          managementVersion: 1,
        ),
      );
    await tester.pumpWidget(app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('official-profile-chip-coelo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('official-posts-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('official-profile-chip-coelo.educa')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('official-post-post-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('official-post-withdraw-post-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('official-post-withdraw-reason')), 'Engano');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('official-post-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(fake.withdrawn, [('post-1', 1, 'Engano')]);
    expect(find.text('Retirado'), findsOneWidget);
  });
}

final class _Fake implements NoticeCtaTargetOptionsReader, OfficialPostsCommands {
  final posts = <OfficialPost>[];
  final published = <(String, String)>[];
  final withdrawn = <(String, int, String)>[];

  @override
  Future<List<NoticeCtaTargetOption>> fetchCtaTargetOptions({
    required NoticeCtaTargetKind kind,
    String? search,
    int pageSize = 30,
  }) async => const [];

  @override
  Future<List<NoticeOfficialProfile>> fetchOfficialProfiles() async => const [
    NoticeOfficialProfile(id: 'p-coelo', handle: 'coelo', displayName: 'Coelo', mandatory: true),
    NoticeOfficialProfile(id: 'p-educa', handle: 'coelo.educa', displayName: 'Coelo Educa'),
  ];

  @override
  Future<List<OfficialPost>> fetchOfficialPosts({String? profileId}) async => List.of(posts);

  @override
  Future<OfficialPost> publishOfficialPost({
    required String requestId,
    required String profileId,
    required String caption,
  }) async {
    published.add((profileId, caption));
    final post = OfficialPost(
      id: 'post-${posts.length + 1}',
      profileId: profileId,
      handle: profileId == 'p-coelo' ? 'coelo' : 'coelo.educa',
      profileName: profileId == 'p-coelo' ? 'Coelo' : 'Coelo Educa',
      caption: caption,
      status: 'published',
      publishedAt: DateTime.utc(2026, 9, 20),
      managementVersion: 1,
    );
    posts.insert(0, post);
    return post;
  }

  @override
  Future<OfficialPost> withdrawOfficialPost({
    required String requestId,
    required String postId,
    required int expectedVersion,
    required String reason,
  }) async {
    withdrawn.add((postId, expectedVersion, reason));
    final index = posts.indexWhere((p) => p.id == postId);
    final old = posts[index];
    final post = OfficialPost(
      id: old.id,
      profileId: old.profileId,
      handle: old.handle,
      profileName: old.profileName,
      caption: old.caption,
      status: 'withdrawn',
      publishedAt: old.publishedAt,
      managementVersion: old.managementVersion + 1,
      withdrawnAt: DateTime.utc(2026, 9, 20, 1),
      withdrawReason: reason,
    );
    posts[index] = post;
    return post;
  }
}
