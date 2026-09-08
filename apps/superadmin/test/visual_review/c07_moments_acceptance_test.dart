import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aceitacao comportamental (sem golden) do viewer de Momentos.
///
/// Contrato: spec 050, secao "Agora e Momentos": ao abrir Momentos a midia
/// ocupa a tela inteira em mobile, tablet e desktop, todo chrome externo e
/// suspenso, o retorno contextual restaura foco e posicao, e os controles
/// preservam legibilidade e alvos de toque.
///
/// O que ja esta coberto em `test/features/principal_moments/presentation/`
/// nao se repete aqui: rect do `page-view`, `BoxFit.cover`, ausencia de
/// dock/nav/aside em tema claro, callback do retorno por toque e Escape,
/// 200 % sem overflow em tema claro e os estados de feed. Este arquivo cobre
/// as lacunas: quadro de midia sem letterbox em claro e escuro, ausencia do
/// chrome administrativo do Superadmin, alvos dos controles, legenda e rail
/// disjuntos, 200 % em tema escuro e a restauracao de foco/posicao na origem
/// quando o viewer e uma rota empilhada.
void main() {
  const viewports = [Size(375, 900), Size(768, 1024), Size(1440, 1000)];
  final themes = [(name: 'light', data: CoeloTheme.light), (name: 'dark', data: CoeloTheme.dark)];
  const scope = PrincipalMomentsFeedScope(institutionId: 'institution-coelo');

  final pageView = find.byKey(const Key('principal-moments-page-view'));
  final back = find.byKey(const Key('principal-moments-back'));

  Future<void> pumpViewer(
    WidgetTester tester, {
    required Size size,
    ThemeData? theme,
    double textScale = 1,
    PrincipalMomentsFeedRepository? feedRepository,
    PrincipalMomentsFeedScope? feedScope,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: child!,
        ),
        home: PrincipalMomentsPreviewPage(feedRepository: feedRepository, feedScope: feedScope),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Os sete controles do contrato: retorno, mudo, curtir, comentar,
  /// compartilhar, salvar e menu. Com remocao autorizada, o menu da lugar ao
  /// controle de remover.
  Map<String, Finder> viewerControls({bool removeGranted = false}) => {
    'retorno': back,
    'mudo': find.byKey(const Key('principal-moments-mute')),
    'curtir': find.byKey(const Key('principal-moments-like')),
    'comentar': find.byTooltip('Comentar'),
    'compartilhar': find.byTooltip('Compartilhar'),
    'salvar': find.byKey(const Key('principal-moments-save')),
    if (removeGranted)
      'remover': find.byKey(const Key('principal-moments-remove'))
    else
      'menu': find.byTooltip('Mais opções'),
  };

  /// Rail de acoes = uniao dos rects dos controles verticais a direita.
  Rect actionRailRect(WidgetTester tester, Map<String, Finder> controls) => controls.entries
      .where((entry) => entry.key != 'retorno' && entry.key != 'mudo')
      .map((entry) => tester.getRect(entry.value))
      .reduce((union, rect) => union.expandToInclude(rect));

  /// Bloco de legenda = a Column do contexto do momento (autor, tempo,
  /// legenda e curtidas), ancestral direto do texto da legenda.
  Rect captionBlockRect(WidgetTester tester, String caption) =>
      tester.getRect(find.ancestor(of: find.text(caption), matching: find.byType(Column)).first);

  void expectMediaFillsViewport(WidgetTester tester, Size size, String label) {
    final viewport = Offset.zero & size;
    final image = find.descendant(of: pageView, matching: find.byType(Image)).first;
    final mediaFrame = find.ancestor(of: image, matching: find.byType(ClipRect)).first;
    final momentFrame = find.ancestor(of: image, matching: find.byType(Stack)).first;

    expect(
      tester.getRect(momentFrame),
      viewport,
      reason: '[$label] quadro do momento mede ${tester.getRect(momentFrame)}',
    );
    expect(
      tester.getRect(mediaFrame),
      viewport,
      reason: '[$label] quadro da midia mede ${tester.getRect(mediaFrame)}',
    );
    final imageRect = tester.getRect(image);
    expect(
      imageRect.left <= 0 &&
          imageRect.top <= 0 &&
          imageRect.right >= size.width &&
          imageRect.bottom >= size.height,
      isTrue,
      reason: '[$label] imagem $imageRect nao cobre o viewport $viewport (letterbox)',
    );
  }

  void expectNoExternalChrome(String label) {
    for (final chrome in <String, Finder>{
      'SuperadminShell': find.byType(SuperadminShell),
      'superadmin-persistent-shell': find.byKey(const Key('superadmin-persistent-shell')),
      'superadmin-sidebar': find.byKey(const Key('superadmin-sidebar')),
      'superadmin-floating-sidebar': find.byKey(const Key('superadmin-floating-sidebar')),
      'AppBar': find.byType(AppBar),
      'NavigationRail': find.byType(NavigationRail),
      'NavigationBar': find.byType(NavigationBar),
      'BottomNavigationBar': find.byType(BottomNavigationBar),
      'Drawer': find.byType(Drawer),
      'principal-global-dock': find.byKey(const Key('principal-global-dock')),
      'principal-moments-desktop-aside': find.byKey(const Key('principal-moments-desktop-aside')),
    }.entries) {
      expect(chrome.value, findsNothing, reason: '[$label] ${chrome.key} presente na arvore');
    }
  }

  void expectControlsMeetTargets(WidgetTester tester, Size size, Map<String, Finder> controls) {
    final viewport = Offset.zero & size;
    for (final control in controls.entries) {
      expect(control.value, findsOneWidget, reason: '${control.key} em ${size.width.toInt()}');
      final rect = tester.getRect(control.value);
      expect(
        rect.width >= CoeloSize.touchMin && rect.height >= CoeloSize.touchMin,
        isTrue,
        reason:
            '${control.key} em ${size.width.toInt()} mede '
            '${rect.width}x${rect.height}; minimo ${CoeloSize.touchMin}',
      );
      expect(
        rect.left >= 0 && rect.top >= 0 && rect.right <= size.width && rect.bottom <= size.height,
        isTrue,
        reason: '${control.key} em ${size.width.toInt()} fica em $rect, fora de $viewport',
      );
    }
  }

  for (final size in viewports) {
    for (final theme in themes) {
      testWidgets(
        'media fills the viewport at ${size.width.toInt()} in ${theme.name} without external chrome',
        (tester) async {
          await pumpViewer(tester, size: size, theme: theme.data);
          final label = '${size.width.toInt()} ${theme.name}';

          expect(pageView, findsOneWidget);
          expectMediaFillsViewport(tester, size, label);
          expectNoExternalChrome(label);
          expect(tester.takeException(), isNull, reason: label);
        },
      );
    }
  }

  for (final size in viewports) {
    testWidgets(
      'dark theme at 200% text keeps the media full-screen at ${size.width.toInt()} without overflow',
      (tester) async {
        await pumpViewer(tester, size: size, theme: CoeloTheme.dark, textScale: 2);
        final label = '${size.width.toInt()} dark 200%';

        expectMediaFillsViewport(tester, size, label);
        expectNoExternalChrome(label);
        expect(tester.takeException(), isNull, reason: label);
      },
    );
  }

  for (final size in viewports) {
    testWidgets(
      'every viewer control meets the 48px target inside the viewport at ${size.width.toInt()}',
      (tester) async {
        await pumpViewer(tester, size: size);

        expectControlsMeetTargets(tester, size, viewerControls());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('every viewer control meets the 48px target at 375 with text at 200%', (
    tester,
  ) async {
    const size = Size(375, 900);
    await pumpViewer(tester, size: size, textScale: 2);

    expectControlsMeetTargets(tester, size, viewerControls());
    expect(tester.takeException(), isNull);
  });

  testWidgets('an authorised feed keeps the remove control within the 48px target at 375', (
    tester,
  ) async {
    const size = Size(375, 900);
    await pumpViewer(
      tester,
      size: size,
      feedRepository: _FakeMomentsFeedRepository([_grantedMoment]),
      feedScope: scope,
    );

    expect(find.text(_grantedMoment.caption), findsOneWidget);
    expectMediaFillsViewport(tester, size, '375 feed autorizado');
    expectControlsMeetTargets(tester, size, viewerControls(removeGranted: true));
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'caption and action rail stay disjoint at 375 with text at ${(textScale * 100).toInt()}%',
      (tester) async {
        const size = Size(375, 900);
        await pumpViewer(tester, size: size, textScale: textScale);
        final caption = PrincipalMomentsPreviewData.demo.moments.first.caption;
        final controls = viewerControls();

        final captionRect = captionBlockRect(tester, caption);
        final railRect = actionRailRect(tester, controls);
        final viewport = Offset.zero & size;

        expect(
          captionRect.overlaps(railRect),
          isFalse,
          reason: 'legenda $captionRect sobrepoe o rail $railRect a ${textScale * 100}%',
        );
        expect(
          captionRect.left >= 0 &&
              captionRect.top >= 0 &&
              captionRect.right <= size.width &&
              captionRect.bottom <= size.height,
          isTrue,
          reason: 'legenda $captionRect fora do viewport $viewport a ${textScale * 100}%',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final closeWithEscape in [false, true]) {
    testWidgets(
      '${closeWithEscape ? 'Escape' : 'the back action'} pops the pushed viewer and restores '
      'focus and position at the origin',
      (tester) async {
        // Mecanismo real: o router abre Momentos com `pushNamed` e
        // `onOpenHappens` chama `_closePrincipalViewer`, que faz `context.pop()`
        // quando ha rota para desempilhar. A restauracao de foco e posicao vem
        // do FocusScope por rota do Navigator (`ModalRoute.didPopNext`) e da
        // rota de origem mantida em memoria. Aqui o mesmo par push/pop e
        // reproduzido com Navigator e MaterialPageRoute.
        const size = Size(375, 900);
        const originOffset = 320.0;
        final navigatorKey = GlobalKey<NavigatorState>();
        final originFocus = FocusNode(debugLabel: 'origem-momentos');
        addTearDown(originFocus.dispose);
        final originScroll = ScrollController();
        addTearDown(originScroll.dispose);
        final openMoments = find.byKey(const Key('origin-open-moments'));

        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  Builder(
                    builder: (context) => TextButton(
                      key: const Key('origin-open-moments'),
                      focusNode: originFocus,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PrincipalMomentsPreviewPage(
                            onOpenHappens: () => navigatorKey.currentState!.pop(),
                          ),
                        ),
                      ),
                      child: const Text('Abrir Momentos'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('origin-feed'),
                      controller: originScroll,
                      itemCount: 40,
                      itemBuilder: (_, index) =>
                          SizedBox(height: 64, child: Text('Publicação $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        originScroll.jumpTo(originOffset);
        originFocus.requestFocus();
        await tester.pump();
        expect(originFocus.hasPrimaryFocus, isTrue);
        expect(originScroll.offset, originOffset);

        await tester.tap(openMoments);
        await tester.pumpAndSettle();

        expect(find.byType(PrincipalMomentsPreviewPage), findsOneWidget);
        expect(pageView, findsOneWidget);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Momentos');
        expect(originFocus.hasPrimaryFocus, isFalse);

        if (closeWithEscape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(back);
        }
        await tester.pumpAndSettle();

        expect(find.byType(PrincipalMomentsPreviewPage), findsNothing, reason: 'viewer nao saiu');
        expect(openMoments, findsOneWidget);
        expect(
          originFocus.hasPrimaryFocus,
          isTrue,
          reason:
              'foco primario apos o retorno: '
              '${FocusManager.instance.primaryFocus?.debugLabel ?? 'nenhum'}',
        );
        expect(
          originScroll.offset,
          originOffset,
          reason: 'posicao da origem apos o retorno: ${originScroll.offset}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _grantedMoment = PrincipalMomentPreviewItem(
  id: 'moment-autorizado',
  canRemove: true,
  author: 'Colégio Coelo',
  context: '3º ano A',
  time: 'Agora',
  caption: 'Momento autorizado para aceitacao.',
  likes: 12,
  comments: 3,
  shares: 1,
  saves: 2,
  imageIndex: 0,
);

/// Fake minimo do repositorio de feed; os fakes dos testes vizinhos sao
/// privados, por isso o essencial e replicado aqui.
final class _FakeMomentsFeedRepository implements PrincipalMomentsFeedRepository {
  _FakeMomentsFeedRepository(this._moments);

  final List<PrincipalMomentPreviewItem> _moments;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async => _moments;

  @override
  Future<PrincipalMomentsMediaRead> resolveMedia(PrincipalMomentsMediaDescriptor media) =>
      Future<PrincipalMomentsMediaRead>.error(const PrincipalMomentsFeedUnavailable());

  @override
  Future<void> removeMoment(PrincipalMomentsRemoveCommand command) =>
      Future<void>.error(const PrincipalMomentsRemoveUnavailable());
}
