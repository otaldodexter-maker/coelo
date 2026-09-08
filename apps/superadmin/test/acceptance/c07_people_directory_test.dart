// C07 - Pessoas / Diretório: aceitação de fluxo, sem golden.
//
// Ações do inventário: people.list, people.create, people.edit, people.links e
// people.reload. Cobre apenas o que os testes focais de `test/features/people/`
// ainda não provam:
//
// - carga que lança `Error` (não `Exception`) sai do loading e cai em falha
//   honesta com retry, sem se disfarçar de vazio nem de "sem resultados"
//   (hunk `on Object` de fdf0972d em `person_directory_view_model.dart`);
// - retry lê exatamente uma vez e deve preservar busca, filtro e página;
// - negado no meio da sessão apaga dados e controles e não fica relendo;
// - "sem resultados" é distinto de vazio e de falha, e limpar restaura o
//   diretório sem deixar o campo de busca contradizendo o que foi carregado;
// - teclado: Tab alcança busca, filtros, tabs lineares de segmentos, toggle de
//   visão, paginação e criar, com alvos de 48 px;
// - foco: o indicador de status é ponto de foco por Tab e precisa responder ao
//   teclado como responde ao toque, com alvo de toque compatível;
// - 375 e 1440 sem exceção de layout em cards, tabela, falha e negado.
//
// Já provado em `test/features/people/` e por isso fora daqui: composição de
// filtros progressivos, colunas da tabela, contadores dos cards, rolagem acima
// da paginação fixa, ocultar ações de arquivo fora do sucesso, estado vazio,
// aparecimento de "sem resultados", cor do status suspenso e troca de
// repositório para negado.
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart' as domain;
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_view_model.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/people/fake_person_directory_repository.dart';

const _failureTitle = 'Não foi possível carregar as pessoas';
const _failureMessage = 'Tente novamente em instantes.';
const _deniedTitle = 'Acesso não autorizado';
const _deniedMessage = 'Você não possui people.read.';
const _emptyTitle = 'Nenhuma pessoa cadastrada';
const _noResultsTitle = 'Nenhum resultado';
const _retryLabel = 'Tentar novamente';
const _clearLabel = 'Limpar filtros';

/// O campo de busca do diretório (o rótulo semântico é o contrato aprovado).
final _searchField = find.byWidgetPredicate(
  (widget) => widget is CoeloSearchField && widget.semanticLabel == 'Buscar pessoas por nome',
);
final _retry = find.widgetWithText(OutlinedButton, _retryLabel);

/// Cards de pessoa: a chave `create-person-card` e a `person-status-…` não
/// entram porque não começam com `person-card-`.
final _personCards = find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('person-card-');
});

