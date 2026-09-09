import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responsive and accessibility proofs for the REAL composition of
/// `principal.profile-view`.
///
/// These tests always mount [PrincipalProfileRoutePage] with an authorized
/// [PrincipalRuntimeContext] and a stubbed [ProfileAboutRepository], so what is
/// exercised is the production composition root — not the preview page with its
/// local fixtures. Sections without an authorized source must stay hidden and
/// the Acontece/Momentos tabs must show their pending state.
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

  const contextLabel = 'Instituição Autorizada · Unidade Centro';

  ProfileAboutPage aboutPageWithSection() => ProfileAboutPage(
    subject: const ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.unit,
      institutionId: 'institution-1',
      unitId: 'unit-1',
    ),
    version: 1,
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

  Future<void> pumpRoute(
    WidgetTester tester, {
    required Size surface,
    ProfileAboutRepository? repository,
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        builder: textScale == 1
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        home: PrincipalProfileRoutePage(
          runtimeContext: context,
          aboutRepository: repository ?? _StubAboutRepository(page: null),
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fails when Flutter reported any layout/paint error (RenderFlex overflow
  /// included) while laying out the real route.
  void expectNoLayoutError(WidgetTester tester) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'the real profile composition reported: $exception');
  }

  Future<void> openTab(WidgetTester tester, String tabKey) async {
    final finder = find.byKey(Key(tabKey));
    expect(finder, findsOneWidget, reason: 'tab $tabKey must exist in the real composition');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('layout without overflow', () {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('renders the real route without overflow at ${width.toInt()} px', (tester) async {
        await pumpRoute(tester, surface: Size(width, 1100));

        expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
        expectNoLayoutError(tester);
      });
    }

    for (final width in [375.0, 1440.0]) {
      testWidgets('renders the real route without overflow at ${width.toInt()} px and 200% text', (
        tester,
      ) async {
        await pumpRoute(tester, surface: Size(width, 1100), textScale: 2);

        expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
        expectNoLayoutError(tester);
      });
    }
  });

  group('authorized identity survives every breakpoint', () {
    for (final width in [375.0, 1440.0]) {
      testWidgets('keeps the authorized identity and no fixture at ${width.toInt()} px', (
        tester,
      ) async {
        await pumpRoute(tester, surface: Size(width, 1100));

        expect(find.text('Unidade Centro'), findsWidgets);
        expect(find.text(contextLabel), findsWidgets);
        expect(find.text('Colégio Horizonte'), findsNothing);
        expectNoLayoutError(tester);
      });

      testWidgets('keeps the authorized identity at ${width.toInt()} px with 200% text', (
        tester,
      ) async {
        await pumpRoute(tester, surface: Size(width, 1100), textScale: 2);

        expect(find.text('Unidade Centro'), findsWidgets);
        expect(find.text(contextLabel), findsWidgets);
        expect(find.text('Colégio Horizonte'), findsNothing);
        expectNoLayoutError(tester);
      });
    }
  });

  group('tabs stay reachable in the real composition', () {
    for (final width in [375.0, 1440.0]) {
      testWidgets('switches between the four tabs at ${width.toInt()} px', (tester) async {
        await pumpRoute(tester, surface: Size(width, 1100));

        await openTab(tester, 'principal-profile-tab-acontece');
        expect(find.byKey(const Key('principal-profile-happens-pending')), findsOneWidget);

        await openTab(tester, 'principal-profile-tab-momentos');
        expect(find.byKey(const Key('principal-profile-moments-pending')), findsOneWidget);

        // No authorized circular repository on this route instance: the tab must
        // say so instead of borrowing preview data.
        await openTab(tester, 'principal-profile-tab-circulares');
        expect(find.text('Contexto não autorizado'), findsOneWidget);

        await openTab(tester, 'principal-profile-tab-sobre');
        expect(find.text('Sobre ainda não publicado'), findsOneWidget);

        // The tabs remain alternable: going back restores the first tab.
        await openTab(tester, 'principal-profile-tab-acontece');
        expect(find.byKey(const Key('principal-profile-happens-pending')), findsOneWidget);

        expectNoLayoutError(tester);
      });

      testWidgets('shows the authorized About content at ${width.toInt()} px', (tester) async {
        await pumpRoute(
          tester,
          surface: Size(width, 1100),
          repository: _StubAboutRepository(page: aboutPageWithSection()),
        );

        await openTab(tester, 'principal-profile-tab-sobre');

        expect(find.text('Nossa proposta'), findsOneWidget);
        expect(find.text('Texto autorizado do Sobre.'), findsOneWidget);
        expect(find.text('Colégio Horizonte'), findsNothing);
        expectNoLayoutError(tester);
      });
    }
  });

  group('accessibility', () {
    testWidgets('the denied state exposes readable text at 375 px', (tester) async {
      await pumpRoute(
        tester,
        surface: const Size(375, 1100),
        repository: _StubAboutRepository(error: ProfileAboutUnauthorizedException()),
      );

      expect(find.byKey(const Key('principal-profile-unauthorized')), findsOneWidget);
      expect(find.text('Acesso não disponível'), findsOneWidget);
      expect(find.text('Seu vínculo atual não autoriza este perfil.'), findsOneWidget);
      expectNoLayoutError(tester);
    });

    testWidgets('the error state exposes readable text and an actionable retry at 375 px', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRoute(
        tester,
        surface: const Size(375, 1100),
        repository: _StubAboutRepository(error: ProfileAboutUnavailableException()),
      );

      expect(find.byKey(const Key('principal-profile-error')), findsOneWidget);
      expect(find.text('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Não conseguimos carregar este perfil agora.'), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expectNoLayoutError(tester);
      handle.dispose();
    });

    testWidgets('the denied and error states keep a usable semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRoute(
        tester,
        surface: const Size(375, 1100),
        repository: _StubAboutRepository(error: ProfileAboutUnauthorizedException()),
      );

      expect(
        find.bySemanticsLabel('Acesso não disponível'),
        findsOneWidget,
        reason: 'the denied state must be announced to assistive technology',
      );
      handle.dispose();
    });

    testWidgets('the loaded route keeps accessible tap targets at 375 px', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRoute(tester, surface: const Size(375, 1100));

      expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expectNoLayoutError(tester);
      handle.dispose();
    });

    testWidgets('the loaded route keeps accessible tap targets at 1440 px', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRoute(tester, surface: const Size(1440, 1100));

      expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expectNoLayoutError(tester);
      handle.dispose();
    });

    testWidgets('the loaded route keeps readable text contrast at 375 px', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRoute(tester, surface: const Size(375, 1100));

      expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expectNoLayoutError(tester);
      handle.dispose();
    });
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
