// Aceitacao comportamental (sem golden) do Perfil institucional do Coelo
// (Principal) contra specs/050-principal-ui-ux-closure.md, secao "Perfil":
// capa, avatar, identidade, contexto, metricas e abas Acontece, Momentos,
// Circulares e Sobre, sem seguidores publicos. Complementa, sem repetir,
// test/features/principal_profile/presentation/principal_profile_preview_page_test.dart
// e principal_profile_responsive_test.dart.

import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_profile/domain/principal_profile_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = PrincipalProfilePreviewData.horizon;
const _viewportHeight = 1100.0;

const _messageKey = Key('principal-profile-message');
const _followKey = Key('principal-profile-follow');
const _tabsScrollKey = Key('principal-profile-tabs-scroll');
const _tabAcontece = Key('principal-profile-tab-acontece');
const _tabMomentos = Key('principal-profile-tab-momentos');
const _tabCirculares = Key('principal-profile-tab-circulares');
const _tabSobre = Key('principal-profile-tab-sobre');
const _tabKeys = [_tabAcontece, _tabMomentos, _tabCirculares, _tabSobre];

const _expectedMetricLabels = ['Publicações', 'Momentos', 'Circulares'];

// Texto distintivo de cada painel de aba (fixtures deterministicas).
const _happensPanelText = 'Aula prática sobre civilizações antigas!';
const _momentsPanelText = 'Música que inspira';
const _circularsPanelText = 'Circular autorizada';
const _aboutPanelText = 'Uma história feita em comunidade';