void main() {
  // ---------------------------------------------------------------------------
  // people.list: carga que falha
  // ---------------------------------------------------------------------------
  for (final scenario in _errorScenarios) {
    testWidgets(
      'people.list: carga que lança ${scenario.label} sai do loading, mostra '
      'falha com retry e não se disfarça de vazio',
      (tester) async {
        await _useSurface(tester, 1440);
        final repository = _ControlledRepository()
          ..pageFailure = scenario.pageFailure
          ..optionsFailure = scenario.optionsFailure
          ..failSynchronously = scenario.synchronous;

        await tester.pumpWidget(_app(repository));
        // Avança frames com duração fixa: esperar o loading terminar tornaria
        // um hang indistinguível de um timeout de `pumpAndSettle`.
        await _settleLoad(tester);

        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: '${scenario.label}: o diretório ficou preso em loading',
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text(_failureTitle), findsOneWidget);
        expect(find.text(_failureMessage), findsOneWidget);
        expect(tester.widget<OutlinedButton>(_retry).enabled, isTrue);

        // Falha não é vazio, não é "sem resultados" e não deixa dado parcial.
        expect(find.text(_emptyTitle), findsNothing);
        expect(find.text(_noResultsTitle), findsNothing);
        expect(find.text(_deniedTitle), findsNothing);
        expect(_personCards, findsNothing);
        expect(find.byKey(const Key('people-directory-pagination-footer')), findsNothing);
        // Detalhe técnico do erro nunca chega à tela.
        expect(find.textContaining(scenario.leakedDetail), findsNothing);
        // Falha não derruba os controles de quem continua autorizado.
        expect(find.byKey(const Key('people-filter-toolbar')), findsOneWidget);
        expect(find.byKey(const Key('people-segment-selector')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('people.list: o view model completa uma carga que lança Error e volta no retry', () async {
    final repository = _ControlledRepository()..pageFailure = _realCastError;
    final viewModel = PersonDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    // Um hang nunca completaria este future; o timeout transforma-o em falha.
    await viewModel.load().timeout(const Duration(seconds: 2));
    expect(viewModel.state, PersonDirectoryLoadState.failure);
    expect(viewModel.page.items, isEmpty);

    repository
      ..pageFailure = null
      ..optionsFailure = () => RangeError.index(3, const <Object>[], 'options');
    await viewModel.retry().timeout(const Duration(seconds: 2));
    expect(viewModel.state, PersonDirectoryLoadState.failure);

    repository.optionsFailure = null;
    await viewModel.retry().timeout(const Duration(seconds: 2));
    expect(viewModel.state, PersonDirectoryLoadState.success);
    expect(viewModel.page.items, hasLength(domain.PersonDirectoryQuery.cardsPageSize));
  });

  // ---------------------------------------------------------------------------
  // people.reload
  // ---------------------------------------------------------------------------
  testWidgets(
    'people.reload: retry lê exatamente uma vez preservando busca, filtro e página',
    (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField, 'Coelo');
      await _settleSearch(tester);
      _selectStatus(tester, const {domain.PersonStatus.active});
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 2'), findsOneWidget);

      // A ida para a página 2 falha: o estado de falha carrega a consulta que
      // estava ativa (busca + status + página 2).
      repository.pageFailure = () => StateError('página 2 indisponível');
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();

      expect(find.text(_failureTitle), findsOneWidget);
      expect(_personCards, findsNothing);
      final failed = repository.pageQueries.last;
      expect(failed.search, 'Coelo');
      expect(failed.statuses, {domain.PersonStatus.active});
      expect(failed.page, 1);
      final readsBeforeRetry = repository.pageQueries.length;

      repository.pageFailure = null;
      await tester.tap(_retry);
      await tester.pumpAndSettle();

      expect(
        repository.pageQueries.length,
        readsBeforeRetry + 1,
        reason: 'o retry deve reler exatamente uma vez',
      );
      final retried = repository.pageQueries.last;
      final observed =
          'busca="${retried.search}", status=${retried.statuses}, página=${retried.page}; '
          'campo de busca ainda exibe "${_searchText(tester)}"';
      expect(
        retried.search,
        'Coelo',
        reason:
            'o retry releu sem a busca da falha ($observed). O campo continua com o termo '
            'digitado, então a tela mostra o diretório inteiro sob uma busca ativa.',
      );
      expect(retried.statuses, {domain.PersonStatus.active}, reason: 'retry perdeu o filtro');
      expect(retried.page, 1, reason: 'retry voltou para a primeira página');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('people.reload: voltar ao diretório relê o repositório e não serve dado velho', (
    tester,
  ) async {
    await _useSurface(tester, 1440);
    final repository = _ControlledRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.pageQueries, hasLength(1));
    expect(find.text('Aaa Recarregada'), findsNothing);

    // Alguém criou a pessoa em outro lugar enquanto a tela estava fora.
    repository.people.insert(0, _person('acc-reload', 'Aaa Recarregada'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(repository.pageQueries, hasLength(2));
    expect(find.text('Aaa Recarregada'), findsOneWidget);
    expect(_personCards, findsNWidgets(domain.PersonDirectoryQuery.cardsPageSize));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'people.reload: alternar cards e tabela relê com o tamanho aprovado e mantém a busca',
    (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField, 'Coelo');
      await _settleSearch(tester);
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(repository.pageQueries.last.page, 1);
      final readsBefore = repository.pageQueries.length;

      await tester.tap(find.byKey(const Key('people-view-table')));
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBefore + 1);
      final tableQuery = repository.pageQueries.last;
      expect(tableQuery.pageSize, domain.PersonDirectoryQuery.tablePageSize);
      expect(tableQuery.search, 'Coelo');
      expect(tableQuery.page, 0, reason: 'trocar de visão deve voltar para a primeira página');
      expect(find.byKey(const Key('people-table')), findsOneWidget);
      expect(_tableRows(), findsNWidgets(domain.PersonDirectoryQuery.tablePageSize));
      expect(find.byKey(const Key('create-person-banner')), findsOneWidget);
      expect(find.text('Ana Pessoa 1'), findsNothing);

      await tester.tap(find.byKey(const Key('people-view-cards')));
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBefore + 2);
      expect(repository.pageQueries.last.pageSize, domain.PersonDirectoryQuery.cardsPageSize);
      expect(repository.pageQueries.last.search, 'Coelo');
      expect(_personCards, findsNWidgets(domain.PersonDirectoryQuery.cardsPageSize));
      expect(find.byKey(const Key('people-table')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // people.list: acesso negado
  // ---------------------------------------------------------------------------
  testWidgets(
    'people.list: negado no meio da sessão apaga dados e ações e não fica relendo',
    (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(_personCards, findsNWidgets(domain.PersonDirectoryQuery.cardsPageSize));
      expect(find.text('Ana Pessoa 1'), findsOneWidget);

      // A permissão cai entre duas interações do usuário.
      repository.unauthorized = true;
      final readsBefore = repository.pageQueries.length;
      await tester.tap(find.text('Crianças'));
      await tester.pumpAndSettle();

      expect(find.text(_deniedTitle), findsOneWidget);
      expect(find.text(_deniedMessage), findsOneWidget);
      expect(_personCards, findsNothing);
      expect(find.text('Ana Pessoa 1'), findsNothing);
      expect(find.byKey(const Key('people-filter-toolbar')), findsNothing);
      expect(find.byKey(const Key('people-segment-selector')), findsNothing);
      expect(find.byKey(const Key('create-person-card')), findsNothing);
      expect(find.byKey(const Key('create-person-banner')), findsNothing);
      expect(find.byKey(const Key('people-directory-pagination-footer')), findsNothing);
      expect(_retry, findsNothing);
      expect(find.text(_failureTitle), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Nada de laço de releitura contra um backend que já disse não.
      expect(repository.pageQueries, hasLength(readsBefore + 1));
      await tester.pump(const Duration(seconds: 3));
      expect(repository.pageQueries, hasLength(readsBefore + 1));
      expect(find.text(_deniedTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // people.list: sem resultados e limpeza
  // ---------------------------------------------------------------------------
  testWidgets(
    'people.list: "sem resultados" difere de falha e limpar restaura o diretório',
    (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField, 'zzz-sem-correspondencia');
      await _settleSearch(tester);

      expect(find.text(_noResultsTitle), findsOneWidget);
      expect(find.text(_failureTitle), findsNothing);
      expect(find.text(_emptyTitle), findsNothing);
      expect(_retry, findsNothing);
      expect(_personCards, findsNothing);
      expect(find.byKey(const Key('people-directory-pagination-footer')), findsNothing);

      // Caminho 1: o botão da toolbar limpa consulta e campo juntos.
      final readsBeforeToolbar = repository.pageQueries.length;
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('people-filter-toolbar')),
          matching: find.text(_clearLabel),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBeforeToolbar + 1);
      expect(repository.pageQueries.last.hasActiveFilters, isFalse);
      expect(_searchText(tester), '');
      expect(find.text(_noResultsTitle), findsNothing);
      expect(_personCards, findsNWidgets(domain.PersonDirectoryQuery.cardsPageSize));

      // Caminho 2: o botão do painel de "sem resultados", com o mesmo rótulo,
      // precisa deixar a tela igualmente coerente.
      await tester.enterText(_searchField, 'zzz-sem-correspondencia');
      await _settleSearch(tester);
      expect(find.text(_noResultsTitle), findsOneWidget);
      final readsBeforePanel = repository.pageQueries.length;
      await tester.tap(find.widgetWithText(OutlinedButton, _clearLabel));
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBeforePanel + 1);
      expect(repository.pageQueries.last.hasActiveFilters, isFalse);
      expect(_personCards, findsNWidgets(domain.PersonDirectoryQuery.cardsPageSize));
      expect(
        _searchText(tester),
        '',
        reason:
            'o painel limpou a consulta mas manteve o termo no campo: a tela lista o '
            'diretório inteiro sob uma busca aparentemente ativa e o botão de limpar da '
            'toolbar já desapareceu.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // people.list / people.links: segmentos irmãos
  // ---------------------------------------------------------------------------
  testWidgets(
    'people.links: as tabs de segmento são lineares por Tab e Enter troca a categoria',
    (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final reached = await _tabUntil(tester, _segmentTab(domain.PersonDirectorySegment.all));
      expect(reached, isTrue, reason: 'Tab não alcançou a primeira tab de segmento');

      // Categorias irmãs são pontos de foco lineares, uma por Tab.
      for (final segment in const [
        domain.PersonDirectorySegment.institutionalTeam,
        domain.PersonDirectorySegment.guardians,
        domain.PersonDirectorySegment.children,
      ]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          _focusInside(_segmentTab(segment)),
          isTrue,
          reason: 'Tab não seguiu para a tab irmã "${segment.label}"',
        );
      }

      final readsBefore = repository.pageQueries.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBefore + 1);
      expect(repository.pageQueries.last.segment, domain.PersonDirectorySegment.children);
      expect(repository.pageQueries.last.page, 0);
      expect(_personCards, findsNWidgets(8));
      expect(find.text('Ana Pessoa 1'), findsNothing);
      expect(find.text('Criança Coelo 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // people.create / people.edit: teclado
  // ---------------------------------------------------------------------------
  testWidgets(
    'people.create: Tab alcança busca, filtros, tabs, toggle, paginação e criar',
    (tester) async {
      await _useSurface(tester, 1440);
      await tester.pumpWidget(_app(_ControlledRepository()));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'busca': _searchField,
        'filtro de tipo': find.byKey(const Key('people-type-filter')),
        'filtro de status': find.byKey(const Key('people-status-filter')),
        'filtro de instituição': find.byKey(const Key('people-institution-filter')),
        'filtro de UF': find.byKey(const Key('people-state-filter')),
        'filtro de auth': find.byKey(const Key('people-auth-filter')),
        'segmento cards': find.byKey(const Key('people-view-cards')),
        'segmento tabela': find.byKey(const Key('people-view-table')),
        'tabs de segmento': find.byKey(const Key('people-segment-selector')),
        'criar pessoa': find.byKey(const Key('create-person-card')),
        'tamanho de página': find.byKey(const Key('coelo-admin-pagination-page-size')),
        'próxima página': _outlinedButtonLabelled('Próxima'),
      };
      final reached = <String>{};
      final tableFlyoutItem = find.widgetWithText(MenuItemButton, 'Visão agrupada');

      for (var step = 0; step < 200 && reached.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (_focusTouches(entry.value)) reached.add(entry.key);
        }
        // Focar o segmento de tabela por Tab abre o flyout de visões; Escape o
        // fecha e devolve o foco para o percurso continuar.
        if (tableFlyoutItem.evaluate().isNotEmpty) {
          reached.add('segmento tabela');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      expect(
        reached,
        containsAll(targets.keys),
        reason: 'não alcançados por Tab: ${targets.keys.toSet().difference(reached)}',
      );

      // Alvos de toque dos controles alcançados que têm tamanho próprio.
      for (final target in <String, Finder>{
        'criar pessoa': targets['criar pessoa']!,
        'tamanho de página': targets['tamanho de página']!,
        'próxima página': targets['próxima página']!,
        'tab de segmento': _segmentTab(domain.PersonDirectorySegment.all),
      }.entries) {
        final size = tester.getSize(target.value);
        expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '${target.key} $size');
        expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '${target.key} $size');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'people.edit: o card abre a pessoa certa por toque e no primeiro ponto de foco',
    (tester) async {
      await _useSurface(tester, 1440);
      final opened = <String>[];
      final repository = _ControlledRepository(seed: [_person('acc-edit', 'Aurora Aceite')]);
      await tester.pumpWidget(_app(repository, onEdit: opened.add));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('person-card-acc-edit'));
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(opened, ['acc-edit']);

      // Teclado: percorre os pontos de foco dentro do card e registra em qual
      // deles Enter abre a pessoa. O contrato é ativar no primeiro.
      final reached = await _tabUntil(tester, card);
      expect(reached, isTrue, reason: 'Tab não alcançou o card da pessoa');
      var stops = 0;
      int? activatedAtStop;
      while (_focusInside(card) && stops < 5) {
        stops += 1;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (opened.length > 1) {
          activatedAtStop = stops;
          break;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }

      expect(
        opened.skip(1).toList(),
        ['acc-edit'],
        reason: 'Enter dentro do card não abriu a pessoa (pontos de foco: $stops)',
      );
      expect(
        activatedAtStop,
        1,
        reason:
            'Enter só abriu a pessoa no ponto de foco $activatedAtStop; o card expõe ao '
            'menos $stops pontos de foco por Tab e o primeiro apenas realça.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // people.list: indicador de status
  // ---------------------------------------------------------------------------
  testWidgets('people.list: o indicador de status responde ao teclado como responde ao toque', (
    tester,
  ) async {
    await _useSurface(tester, 1440);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final opened = <String>[];
    final repository = _ControlledRepository(seed: [_person('acc-status', 'Aurora Aceite')]);
    await tester.pumpWidget(_app(repository, onEdit: opened.add));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const Key('person-status-acc-status'));
    expect(indicator, findsOneWidget);
    final collapsed = tester.getSize(indicator).width;

    // Anúncio: o status chega ao leitor de tela. O card de Pessoas é um
    // `CoeloAdminInteractiveCard`, que embrulha a superfície em
    // `ExcludeSemantics`, então o `Semantics(button: true)` declarado dentro do
    // indicador não vira nó próprio: quem anuncia é o nó do card.
    final node = tester.getSemantics(indicator);
    expect(
      node.label,
      contains('Status: Ativa'),
      reason: 'nenhum nó semântico sobre o indicador anuncia o status ($node)',
    );

    // Toque: expande, recolhe e não abre a pessoa. É a linha de base contra a
    // qual o teclado é medido.
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    final afterTap = tester.getSize(indicator).width;
    expect(
      afterTap,
      greaterThan(collapsed),
      reason: 'o toque não expandiu o indicador ($collapsed -> $afterTap)',
    );
    expect(opened, isEmpty, reason: 'tocar o status abriu a pessoa por baixo do indicador');
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    final afterSecondTap = tester.getSize(indicator).width;
    expect(
      afterSecondTap,
      collapsed,
      reason: 'o segundo toque não recolheu o indicador ($afterTap -> $afterSecondTap)',
    );

    // Teclado: o realce sozinho já expande e some ao sair do foco, então a
    // prova de ativação é a expansão sobreviver à saída do foco, como no toque.
    final reached = await _tabUntil(tester, _statusFocus('acc-status'));
    expect(reached, isTrue, reason: 'Tab não alcançou o indicador de status');
    await tester.pumpAndSettle();
    final focused = tester.getSize(indicator).width;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final afterEnter = tester.getSize(indicator).width;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final afterBlur = tester.getSize(indicator).width;

    final measured =
        'larguras: recolhido=$collapsed, após toque=$afterTap, após 2º toque=$afterSecondTap, '
        'com foco=$focused, após Enter=$afterEnter, após sair do foco=$afterBlur; '
        'Enter abriu a pessoa: ${opened.isNotEmpty}';
    expect(
      afterBlur,
      greaterThan(collapsed),
      reason: 'Enter no indicador focado não o ativou como o toque ativa ($measured)',
    );
    expect(
      opened,
      isEmpty,
      reason: 'o Enter dirigido ao indicador foi capturado pelo card por baixo ($measured)',
    );
  });

  testWidgets('people.list: o indicador de status oferece alvo de toque de 48', (tester) async {
    await _useSurface(tester, 1440);
    final repository = _ControlledRepository(seed: [_person('acc-status', 'Aurora Aceite')]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final hitArea = find
        .ancestor(
          of: find.byKey(const Key('person-status-acc-status')),
          matching: find.byType(GestureDetector),
        )
        .first;
    final size = tester.getSize(hitArea);
    const reference =
        'a baseline do Design System (CoeloAdminExpandableStatusIndicator) impõe '
        'BoxConstraints(minWidth: CoeloSize.touchMin, minHeight: CoeloSize.touchMin) '
        'na mesma composição';
    expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size; $reference');
    expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size; $reference');
  });

  // ---------------------------------------------------------------------------
  // people.list em 375 e 1440
  // ---------------------------------------------------------------------------
  for (final width in const [375.0, 1440.0]) {
    final label = width.toInt();

    testWidgets('people.list @$label: cards e tabela alternam sem exceção de layout', (
      tester,
    ) async {
      await _useSurface(tester, width);
      await tester.pumpWidget(_app(_ControlledRepository()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('people-card-grid')), findsOneWidget);
      expect(find.byKey(const Key('people-table')), findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('people-filter-toolbar'))).right,
        lessThanOrEqualTo(width),
      );

      await tester.ensureVisible(find.byKey(const Key('people-view-table')));
      await tester.tap(find.byKey(const Key('people-view-table')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('people-table')), findsOneWidget);
      expect(find.byKey(const Key('people-card-grid')), findsNothing);
      expect(_tableRows(), findsNWidgets(domain.PersonDirectoryQuery.tablePageSize));
      expect(
        tester.getRect(find.byKey(const Key('people-table-viewport'))).right,
        lessThanOrEqualTo(width),
      );

      await tester.ensureVisible(find.byKey(const Key('people-view-cards')));
      await tester.tap(find.byKey(const Key('people-view-cards')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('people-card-grid')), findsOneWidget);
      expect(find.byKey(const Key('people-table')), findsNothing);
    });

    testWidgets('people.list @$label: paginação avança preservando a busca com alvos de 48', (
      tester,
    ) async {
      await _useSurface(tester, width);
      final repository = _ControlledRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField, 'Coelo');
      await _settleSearch(tester);

      final compact = width < CoeloBreakpoints.medium.minWidth;
      final next = compact
          ? find.byKey(const Key('coelo-admin-pagination-next'))
          : _outlinedButtonLabelled('Próxima');
      final previous = compact
          ? find.byKey(const Key('coelo-admin-pagination-previous'))
          : _outlinedButtonLabelled('Anterior');
      expect(find.text('Página 1 de 2'), findsOneWidget);
      for (final target in [next, previous]) {
        final size = tester.getSize(target);
        expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
        expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
        expect(tester.getRect(target).right, lessThanOrEqualTo(width));
      }

      await tester.tap(next);
      await tester.pumpAndSettle();

      final query = repository.pageQueries.last;
      expect(query.page, 1);
      expect(query.search, 'Coelo', reason: 'a paginação perdeu a busca ativa');
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(_visibleCardIds(), await repository.expectedIds(query));
      expect(_personCards, findsNWidgets(5));
      expect(find.text('Ana Pessoa 1'), findsNothing);

      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(repository.pageQueries.last.page, 0);
      expect(repository.pageQueries.last.search, 'Coelo');
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('people.list @$label: falha e negado compõem sem overflow', (tester) async {
      await _useSurface(tester, width);
      final repository = _ControlledRepository()..pageFailure = () => StateError('indisponível');
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_failureTitle), findsOneWidget);
      await tester.ensureVisible(_retry);
      final retrySize = tester.getSize(_retry);
      expect(retrySize.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$retrySize');
      expect(retrySize.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$retrySize');
      expect(tester.getRect(_retry).right, lessThanOrEqualTo(width));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(_ControlledRepository()..unauthorized = true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_deniedTitle), findsOneWidget);
      expect(_personCards, findsNothing);
      expect(find.byKey(const Key('create-person-card')), findsNothing);
      expect(find.byKey(const Key('people-filter-toolbar')), findsNothing);
      expect(_retry, findsNothing);
    });
  }
}

// -----------------------------------------------------------------------------
// Cenários de falha
// -----------------------------------------------------------------------------

typedef _ErrorScenario = ({
  String label,
  Object Function()? pageFailure,
  Object Function()? optionsFailure,
  bool synchronous,
  String leakedDetail,
});

final _errorScenarios = <_ErrorScenario>[
  (
    label: 'TypeError de cast real na página',
    pageFailure: _realCastError,
    optionsFailure: null,
    synchronous: false,
    leakedDetail: 'is not a subtype',
  ),
  (
    label: 'RangeError de página malformada',
    pageFailure: () => RangeError.index(3, const <Object>[], 'items', 'detalhe de range'),
    optionsFailure: null,
    synchronous: false,
    leakedDetail: 'detalhe de range',
  ),
  (
    label: 'StateError síncrono antes do Future',
    pageFailure: () => StateError('detalhe síncrono'),
    optionsFailure: null,
    synchronous: true,
    leakedDetail: 'detalhe síncrono',
  ),
  (
    label: 'StateError nas opções de filtro',
    pageFailure: null,
    optionsFailure: () => StateError('detalhe de filtro'),
    synchronous: false,
    leakedDetail: 'detalhe de filtro',
  ),
];

Object _boxedInteger() => 42;

/// Produz o mesmo `TypeError` que um payload malformado geraria num cast.
Object _realCastError() {
  try {
    final _ = _boxedInteger() as String;
  } on TypeError catch (error) {
    return error;
  }
  return StateError('o cast inesperadamente funcionou');
}

// -----------------------------------------------------------------------------
// Fixtures, finders e ajudantes
// -----------------------------------------------------------------------------

Widget _app(domain.PersonDirectoryRepository repository, {ValueChanged<String>? onEdit}) =>
    MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      home: PersonDirectoryPage(
        repository: repository,
        logout: () async => const LogoutResult.success(),
        onCreate: () {},
        onEdit: onEdit ?? (_) {},
        onImport: () {},
        onExport: (_, _) {},
      ),
    );

Future<void> _useSurface(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Avança frames com duração fixa: nunca espera um loading que pode não
/// terminar, o que tornaria o próprio hang indistinguível de um timeout.
Future<void> _settleLoad(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A busca é debounced por 300 ms antes de reler o diretório.
Future<void> _settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

domain.PersonDirectoryItem _person(String id, String displayName) => domain.PersonDirectoryItem(
  id: id,
  displayName: displayName,
  type: domain.PersonType.adult,
  status: domain.PersonStatus.active,
  updatedAt: DateTime.utc(2026, 9, 8),
);

String _searchText(WidgetTester tester) =>
    tester.widget<CoeloSearchField>(_searchField).controller.text;

void _selectStatus(WidgetTester tester, Set<domain.PersonStatus> values) {
  tester
      .widget<CoeloAdminMultiSelectFilter<domain.PersonStatus>>(
        find.descendant(
          of: find.byKey(const Key('people-status-filter')),
          matching: find.byType(CoeloAdminMultiSelectFilter<domain.PersonStatus>),
        ),
      )
      .onChanged(values);
}

Finder _tableRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('people-table-row-');
});

/// Ids dos cards de pessoa hoje na grade, em ordem de renderização.
List<String> _visibleCardIds() => [
  for (final element in _personCards.evaluate())
    (element.widget.key! as ValueKey<String>).value.substring('person-card-'.length),
];

/// `OutlinedButton.icon` constrói uma subclasse privada, então `byType` não a
/// enxerga; o ancestral pelo rótulo é o caminho estável.
Finder _outlinedButtonLabelled(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    )
    .first;

/// A tab de segmento recebe foco no `InkWell` que embrulha o conteúdo chaveado.
Finder _segmentTab(domain.PersonDirectorySegment segment) => find
    .ancestor(
      of: find.byKey(ValueKey('superadmin-underline-tab-$segment')),
      matching: find.byType(InkWell),
    )
    .first;

/// O ponto de foco do indicador de status: a chave fica no filho animado, mas
/// quem entra no percurso por Tab é o `FocusableActionDetector` que o embrulha.
Finder _statusFocus(String personId) => find
    .ancestor(
      of: find.byKey(Key('person-status-$personId')),
      matching: find.byType(FocusableActionDetector),
    )
    .first;

/// Verdadeiro quando o foco primário está em [target] ou em um descendente.
bool _focusInside(Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) return false;
  final targets = target.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Verdadeiro quando o foco primário está dentro de [target] ou o envolve:
/// segmentos focam o botão que contém o ícone chaveado.
bool _focusTouches(Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || target.evaluate().isEmpty) return false;
  final focusedFinder = find.byElementPredicate((element) => identical(element, focused));
  return find
          .descendant(of: target, matching: focusedFinder, matchRoot: true)
          .evaluate()
          .isNotEmpty ||
      find.descendant(of: focusedFinder, matching: target, matchRoot: true).evaluate().isNotEmpty;
}

/// Pressiona Tab até o foco entrar em [target]; falso após [maxSteps].
Future<bool> _tabUntil(WidgetTester tester, Finder target, {int maxSteps = 160}) async {
  for (var step = 0; step < maxSteps; step++) {
    if (_focusInside(target)) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  }
  return _focusInside(target);
}

/// Embrulha o fake de `test/support` para registrar leituras e poder falhar com
/// `Error` real (não `Exception`) ou com o sinal de acesso negado.
final class _ControlledRepository implements domain.PersonDirectoryRepository {
  _ControlledRepository({List<domain.PersonDirectoryItem>? seed})
    : _delegate = FakePersonDirectoryRepository(seed: seed);

  final FakePersonDirectoryRepository _delegate;
  final pageQueries = <domain.PersonDirectoryQuery>[];

  /// Construídos a cada leitura para que cada falha seja um objeto distinto.
  Object Function()? pageFailure;
  Object Function()? optionsFailure;
  bool failSynchronously = false;
  bool unauthorized = false;

  List<domain.PersonDirectoryItem> get people => _delegate.people;

  /// O que o próprio fake devolve para a mesma consulta, para comparação.
  Future<List<String>> expectedIds(domain.PersonDirectoryQuery query) async {
    final page = await _delegate.fetchPage(query);
    return [for (final item in page.items) item.id];
  }

  @override
  Future<domain.PersonDirectoryPage> fetchPage(domain.PersonDirectoryQuery query) {
    pageQueries.add(query);
    if (unauthorized) throw const domain.PersonDirectoryUnauthorizedException();
    final failure = pageFailure;
    if (failure != null && failSynchronously) throw failure();
    return _readPage(query, failure);
  }

  Future<domain.PersonDirectoryPage> _readPage(
    domain.PersonDirectoryQuery query,
    Object Function()? failure,
  ) async {
    if (failure != null) throw failure();
    return _delegate.fetchPage(query);
  }

  @override
  Future<domain.PersonDirectoryFilterOptions> fetchFilterOptions() async {
    if (unauthorized) throw const domain.PersonDirectoryUnauthorizedException();
    final failure = optionsFailure;
    if (failure != null) throw failure();
    return _delegate.fetchFilterOptions();
  }

  @override
  Future<domain.PersonDirectoryItem> fetchDetail(String personId) =>
      _delegate.fetchDetail(personId);

  @override
  Future<domain.PersonDirectoryItem> createDraft(domain.PersonDraft draft) =>
      _delegate.createDraft(draft);

  @override
  Future<domain.PersonDirectoryItem> updatePerson(domain.PersonUpdate update) =>
      _delegate.updatePerson(update);
}
