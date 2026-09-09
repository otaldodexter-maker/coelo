import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_happens_tab.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responsive and accessibility proofs for the Acontece tab of the Perfil.
///
/// The tab is embedded inside a scrolling profile, so it must lay out under the
/// canonical widths and at 200% text without overflowing, and its states must
/// stay readable and announced.
void main() {
  const scope = PrincipalHappensFeedScope(
    institutionId: 'institution-1',
    unitId: 'unit-1',
    groupId: 'group-1',
  );

  PrincipalPostPreviewItem post({String author = 'Coordenação Pedagógica'}) =>
      PrincipalPostPreviewItem(
        author: author,
        context: 'Unidade Centro · Turma 3A',
        time: '2 h',
        initials: 'CP',
        body:
            'Um texto autorizado longo o bastante para exercitar o refluxo do '
            'card em telas estreitas e com a escala de texto ampliada, porque é '
            'assim que uma publicação real costuma chegar.',
        likes: 12,
        comments: 3,
        shares: 1,
        likedBy: 'Curtido por Ana e mais 11 pessoas',
      );

  Future<void> pumpTab(
    WidgetTester tester, {
    required Size surface,
    double textScale = 1,
    _StubHappensRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrincipalProfileHappensTab(
              repository: repository ?? _StubHappensRepository(posts: [post()]),
              scope: scope,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoLayoutError(WidgetTester tester) => expect(tester.takeException(), isNull);

  group('layout', () {
    for (final width in <double>[375, 768, 1024, 1440]) {
      testWidgets('renders the authorized feed without overflow at ${width.toInt()} px', (
        tester,
      ) async {
        await pumpTab(tester, surface: Size(width, 1200));

        expect(find.byKey(const Key('principal-profile-happens-list')), findsOneWidget);
        expect(find.text('Coordenação Pedagógica'), findsOneWidget);
        expectNoLayoutError(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final width in <double>[375, 1440]) {
      testWidgets('renders without overflow at ${width.toInt()} px and 200% text', (tester) async {
        await pumpTab(tester, surface: Size(width, 2400), textScale: 2);

        expect(find.byKey(const Key('principal-profile-happens-list')), findsOneWidget);
        expectNoLayoutError(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('lays out several posts without overflow at 375 px', (tester) async {
      await pumpTab(
        tester,
        surface: const Size(375, 2000),
        repository: _StubHappensRepository(
          posts: [post(), post(author: 'Secretaria'), post(author: 'Direção')],
        ),
      );

      expect(find.byKey(const Key('principal-profile-happens-post-2')), findsOneWidget);
      expectNoLayoutError(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('accessibility', () {
    testWidgets('announces each post as a container with its author', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTab(tester, surface: const Size(1440, 1200));

      expect(find.bySemanticsLabel('Publicação de Coordenação Pedagógica'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the loaded feed keeps readable text', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTab(tester, surface: const Size(375, 1200));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the denied state is readable and offers no retry', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTab(
        tester,
        surface: const Size(375, 900),
        repository: _StubHappensRepository(posts: const [], failure: PrincipalHappensFeedUnauthorized()),
      );

      expect(find.byKey(const Key('principal-profile-happens-unauthorized')), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the error state keeps its retry reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTab(
        tester,
        surface: const Size(375, 900),
        repository: _StubHappensRepository(posts: const [], failure: StateError('offline')),
      );

      expect(find.byKey(const Key('principal-profile-happens-error')), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

final class _StubHappensRepository implements PrincipalHappensFeedRepository {
  _StubHappensRepository({required this.posts, this.failure});

  final List<PrincipalPostPreviewItem> posts;
  final Object? failure;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    final error = failure;
    if (error != null) throw error;
    return posts;
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      Future.error(StateError('these posts carry no media'));
}