void main() {
  for (final (themeName, theme) in [('claro', CoeloTheme.light), ('escuro', CoeloTheme.dark)]) {
    for (final width in [375.0, 768.0, 1440.0]) {
      testWidgets('Perfil ${width.toInt()}x1100 $themeName: capa, avatar, identidade, contexto, '
          'metricas e abas sem seguidores publicos', (tester) async {
        await _pump(tester, width: width, theme: theme);
        final viewport = Size(width, _viewportHeight);

        expect(tester.takeException(), isNull);

        // Capa: imagem semantica landscape do campus.
        final coverSemantics = _imageSemantics('Campus do ${_fixture.name}');
        expect(coverSemantics, findsOneWidget);
        final cover = find.descendant(
          of: coverSemantics,
          matching: _assetImage('institution-cover.png'),
        );
        expect(cover, findsOneWidget);
        final coverRect = tester.getRect(cover);
        expect(coverRect.width, greaterThan(coverRect.height));

        // Avatar: brasao sobreposto a borda inferior da capa.
        final avatarSemantics = _imageSemantics('Brasão do ${_fixture.name}');
        expect(avatarSemantics, findsOneWidget);
        expect(
          find.descendant(of: avatarSemantics, matching: _assetImage('institution-crest.png')),
          findsOneWidget,
        );
        final avatarRect = tester.getRect(avatarSemantics);
        expect(avatarRect.top, lessThan(coverRect.bottom));
        expect(avatarRect.bottom, greaterThan(coverRect.bottom));
        expect(_within(avatarRect, viewport), isTrue, reason: 'avatar fora do viewport');

        // Identidade: nome ao lado do selo verificado.
        final verified = find.byIcon(Icons.verified_rounded);
        expect(verified, findsOneWidget);
        final identityRow = find.ancestor(of: verified, matching: find.byType(Row)).first;
        expect(
          find.descendant(of: identityRow, matching: find.text(_fixture.name)),
          findsOneWidget,
        );

        // Contexto: chip com icone institucional e o tipo da fixture.
        expect(
          find.descendant(of: _contextChip(), matching: find.text(_fixture.typeLabel)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _contextChip(), matching: find.byIcon(Icons.school_outlined)),
          findsOneWidget,
        );

        _expectMetricsCard(tester);
        _expectTabsPresent(tester);
        _expectNoPublicFollowSignals();
        _expectMessageActionAccessible(tester, viewport);

        // Abas numa unica linha; em 375 essa linha e rolavel.
        _expectTabsOnOneLine(tester);
        if (width == 375.0) {
          expect(find.byKey(_tabsScrollKey), findsOneWidget);
        }
      });
    }
  }

  for (final (themeName, theme, width) in [
    ('escuro', CoeloTheme.dark, 375.0),
    ('claro', CoeloTheme.light, 1440.0),
  ]) {
    testWidgets('Perfil ${width.toInt()}x1100 $themeName a 200% de texto: sem overflow, metricas '
        'integras, Mensagem acessivel e abas alcancaveis', (tester) async {
      await _pump(tester, width: width, theme: theme, textScale: 2, withTabContent: true);
      final viewport = Size(width, _viewportHeight);

      expect(tester.takeException(), isNull);
      _expectMetricsCard(tester);
      _expectTabsPresent(tester);
      _expectNoPublicFollowSignals();
      _expectMessageActionAccessible(tester, viewport);
      _expectTabsOnOneLine(tester);

      await tester.ensureVisible(find.byKey(_tabSobre));
      await tester.tap(find.byKey(_tabSobre));
      await tester.pumpAndSettle();
      expect(find.text(_aboutPanelText), findsOneWidget);
      expect(find.byKey(_tabSobre).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Perfil 375x1100: abas em linha rolavel com Circulares e Sobre alcancaveis', (
    tester,
  ) async {
    await _pump(tester, width: 375, theme: CoeloTheme.light, withTabContent: true);

    final tabsScroll = find.byKey(_tabsScrollKey);
    expect(tabsScroll, findsOneWidget);
    expect(tester.widget<SingleChildScrollView>(tabsScroll).scrollDirection, Axis.horizontal);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: tabsScroll, matching: find.byType(Scrollable)),
    );
    expect(
      scrollable.position.maxScrollExtent,
      greaterThan(0),
      reason: 'em 375 a linha de abas precisa rolar para alcancar Circulares e Sobre',
    );
    _expectTabsOnOneLine(tester);
    expect(
      tester.getRect(find.byKey(_tabSobre)).right,
      greaterThan(375),
      reason: 'Sobre nasce fora da largura visivel e depende da rolagem horizontal',
    );

    await tester.ensureVisible(find.byKey(_tabCirculares));
    await tester.pumpAndSettle();
    expect(find.byKey(_tabCirculares).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(_tabCirculares));
    await tester.pumpAndSettle();
    expect(find.text(_circularsPanelText), findsOneWidget);
    expect(find.textContaining(_happensPanelText), findsNothing);

    await tester.ensureVisible(find.byKey(_tabSobre));
    await tester.pumpAndSettle();
    expect(find.byKey(_tabSobre).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(_tabSobre));
    await tester.pumpAndSettle();
    expect(find.text(_aboutPanelText), findsOneWidget);
    expect(find.text(_circularsPanelText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [375.0, 1440.0]) {
    testWidgets('Perfil ${width.toInt()}x1100: Tab a partir do inicio alcanca Mensagem e as quatro '
        'abas com foco visivel', (tester) async {
      await _pump(tester, width: width, theme: CoeloTheme.light);
      final viewport = Size(width, _viewportHeight);
      const targets = [_messageKey, ..._tabKeys];
      final reached = <Key>[];

      for (var press = 0; press < 40 && reached.length < targets.length; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focusedKey = _focusedTarget(targets);
        if (focusedKey == null || reached.contains(focusedKey)) {
          continue;
        }
        reached.add(focusedKey);

        // Foco visivel: modo tradicional (anel de foco pintado) no proprio botao
        // e alvo trazido para dentro do viewport pela travessia.
        expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
        final label = find.descendant(of: find.byKey(focusedKey), matching: find.byType(Text));
        expect(
          Focus.of(tester.element(label.first), createDependency: false).hasPrimaryFocus,
          isTrue,
          reason: '$focusedKey deveria deter o foco primario',
        );
        expect(
          _within(tester.getRect(find.byKey(focusedKey)), viewport),
          isTrue,
          reason: '$focusedKey focado fora do viewport',
        );
      }

      expect(reached, containsAll(targets), reason: 'alcancados por Tab: $reached');
      final messageIndex = reached.indexOf(_messageKey);
      for (final tabKey in _tabKeys) {
        expect(messageIndex, lessThan(reached.indexOf(tabKey)));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Perfil: tocar em cada aba troca o painel e a aba escolhida sobrevive ao redimensionar',
    (tester) async {
      await _pump(tester, width: 768, theme: CoeloTheme.light, withTabContent: true);

      expect(find.textContaining(_happensPanelText), findsOneWidget);
      expect(find.textContaining(_momentsPanelText), findsNothing);
      _expectSelectedTab(tester, _tabAcontece);

      await _selectTab(tester, _tabMomentos);
      expect(find.textContaining(_momentsPanelText), findsOneWidget);
      expect(find.textContaining(_happensPanelText), findsNothing);
      _expectSelectedTab(tester, _tabMomentos);

      await _selectTab(tester, _tabCirculares);
      expect(find.text(_circularsPanelText), findsOneWidget);
      expect(find.textContaining(_momentsPanelText), findsNothing);
      _expectSelectedTab(tester, _tabCirculares);

      await _selectTab(tester, _tabSobre);
      expect(find.text(_aboutPanelText), findsOneWidget);
      expect(find.text(_circularsPanelText), findsNothing);
      _expectSelectedTab(tester, _tabSobre);

      await _selectTab(tester, _tabAcontece);
      expect(find.textContaining(_happensPanelText), findsOneWidget);
      expect(find.text(_aboutPanelText), findsNothing);
      _expectSelectedTab(tester, _tabAcontece);

      // Estado preservado ao redimensionar: 768 -> 375 -> 1440 -> 768.
      await _selectTab(tester, _tabMomentos);
      for (final width in [375.0, 1440.0, 768.0]) {
        await tester.binding.setSurfaceSize(Size(width, _viewportHeight));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow ao redimensionar para $width');
        expect(
          find.textContaining(_momentsPanelText),
          findsOneWidget,
          reason: 'painel Momentos perdido ao redimensionar para $width',
        );
        expect(find.textContaining(_happensPanelText), findsNothing);
        _expectSelectedTab(tester, _tabMomentos);
        expect(find.text(_fixture.name), findsWidgets);
      }
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required ThemeData theme,
  double textScale = 1,
  bool withTabContent = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, _viewportHeight));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PrincipalProfilePreviewPage(
        onOpenAgenda: () {},
        circularRepository: withTabContent ? _CircularRepositoryFixture() : null,
        circularScope: withTabContent ? const CircularScope(institutionId: 'institution-1') : null,
        aboutPage: withTabContent ? _aboutPageFixture() : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProfileAboutPage _aboutPageFixture() => ProfileAboutPage(
  subject: const ProfileAboutSubjectRef(
    type: ProfileAboutSubjectType.institution,
    institutionId: 'institution-1',
  ),
  version: 1,
  fields: const [
    ProfileAboutField(key: ProfileAboutFieldKey.preciseLocation, value: '-23.5505,-46.6333'),
  ],
  sections: const [
    ProfileAboutSection(
      id: 'history',
      type: ProfileAboutSectionType.text,
      title: _aboutPanelText,
      body: 'Conteúdo editorial autorizado.',
      position: 0,
      state: ProfileAboutSectionState.published,
    ),
  ],
);

Finder _imageSemantics(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics && widget.properties.image == true && widget.properties.label == label,
);

Finder _assetImage(String suffix) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName.endsWith(suffix),
);

Finder _contextChip() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) {
    return false;
  }
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.border != null &&
      decoration.borderRadius == BorderRadius.circular(CoeloRadius.full);
});

final Finder _metricLabels = find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('principal-profile-metric-'),
);

/// As quatro abas partilham uma unica linha: centros verticais alinhados e
/// ordem horizontal sem empilhamento. Um rotulo que quebre linha (ex.:
/// "Circulares" a 200%) pode deixar a aba mais alta sem tira-la da linha.
void _expectTabsOnOneLine(WidgetTester tester) {
  final rects = [for (final key in _tabKeys) tester.getRect(find.byKey(key))];
  expect(
    {for (final rect in rects) rect.center.dy.roundToDouble()},
    hasLength(1),
    reason: 'abas fora de uma unica linha: $rects',
  );
  for (var index = 1; index < rects.length; index++) {
    expect(
      rects[index].left,
      greaterThanOrEqualTo(rects[index - 1].right - 0.5),
      reason: 'abas empilhadas: $rects',
    );
  }
}

bool _within(Rect rect, Size viewport) =>
    rect.left >= -0.5 &&
    rect.top >= -0.5 &&
    rect.right <= viewport.width + 0.5 &&
    rect.bottom <= viewport.height + 0.5;

void _expectMetricsCard(WidgetTester tester) {
  expect(
    _fixture.metrics.map((metric) => metric.label).toList(),
    _expectedMetricLabels,
    reason: 'a fixture deve expor exatamente Publicações, Momentos e Circulares',
  );
  expect(_metricLabels, findsNWidgets(_expectedMetricLabels.length));
  expect(
    tester.widgetList<Text>(_metricLabels).map((text) => text.data).toList(),
    _expectedMetricLabels,
  );
  for (final metric in _fixture.metrics) {
    expect(metric.value.trim(), isNotEmpty);
    expect(metric.value, isNot('0'));
    final label = find.byKey(Key('principal-profile-metric-${metric.label}'));
    expect(label, findsOneWidget);
    final column = find.ancestor(of: label, matching: find.byType(Column)).first;
    final texts = tester
        .widgetList<Text>(find.descendant(of: column, matching: find.byType(Text)))
        .map((text) => text.data)
        .toList();
    expect(texts, [metric.value, metric.label], reason: 'metrica ${metric.label}');
  }
}

void _expectTabsPresent(WidgetTester tester) {
  for (final (key, label) in [
    (_tabAcontece, 'Acontece'),
    (_tabMomentos, 'Momentos'),
    (_tabCirculares, 'Circulares'),
    (_tabSobre, 'Sobre'),
  ]) {
    expect(find.byKey(key), findsOneWidget);
    expect(find.descendant(of: find.byKey(key), matching: find.text(label)), findsOneWidget);
    expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(CoeloSize.touchMin));
  }
}

void _expectNoPublicFollowSignals() {
  for (final label in const ['Seguidores', 'Seguindo', 'Acompanhar']) {
    expect(find.text(label), findsNothing);
  }
  expect(
    find.textContaining(RegExp('seguidor|seguindo|acompanhar', caseSensitive: false)),
    findsNothing,
  );
  expect(find.byKey(_followKey), findsNothing);
}

void _expectMessageActionAccessible(WidgetTester tester, Size viewport) {
  final message = find.byKey(_messageKey);
  expect(message, findsOneWidget);
  expect(find.descendant(of: message, matching: find.text('Mensagem')), findsOneWidget);
  expect(tester.getSize(message).height, greaterThanOrEqualTo(CoeloSize.touchMin));
  expect(message.hitTestable(), findsOneWidget);
  expect(_within(tester.getRect(message), viewport), isTrue, reason: 'Mensagem fora do viewport');
}

Future<void> _selectTab(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void _expectSelectedTab(WidgetTester tester, Key selected) {
  for (final key in _tabKeys) {
    final semantics = tester.widget<Semantics>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Semantics)).first,
    );
    expect(
      semantics.properties.selected,
      key == selected,
      reason: '$key deveria ${key == selected ? '' : 'nao '}estar selecionada',
    );
  }
}

Key? _focusedTarget(List<Key> targets) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return null;
  }
  Key? found;
  if (targets.contains(context.widget.key)) {
    return context.widget.key;
  }
  context.visitAncestorElements((element) {
    if (targets.contains(element.widget.key)) {
      found = element.widget.key;
      return false;
    }
    return true;
  });
  return found;
}

final class _CircularRepositoryFixture implements CircularRepository {
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async => PrincipalCursorPage(
    items: [
      CircularSummary(
        id: 'circular-1',
        title: _circularsPanelText,
        excerpt: 'Conteúdo do contexto autenticado.',
        authorName: _fixture.name,
        contextLabel: 'Instituição',
        publishedAt: DateTime.utc(2026, 8, 21),
        attachmentCount: 0,
        questionCount: 0,
        responseState: CircularResponseState.unanswered,
      ),
    ],
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
