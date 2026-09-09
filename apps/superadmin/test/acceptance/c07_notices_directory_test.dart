import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_status_presentation.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/notices/support/fake_notice_repository.dart';

/// C07 - Comunicações: o card compacto em 375 medido contra a referência
/// administrativa aprovada, na mesma execução.
///
/// Critério: "Comunicados: card compacto em 375 comparado à referência
/// administrativa aprovada — título, indicador, recorte."
///
/// A referência é Instituições, por decisão aprovada e não por analogia:
///
/// - `docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md`
///   (`status: approved-design`, `updated_at: 2026-08-31`): a lista compacta
///   mobile e a tabela "reutilizam literalmente as anatomias correspondentes
///   de Instituições, incluindo alinhamento horizontal e vertical, baseline
///   tipográfica, alturas, paddings, gaps, estados, largura natural,
///   scrollbar e paginação".
/// - `docs/superpowers/specs/2026-09-01-superadmin-communication-finish-design.md`
///   (`status: approved`): "Instituições é a baseline obrigatória para
///   toolbar, ações de arquivo, criação, tabela, cards e paginação."
/// - `docs/superpowers/specs/2026-07-21-superadmin-import-activity-theme-prototype-design.md`
///   (`status: approved`): o indicador de status é "um único círculo
///   centralizado dentro de uma área interativa invisível de pelo menos
///   48 px". Invisível significa que o alvo não pode aparecer como largura de
///   layout empurrando os vizinhos da linha.
///
/// Já provado por `test/features/notices/notice_card_status_layout_test.dart`
/// (C05, correção `116231bd`) e por isso NÃO repetido aqui:
///
/// 1. um título curto cabe em uma linha no card compacto em 375;
/// 2. o indicador mede 48x48 e não sobrepõe o título nem o menu de ações;
/// 3. o toque no centro do indicador alterna o rótulo e não rouba o toque do
///    badge de tipo ao lado;
/// 4. o indicador é botão semântico, focalizável, e o Tab não lança exceção.
///
/// O que este arquivo acrescenta é a comparação medida contra a baseline, que
/// nenhum dos testes focais faz: o mesmo texto de título nos dois cards, a
/// posição relativa do indicador nas duas telas, o recorte do último card em
/// 375 e a separação entre alvo efetivo e largura de layout do indicador.
/// Cada asserção guarda antes o valor da referência: se a baseline mudar ou o
/// instrumento quebrar, a mensagem diz isso em vez de acusar Comunicações.
///
/// Sem golden: todas as provas são medidas numéricas com o valor na mensagem.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A marca é carregada porque as medidas são de texto. O ícone do Material
  // não é carregado de propósito: `Icon` fixa a caixa pelo `size`, então a
  // ausência do glifo não move layout algum e um artefato a menos é uma fonte
  // a menos de falso vermelho.
  setUpAll(_loadBrandFont);

  // ---------------------------------------------------------------------------
  // Título
  // ---------------------------------------------------------------------------
  testWidgets(
    'comunicados.card@375: o título do card compacto ocupa as mesmas linhas '
    'que o título do card de Instituições com o mesmo texto',
    (tester) async {
      await _useSurface(tester);

      await _pumpNotices(tester, repository: _notices(const [_sharedTitle]));
      final noticeTitleFinder = find.text(_sharedTitle);
      expect(
        noticeTitleFinder,
        findsOneWidget,
        reason: 'Instrumento: o título do card de Comunicações não foi encontrado uma única vez.',
      );
      final notice = _titleMetrics(tester, noticeTitleFinder);

      await _pumpInstitutions(tester, _institutions(const [_sharedTitle]));
      final referenceTitleFinder = find.text(_sharedTitle);
      expect(
        referenceTitleFinder,
        findsOneWidget,
        reason: 'Instrumento: o título do card de Instituições não foi encontrado uma única vez.',
      );
      final reference = _titleMetrics(tester, referenceTitleFinder);

      expect(
        reference.lines,
        1,
        reason:
            'Instrumento ou baseline: em 375 o card de Instituições deveria manter o título em '
            'uma linha, recortando com reticências. Medido ${reference.lines} linha(s) em '
            '${_px(reference.width)} px de largura útil, altura ${_px(reference.height)} px, '
            'linha de ${_px(reference.lineHeight)} px.',
      );

      expect(
        notice.lines,
        reference.lines,
        reason:
            'A lista compacta de Comunicações reutiliza literalmente a anatomia do card de '
            'Instituições (spec 2026-08-05, direção visual; spec 2026-09-01, direção visual), '
            'inclusive baseline tipográfica e alturas: com o mesmo texto, o título tem de '
            'ocupar o mesmo número de linhas em 375. Medido: Comunicações ${notice.lines} '
            'linha(s) em ${_px(notice.width)} px de largura útil (altura ${_px(notice.height)} '
            'px, linha de ${_px(notice.lineHeight)} px); Instituições ${reference.lines} '
            'linha(s) em ${_px(reference.width)} px (altura ${_px(reference.height)} px, linha '
            'de ${_px(reference.lineHeight)} px). Comunicações recebe mais largura e ainda '
            'assim quebra, porque o card admite duas linhas onde a baseline recorta em uma.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Indicador: posição relativa
  // ---------------------------------------------------------------------------
  testWidgets(
    'comunicados.card@375: o indicador de status divide a linha do título, '
    'como no card de Instituições',
    (tester) async {
      await _useSurface(tester);

      await _pumpNotices(tester, repository: _notices(const [_shortTitle]));
      final noticeIndicator = find.byType(CoeloAdminExpandableStatusIndicator);
      expect(
        noticeIndicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Comunicações.',
      );
      final noticeTitleRect = tester.getRect(find.text(_shortTitle));
      final noticeIndicatorRect = tester.getRect(noticeIndicator);
      final noticeSharesRow = _sharesRow(noticeTitleRect, noticeIndicatorRect);

      await _pumpInstitutions(tester, _institutions(const [_shortTitle]));
      final referenceIndicator = find.byType(ExpandableInstitutionStatusIndicator);
      expect(
        referenceIndicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Instituições.',
      );
      final referenceTitleRect = tester.getRect(find.text(_shortTitle));
      final referenceIndicatorRect = tester.getRect(referenceIndicator);
      final referenceSharesRow = _sharesRow(referenceTitleRect, referenceIndicatorRect);

      expect(
        referenceSharesRow,
        isTrue,
        reason:
            'Instrumento ou baseline: no card de Instituições o indicador ocupa a mesma faixa '
            'vertical do título. Medido título ${_band(referenceTitleRect)} e indicador '
            '${_band(referenceIndicatorRect)}.',
      );

      expect(
        noticeSharesRow,
        referenceSharesRow,
        reason:
            'A anatomia do card compacto é a de Instituições, reutilizada literalmente, '
            'inclusive alinhamento horizontal e vertical (spec 2026-08-05, direção visual). '
            'Na baseline o indicador divide a linha do título. Medido em 375: Comunicações '
            'título ${_band(noticeTitleRect)} e indicador ${_band(noticeIndicatorRect)}, '
            'compartilham=$noticeSharesRow; Instituições título ${_band(referenceTitleRect)} e '
            'indicador ${_band(referenceIndicatorRect)}, compartilham=$referenceSharesRow. '
            'Em Comunicações o indicador desceu para a linha de descritores em `116231bd`, '
            'para devolver ao título a largura que os 48 px de `a0be1abe` tomaram.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Recorte
  // ---------------------------------------------------------------------------
  testWidgets(
    'comunicados.card@375: no fim da rolagem o último card aparece inteiro, '
    'sem ser cortado pelo rodapé nem pela borda do viewport',
    (tester) async {
      await _useSurface(tester);

      await _pumpNotices(
        tester,
        repository: _notices(_seriesTitles('Comunicado')),
        onCreate: () {},
      );
      final noticeClip = await _lastCardClipping(
        tester,
        scrollable: find.byKey(const Key('notice-card-list')),
        cards: find.byType(CoeloAdminInteractiveCard),
      );

      await _pumpInstitutions(tester, _institutions(_seriesTitles('Instituição')));
      final referenceClip = await _lastCardClipping(
        tester,
        scrollable: find.byKey(const Key('institution-directory-content-scroll')),
        cards: _institutionCards(),
      );

      expect(
        referenceClip.hiddenByFooter <= 0 && referenceClip.hiddenByViewport <= 0,
        isTrue,
        reason:
            'Instrumento ou baseline: em 375 o último card de Instituições deveria terminar '
            'acima do rodapé e dentro do viewport. Medido ${referenceClip.describe()}.',
      );

      expect(
        noticeClip.hiddenByFooter,
        lessThanOrEqualTo(0.5),
        reason:
            'Em 375 a paginação vem logo depois da lista, dentro do rodapé compartilhado '
            '(spec 2026-09-01, direção visual), e não pode esconder card algum. Medido: '
            'Comunicações ${noticeClip.describe()}; Instituições ${referenceClip.describe()}.',
      );
      expect(
        noticeClip.hiddenByViewport,
        lessThanOrEqualTo(0.5),
        reason:
            'No fim da rolagem o último card compacto tem de caber inteiro no viewport de 375. '
            'Medido: Comunicações ${noticeClip.describe()}; '
            'Instituições ${referenceClip.describe()}.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'O card compacto em 375 não pode estourar layout ao rolar até o fim.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Indicador: alvo de toque efetivo
  // ---------------------------------------------------------------------------
  testWidgets(
    'comunicados.card@375: o indicador recolhido tem alvo efetivo de 48 px',
    (tester) async {
      await _useSurface(tester);

      await _pumpNotices(tester, repository: _notices(const [_shortTitle]));
      final indicator = find.byType(CoeloAdminExpandableStatusIndicator);
      expect(
        indicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Comunicações.',
      );
      // O hit test é feito em coordenadas de tela: sem trazer o indicador para
      // dentro do viewport, um zero mediria a rolagem, não o alvo.
      await tester.ensureVisible(indicator);
      await tester.pumpAndSettle();
      expect(
        _hits(tester, tester.renderObject(indicator), tester.getCenter(indicator)),
        isTrue,
        reason:
            'Instrumento: o centro do indicador de Comunicações não recebe o ponteiro depois de '
            'trazido para o viewport de 375.',
      );
      final noticeTarget = _touchTarget(tester, indicator);

      await _pumpInstitutions(tester, _institutions(const [_shortTitle]));
      final referenceIndicator = find.byType(ExpandableInstitutionStatusIndicator);
      expect(
        referenceIndicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Instituições.',
      );
      await tester.ensureVisible(referenceIndicator);
      await tester.pumpAndSettle();
      final referenceTarget = _touchTarget(tester, referenceIndicator);

      // A referência é medida como contexto, não como asserção: o alvo de 24 px
      // de Instituições é pendência do próprio diretório de Instituições e não
      // pertence a este recorte.
      final referenceLabel = referenceTarget.width <= 0
          ? 'não medido, o centro do indicador não recebeu o ponteiro nesta rolagem'
          : '${_px(referenceTarget.width)}x${_px(referenceTarget.height)} px';
      final context =
          'Alvo medido por hit test a partir do centro, bissecando até a borda. '
          'Comunicações ${_px(noticeTarget.width)}x${_px(noticeTarget.height)} px; '
          'Instituições (referência, apenas contexto) $referenceLabel.';

      expect(
        noticeTarget.width,
        greaterThanOrEqualTo(CoeloSize.touchMin - 0.5),
        reason:
            'Alvos de 48 px são obrigatórios no diretório (spec 2026-08-05, responsividade e '
            'acessibilidade) e o indicador é interativo: alterna o rótulo. $context',
      );
      expect(
        noticeTarget.height,
        greaterThanOrEqualTo(CoeloSize.touchMin - 0.5),
        reason:
            'Alvos de 48 px são obrigatórios no diretório (spec 2026-08-05, responsividade e '
            'acessibilidade) e o indicador é interativo: alterna o rótulo. $context',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Indicador: largura de layout do alvo
  // ---------------------------------------------------------------------------
  testWidgets(
    'comunicados.card@375: o alvo do indicador não vira largura de layout '
    'além da que a referência ocupa',
    (tester) async {
      await _useSurface(tester);

      await _pumpNotices(tester, repository: _notices(const [_shortTitle]));
      final indicator = find.byType(CoeloAdminExpandableStatusIndicator);
      expect(
        indicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Comunicações.',
      );
      final noticeLayout = tester.getSize(indicator);

      await _pumpInstitutions(tester, _institutions(const [_shortTitle]));
      final referenceIndicator = find.byType(ExpandableInstitutionStatusIndicator);
      expect(
        referenceIndicator,
        findsOneWidget,
        reason: 'Instrumento: esperado exatamente um indicador de status no card de Instituições.',
      );
      final referenceLayout = tester.getSize(referenceIndicator);

      expect(
        referenceLayout.width,
        lessThanOrEqualTo(CoeloSpacing.space6 + 0.5),
        reason:
            'Instrumento ou baseline: recolhido, o indicador de Instituições é o círculo de 24 '
            'px e ocupa só isso de largura. Medido ${_px(referenceLayout.width)} px.',
      );

      expect(
        noticeLayout.width,
        lessThanOrEqualTo(referenceLayout.width + 0.5),
        reason:
            'O alvo de 48 px pertence a "uma área interativa invisível" em volta do círculo '
            '(spec 2026-07-21, protótipo refinado): invisível é área que não consome largura de '
            'layout nem empurra vizinho. Recolhido, o indicador tem de ocupar na linha a mesma '
            'largura da referência. Medido em 375: Comunicações '
            '${_px(noticeLayout.width)}x${_px(noticeLayout.height)} px de caixa de layout; '
            'Instituições ${_px(referenceLayout.width)}x${_px(referenceLayout.height)} px. '
            'Foi essa largura extra que, em `a0be1abe`, tirou do título a largura que o fez '
            'quebrar em 375, e que `116231bd` contornou movendo o indicador de linha em vez de '
            'devolver a largura.',
      );
    },
  );
}

// -----------------------------------------------------------------------------
// Fixtures
// -----------------------------------------------------------------------------

const _mobile = Size(375, 900);

/// O mesmo texto nos dois cards: a comparação só é justa quando a única
/// variável é a anatomia do card.
const _sharedTitle = 'Comunicado sobre a nova rotina de entrada e saída das turmas da tarde';

/// Curto o bastante para caber em uma linha nos dois cards: nas provas de
/// indicador o título não pode ser a variável.
const _shortTitle = 'Rotina da tarde';

List<String> _seriesTitles(String prefix) => [
  for (var index = 1; index <= 6; index++) '$prefix ${index.toString().padLeft(2, '0')}',
];

FakeNoticeRepository _notices(List<String> titles) {
  final now = DateTime.utc(2026, 8, 20, 12);
  final repository = FakeNoticeRepository(now: () => now);
  for (final title in titles) {
    repository.create(
      NoticeDraft(
        type: CommunicationType.notice,
        title: title,
        message: 'Mensagem de exemplo',
        priority: NoticePriority.routine,
        audience: NoticeAudience.everyone,
        audienceLabel: 'Todos',
        behavior: NoticeBehavior.dismissible,
      ),
    );
  }
  return repository;
}

List<InstitutionDirectoryItem> _institutions(List<String> names) => [
  for (var index = 0; index < names.length; index++)
    InstitutionDirectoryItem(
      id: 'c07-reference-${index + 1}',
      publicName: names[index],
      tradeName: null,
      legalName: null,
      primaryDomain: null,
      status: InstitutionStatus.active,
      typeId: null,
      typeName: null,
      city: null,
      state: null,
      planId: null,
      planName: null,
      unitsCount: 0,
      groupsCount: 0,
    ),
];

// -----------------------------------------------------------------------------
// Harness
// -----------------------------------------------------------------------------

Future<void> _useSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_mobile);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpNotices(
  WidgetTester tester, {
  required FakeNoticeRepository repository,
  VoidCallback? onCreate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: NoticeDirectoryPage(
          repository: repository,
          canManageLifecycle: true,
          onCreate: onCreate,
          onEdit: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpInstitutions(WidgetTester tester, List<InstitutionDirectoryItem> items) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: InstitutionDirectoryPage(
        repository: FakeInstitutionDirectoryRepository(items: items),
        logout: () async => const LogoutResult.success(),
        onCreate: () {},
        onEdit: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadBrandFont() async {
  final loader = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await loader.load();
}

Finder _institutionCards() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  if (key is! ValueKey<String>) return false;
  final value = key.value;
  return value.startsWith('institution-card-') &&
      value != 'institution-card-grid' &&
      !value.startsWith('institution-card-surface-') &&
      !value.startsWith('institution-card-detail-');
});

// -----------------------------------------------------------------------------
// Medidas
// -----------------------------------------------------------------------------

typedef _TitleMetrics = ({int lines, double width, double height, double lineHeight});

/// Conta as linhas realmente renderizadas: a altura da caixa dividida pela
/// altura de uma linha do mesmo span, com o mesmo `textScaler`. Ler o
/// `maxLines` do widget seria afirmar a implementação, e contar as linhas
/// naturais ignoraria o recorte por reticências, que é justamente o que a
/// baseline faz.
_TitleMetrics _titleMetrics(WidgetTester tester, Finder title) {
  final paragraph = tester.renderObject<RenderParagraph>(title);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout();
  final lineHeight = painter.height;
  painter.dispose();
  final size = paragraph.size;
  return (
    lines: lineHeight <= 0 ? 0 : (size.height / lineHeight).round(),
    width: size.width,
    height: size.height,
    lineHeight: lineHeight,
  );
}

/// Duas caixas dividem a mesma linha quando suas faixas verticais se cruzam.
bool _sharesRow(Rect first, Rect second) =>
    first.top < second.bottom && second.top < first.bottom;

typedef _Clipping = ({
  Rect card,
  Rect viewport,
  Rect footer,
  double hiddenByFooter,
  double hiddenByViewport,
});

extension _ClippingDescription on _Clipping {
  String describe() =>
      'último card ${_band(card)}, viewport ${_band(viewport)}, rodapé começa em '
      '${_px(footer.top)}; escondido pelo rodapé ${_px(hiddenByFooter)} px, escondido pela '
      'borda do viewport ${_px(hiddenByViewport)} px';
}

/// Rola até o fim e mede quanto do último card fica atrás do rodapé ou fora do
/// viewport. Valores positivos são conteúdo escondido.
Future<_Clipping> _lastCardClipping(
  WidgetTester tester, {
  required Finder scrollable,
  required Finder cards,
}) async {
  expect(
    scrollable,
    findsOneWidget,
    reason: 'Instrumento: a lista rolável do diretório não foi encontrada em 375.',
  );
  await tester.drag(scrollable, const Offset(0, -4000));
  await tester.pumpAndSettle();

  expect(cards, findsWidgets, reason: 'Instrumento: nenhum card no fim da rolagem em 375.');
  final footer = find.byType(SuperadminListingPaginationFooter);
  expect(
    footer,
    findsOneWidget,
    reason: 'Instrumento: o rodapé de paginação não foi encontrado em 375.',
  );

  final card = tester.getRect(cards.last);
  final viewport = tester.getRect(scrollable);
  final footerRect = tester.getRect(footer);
  return (
    card: card,
    viewport: viewport,
    footer: footerRect,
    hiddenByFooter: card.bottom - footerRect.top,
    hiddenByViewport: card.bottom - viewport.bottom,
  );
}

/// Mede a área que responde ao ponteiro no próprio widget do indicador,
/// caminhando do centro para fora e bissecando até a borda. Não depende de
/// `ConstrainedBox`, `padding` ou de qualquer chave: uma área interativa
/// implementada de outra forma continua sendo medida, desde que pertença ao
/// indicador. Área provida por um ancestral não é contada, e isso é
/// intencional: o alvo tem de ser do indicador.
({double width, double height}) _touchTarget(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final centre = tester.getCenter(finder);

  double edge(Offset direction) {
    const limit = 240.0;
    if (!_hits(tester, target, centre)) return 0;
    if (_hits(tester, target, centre + direction * limit)) return limit;
    var inside = 0.0;
    var outside = limit;
    for (var step = 0; step < 24; step++) {
      final middle = (inside + outside) / 2;
      if (_hits(tester, target, centre + direction * middle)) {
        inside = middle;
      } else {
        outside = middle;
      }
    }
    return outside;
  }

  return (
    width: edge(const Offset(-1, 0)) + edge(const Offset(1, 0)),
    height: edge(const Offset(0, -1)) + edge(const Offset(0, 1)),
  );
}

bool _hits(WidgetTester tester, RenderObject target, Offset point) =>
    tester.hitTestOnBinding(point).path.any((entry) => identical(entry.target, target));

String _px(double value) => value.toStringAsFixed(1);

String _band(Rect rect) => '[${_px(rect.top)}, ${_px(rect.bottom)}]';
