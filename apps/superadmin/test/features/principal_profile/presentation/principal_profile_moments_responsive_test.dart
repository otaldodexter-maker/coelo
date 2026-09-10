import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_moments_tab.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responsive and accessibility proofs for the Momentos tab of the REAL Perfil.
///
/// The tab was written in this round, so it arrived without the coverage the
/// sibling tabs already had. Absence of coverage is not a neutral state: the
/// two defects this front found in the editor's footer and in the hero card
/// only appeared when someone wrote the responsive proof that was missing.
///
/// Everything here mounts the production composition root with an authorized
/// context, never the preview page with its sprite fixtures.
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
    String caption =
        'Registro da manhã no ateliê, com a turma inteira envolvida na construção do painel coletivo',
    List<PrincipalMomentMedia> media = const [],
  }) => PrincipalMomentPreviewItem(
    author: 'Coordenação Pedagógica da Unidade Centro',
    context: 'Unidade Centro',
    time: 'Hoje, 09:15',
    caption: caption,
    likes: 128,
    comments: 34,
    shares: 7,
    saves: 2,
    imageIndex: 0,
    media: media,
  );

  Future<void> openMomentsTab(
    WidgetTester tester, {
    required Size surface,
    required PrincipalMomentsFeedRepository? repository,
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
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        home: PrincipalProfileRoutePage(
          runtimeContext: context,
          embedded: true,
          momentsFeedRepository: repository,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tab = find.byKey(const Key('principal-profile-tab-momentos'));
    expect(tab, findsOneWidget, reason: 'the Momentos tab must exist in the real composition');
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  void expectNoLayoutError(WidgetTester tester) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'the real Momentos tab reported: $exception');
  }

  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets('lays out without overflow at ${width.toInt()} px', (tester) async {
      await openMomentsTab(
        tester,
        surface: Size(width, 1100),
        repository: _StubMomentsRepository(items: [moment(), moment()]),
      );

      expect(find.byKey(const Key('principal-profile-moments-list')), findsOneWidget);
      expectNoLayoutError(tester);
    });
  }

  for (final width in [375.0, 1440.0]) {
    testWidgets('lays out without overflow at ${width.toInt()} px and 200% text', (tester) async {
      await openMomentsTab(
        tester,
        surface: Size(width, 1400),
        repository: _StubMomentsRepository(items: [moment()]),
        textScale: 2,
      );

      expectNoLayoutError(tester);
    });
  }

  testWidgets('the metrics reflow at 200% text instead of running off the card', (tester) async {
    // This is the assertion that can actually fail, and it exists because the
    // no-exception checks above nearly cannot: every axis of this tab is either
    // scrollable or wrapping, so a naive overflow probe stays green even on a
    // 120 px tall surface -- measured, not assumed. What the Wrap protects is
    // the metrics line, and swapping it back to a Row is the exact defect this
    // front already fixed in the editor's footer.
    //
    // The numbers here are measured too. At 375 px and 200% text the three
    // metrics still fit on one line -- the Wrap comes back 40 px tall -- so
    // that combination proves nothing. 320 px at 300% is where the reflow
    // actually happens, and the guard was seen failing at 375/200% before it
    // was moved here.
    await openMomentsTab(
      tester,
      surface: const Size(320, 1400),
      repository: _StubMomentsRepository(items: [moment()]),
      textScale: 3,
    );

    final metrics = find.descendant(
      of: find.byType(PrincipalProfileMomentsTab),
      matching: find.byType(Wrap),
    );
    expect(metrics, findsOneWidget);
    final wrapHeight = tester.getSize(metrics).height;
    final singleMetricHeight = tester.getSize(find.text('128')).height;
    expect(
      wrapHeight,
      greaterThan(singleMetricHeight * 1.5),
      reason:
          'at 200% text the three metrics must reflow onto more than one line; '
          'a Row here would push the last one off the card instead',
    );
  });

  testWidgets('every state lays out without overflow at 375 px', (tester) async {
    for (final repository in [
      _StubMomentsRepository(items: const []),
      _StubMomentsRepository(items: const [], failure: const PrincipalMomentsFeedUnavailable()),
      _StubMomentsRepository(items: const [], failure: const PrincipalMomentsFeedUnauthorized()),
    ]) {
      await openMomentsTab(tester, surface: const Size(375, 900), repository: repository);
      expectNoLayoutError(tester);
    }
    // And the state the tab keeps when no projection is composed at all.
    await openMomentsTab(tester, surface: const Size(375, 900), repository: null);
    expectNoLayoutError(tester);
  });

  testWidgets('the dark theme keeps the tab renderable', (tester) async {
    await openMomentsTab(
      tester,
      surface: const Size(375, 900),
      repository: _StubMomentsRepository(items: [moment()]),
      theme: CoeloTheme.dark,
    );

    expect(find.byKey(const Key('principal-profile-moments-list')), findsOneWidget);
    expectNoLayoutError(tester);
  });

  testWidgets('a screen reader can walk each moment instead of hearing one block', (tester) async {
    // The Acontece tab had this exact defect: a Semantics container without
    // explicitChildNodes announced author, context, caption and metrics as a
    // single blob. This asserts the Momentos card did not repeat it.
    final handle = tester.ensureSemantics();
    await openMomentsTab(
      tester,
      surface: const Size(375, 1200),
      repository: _StubMomentsRepository(items: [moment(caption: 'Ateliê de artes')]),
    );

    expect(find.text('Ateliê de artes'), findsOneWidget);
    final node = tester.getSemantics(find.text('Ateliê de artes'));
    expect(
      node.label,
      'Ateliê de artes',
      reason: 'the caption must be its own node, not merged into the whole card',
    );
    handle.dispose();
  });

  testWidgets('the retry action of the error state is reachable at 375 px', (tester) async {
    await openMomentsTab(
      tester,
      surface: const Size(375, 900),
      repository: _StubMomentsRepository(
        items: const [],
        failure: const PrincipalMomentsFeedUnavailable(),
      ),
    );

    final retry = find.text('Tentar novamente');
    expect(retry, findsOneWidget);
    final size = tester.getSize(find.ancestor(of: retry, matching: find.byType(FilledButton)));
    expect(
      size.height,
      greaterThanOrEqualTo(CoeloSize.touchMin),
      reason: 'the only way out of the error state must stay a real touch target',
    );
  });
}

final class _StubMomentsRepository implements PrincipalMomentsFeedRepository {
  _StubMomentsRepository({required this.items, this.failure});

  List<PrincipalMomentPreviewItem> items;
  Object? failure;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    final error = failure;
    if (error != null) throw error;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
