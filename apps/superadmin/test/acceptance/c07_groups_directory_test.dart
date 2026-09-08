import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart' as domain;
import 'package:coelo_superadmin/features/groups/presentation/group_directory_page.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_directory_view_model.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// C07 - Turmas / Diretório: aceitação de fluxo, sem golden.
///
/// Ações do inventário: groups.list, groups.create, groups.edit,
/// groups.members e groups.location. Cobre apenas o que os testes focais em
/// `test/features/groups/` ainda não provam: carga que lança `Error` de
/// verdade (o hunk `on Object` de fdf0972d), retry único preservando busca,
/// status e página, ausência de dado residual em falha e em negado depois de
/// um sucesso, vazio distinto de "sem resultados", paginação real com o filtro
/// preservado, edição pela linha da tabela, alcance por Tab, ativação por
/// Enter no primeiro ponto de foco e composição em 375/1440.
///
/// `groups.members` e `groups.location` aparecem no diretório apenas como
/// leitura (contagens de alunos/professores e as linhas Instituição/Unidade),
/// já cobertas por `group_directory_page_test.dart`; a edição delas vive no
/// formulário, coberto por `group_form_page_test.dart`.
const _failureTitle = 'Não foi possível carregar as turmas';
const _emptyTitle = 'Nenhuma turma cadastrada';
const _noResultsTitle = 'Nenhuma turma encontrada';
const _deniedTitle = 'Acesso não autorizado';
const _deniedMessage = 'Você não tem permissão para ver as turmas.';
const _retryLabel = 'Tentar novamente';
const _active = {domain.GroupStatus.active};

void main() {
  // ---------------------------------------------------------------------------
  // groups.list: falha honesta em vez de spinner preso
  // ---------------------------------------------------------------------------
  for (final scenario in _errorScenarios) {
    testWidgets('groups.list: carga que lança ${scenario.label} sai do loading, mostra falha com '
        'retry e não se disfarça de vazio', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ScriptedGroupDirectoryRepository()
        ..pageFailure = scenario.pageFailure
        ..optionsFailure = scenario.optionsFailure
        ..failSynchronously = scenario.synchronous;

      await tester.pumpWidget(_app(repository));
      await _settleLoad(tester);

      // O hunk `on Object`: qualquer throw, inclusive `Error`, precisa sair
      // do loading. Spinner preso sem mensagem e sem retry é o modo de falha
      // proibido, e `pumpAndSettle` mascararia isso com um timeout.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: '${scenario.label}: o diretório ficou preso em loading',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(_failureTitle), findsOneWidget);
      expect(find.text(_retryLabel), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_retry).enabled, isTrue);
      expect(find.textContaining(scenario.leakedDetail), findsNothing);

      // Falha não é vazio, não é "sem resultados" e não deixa dado parcial.
      expect(find.text(_emptyTitle), findsNothing);
      expect(find.text(_noResultsTitle), findsNothing);
      expect(find.text(_deniedTitle), findsNothing);
      expect(_visibleCardIds(tester), isEmpty);
      expect(find.byKey(const Key('group-directory-pagination-footer')), findsNothing);
      // Autorizado a criar continua podendo criar mesmo com a leitura falha.
      expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('groups.list: falha depois de um sucesso apaga os dados anteriores e mantém '
      'barra, abas e Criar', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final firstId = _visibleCardIds(tester).first;
    expect(_visibleCardIds(tester), hasLength(11));

    repository.pageFailure = () => StateError('detalhe interno da página');
    await tester.tap(find.text('Ativos'));
    await _settleLoad(tester);

    expect(find.text(_failureTitle), findsOneWidget);
    expect(find.text('detalhe interno da página'), findsNothing);
    expect(_visibleCardIds(tester), isEmpty);
    expect(find.byKey(Key('group-card-$firstId')), findsNothing);
    expect(find.text(_emptyTitle), findsNothing);
    expect(find.text(_noResultsTitle), findsNothing);
    expect(find.byKey(const Key('group-directory-pagination-footer')), findsNothing);
    expect(find.byKey(const Key('group-filter-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('group-status-tabs')), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.list: o retry relê exatamente uma vez e preserva busca, status e página', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'Turma');
    await _settleSearch(tester);
    await tester.tap(_nextPage);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 1);

    // A releitura da terceira página falha: a falha precisa carregar a consulta
    // inteira, não voltar para a primeira página sem filtro.
    repository.pageFailure = () => StateError('página indisponível');
    await tester.tap(_nextPage);
    await _settleLoad(tester);
    expect(find.text(_failureTitle), findsOneWidget);
    expect(repository.lastQuery.page, 2);
    expect(repository.lastQuery.search, 'Turma');
    expect(repository.lastQuery.statuses, _active);

    final pageReadsBefore = repository.pageQueries.length;
    final optionReadsBefore = repository.optionReads;
    repository.pageFailure = null;
    await tester.tap(_retry);
    await tester.pumpAndSettle();

    expect(repository.pageQueries, hasLength(pageReadsBefore + 1));
    expect(repository.optionReads, optionReadsBefore + 1);
    expect(repository.lastQuery.page, 2);
    expect(repository.lastQuery.search, 'Turma');
    expect(repository.lastQuery.statuses, _active);
    final expected = await repository.expectedIds(page: 2, search: 'Turma', statuses: _active);
    expect(expected, isNotEmpty);
    expect(_visibleCardIds(tester), expected);
    expect(find.text(_failureTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'groups.list: o view model conclui uma carga que lança Error e se recupera no retry',
    () async {
      final repository = _ScriptedGroupDirectoryRepository()..pageFailure = _realCastError;
      final viewModel = GroupDirectoryViewModel(repository);
      addTearDown(viewModel.dispose);

      // Um hang jamais completaria este future; o timeout transforma o hang em
      // falha de teste em vez de espera infinita.
      await viewModel.load().timeout(const Duration(seconds: 2));
      expect(viewModel.state, GroupDirectoryLoadState.failure);
      expect(viewModel.isLoading, isFalse);

      repository.pageFailure = null;
      repository.optionsFailure = () => RangeError.index(3, const <Object>[], 'options');
      repository.failSynchronously = true;
      await viewModel.retry().timeout(const Duration(seconds: 2));
      expect(viewModel.state, GroupDirectoryLoadState.failure);

      repository
        ..optionsFailure = null
        ..failSynchronously = false;
      await viewModel.retry().timeout(const Duration(seconds: 2));
      expect(viewModel.state, GroupDirectoryLoadState.success);
      expect(viewModel.page.items, hasLength(11));
    },
  );

  // ---------------------------------------------------------------------------
  // groups.list: acesso negado
  // ---------------------------------------------------------------------------
  testWidgets('groups.list: negado depois de um sucesso apaga os dados e não oferece criar, '
      'retry nem releitura em laço', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final firstId = _visibleCardIds(tester).first;

    repository.pageFailure = () => const domain.GroupDirectoryUnauthorizedException();
    await tester.tap(find.text('Ativos'));
    await _settleLoad(tester);

    expect(find.text(_deniedTitle), findsOneWidget);
    expect(find.text(_deniedMessage), findsOneWidget);
    expect(find.text(_failureTitle), findsNothing);
    expect(find.text(_retryLabel), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_visibleCardIds(tester), isEmpty);
    expect(find.byKey(Key('group-card-$firstId')), findsNothing);
    // Permissão de criar foi dada à página, mas um diretório negado não a oferece.
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.byKey(const Key('group-create-banner')), findsNothing);
    expect(find.text('Criar turma'), findsNothing);
    expect(find.byKey(const Key('group-filter-toolbar')), findsNothing);
    expect(find.byKey(const Key('group-status-tabs')), findsNothing);
    expect(find.byKey(const Key('group-directory-pagination-footer')), findsNothing);

    // Nada de marteladas num backend que já disse não.
    final readsAfterDenial = repository.pageQueries.length;
    await tester.pump(const Duration(seconds: 3));
    expect(repository.pageQueries, hasLength(readsAfterDenial));
    expect(find.text(_deniedTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // groups.list / groups.create: vazio e "sem resultados" são estados distintos
  // ---------------------------------------------------------------------------
  testWidgets('groups.list: o diretório vazio convida a criar e não fala em filtros', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));

    await tester.pumpWidget(_app(_ScriptedGroupDirectoryRepository(records: const [])));
    await tester.pumpAndSettle();

    expect(find.text(_emptyTitle), findsOneWidget);
    expect(find.text('Crie a primeira turma da plataforma.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Criar turma'), findsOneWidget);
    expect(find.text(_noResultsTitle), findsNothing);
    expect(find.text(_failureTitle), findsNothing);
    expect(find.text(_retryLabel), findsNothing);
    expect(find.text('Limpar filtros'), findsNothing);
    expect(find.byKey(const Key('group-directory-pagination-footer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.create: sem permissão de criar, o vazio não oferece ação nenhuma', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));

    await tester.pumpWidget(
      _app(_ScriptedGroupDirectoryRepository(records: const []), allowCreate: false),
    );
    await tester.pumpAndSettle();

    expect(find.text(_emptyTitle), findsOneWidget);
    expect(find.text('Criar turma'), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.byKey(const Key('group-create-banner')), findsNothing);
    // Os filtros da barra também são OutlinedButton: o alvo aqui é o painel.
    expect(
      find.descendant(of: find.byType(CoeloStatePanel), matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.list: sem resultados fala em filtros, não em falha, e limpar devolve a '
      'consulta sem filtro', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'zzz-sem-correspondencia');
    await _settleSearch(tester);

    expect(find.text(_noResultsTitle), findsOneWidget);
    expect(find.text('Ajuste ou limpe os filtros.'), findsOneWidget);
    expect(find.text(_emptyTitle), findsNothing);
    expect(find.text(_failureTitle), findsNothing);
    expect(find.text(_retryLabel), findsNothing);
    expect(_visibleCardIds(tester), isEmpty);
    // Uma ação na barra e outra no painel de estado.
    expect(find.text('Limpar filtros'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Limpar filtros'));
    await tester.pumpAndSettle();

    expect(repository.lastQuery.search, '');
    expect(repository.lastQuery.hasActiveFilters, isFalse);
    expect(find.text(_noResultsTitle), findsNothing);
    expect(find.text('Limpar filtros'), findsNothing);
    expect(_visibleCardIds(tester), hasLength(11));
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // groups.list: paginação com o filtro preservado
  // ---------------------------------------------------------------------------
  testWidgets('groups.list: próxima, anterior e página numerada leem a página certa com o status '
      'preservado e com alvos de 48', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();

    final totalPages = (repository.activeCount / 11).ceil();
    expect(totalPages, greaterThanOrEqualTo(3), reason: 'a fixture precisa de três páginas');
    expect(find.text('Página 1 de $totalPages'), findsOneWidget);
    expect(repository.lastQuery.statuses, _active);
    expect(tester.widget<OutlinedButton>(_previousPage).enabled, isFalse);
    for (final target in [_nextPage, _previousPage, _pageButton(2)]) {
      final size = tester.getSize(target);
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
    }
    final firstPageIds = _visibleCardIds(tester);
    expect(firstPageIds, await repository.expectedIds(statuses: _active));

    await tester.tap(_nextPage);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 1);
    expect(repository.lastQuery.statuses, _active);
    expect(find.text('Página 2 de $totalPages'), findsOneWidget);
    final secondPageIds = _visibleCardIds(tester);
    expect(secondPageIds, await repository.expectedIds(page: 1, statuses: _active));
    expect(secondPageIds, isNot(firstPageIds));

    await tester.tap(_pageButton(3));
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 2);
    expect(repository.lastQuery.statuses, _active);
    expect(find.text('Página 3 de $totalPages'), findsOneWidget);
    expect(_visibleCardIds(tester), await repository.expectedIds(page: 2, statuses: _active));

    await tester.tap(_previousPage);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 1);
    expect(repository.lastQuery.statuses, _active);
    expect(_visibleCardIds(tester), secondPageIds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.list: trocar o tamanho de página relê da primeira com o status preservado', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();
    await tester.tap(_nextPage);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 1);
    final readsBefore = repository.pageQueries.length;

    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size-20')));
    await tester.pumpAndSettle();

    expect(repository.pageQueries, hasLength(readsBefore + 1));
    expect(repository.lastQuery.pageSize, 20);
    expect(repository.lastQuery.page, 0);
    expect(repository.lastQuery.statuses, _active);
    final ids = _visibleCardIds(tester);
    expect(ids, await repository.expectedIds(pageSize: 20, statuses: _active));
    expect(ids, hasLength(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.list @375: a paginação compacta pagina com alvos de 48 dentro da tela', (
    tester,
  ) async {
    await _useSurface(tester, const Size(375, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();

    final totalPages = (repository.activeCount / 11).ceil();
    final next = find.byKey(const Key('coelo-admin-pagination-next'));
    final previous = find.byKey(const Key('coelo-admin-pagination-previous'));
    expect(find.text('Página 1 de $totalPages'), findsOneWidget);
    for (final target in [next, previous]) {
      final size = tester.getSize(target);
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(tester.getRect(target).right, lessThanOrEqualTo(375));
    }
    expect(tester.widget<IconButton>(previous).onPressed, isNull);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 1);
    expect(repository.lastQuery.statuses, _active);
    expect(find.text('Página 2 de $totalPages'), findsOneWidget);
    expect(_visibleCardIds(tester), await repository.expectedIds(page: 1, statuses: _active));

    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(repository.lastQuery.page, 0);
    expect(find.text('Página 1 de $totalPages'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // groups.edit e groups.create: navegação a partir do diretório
  // ---------------------------------------------------------------------------
  testWidgets('groups.edit: a linha da tabela abre a edição com o id da turma', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();
    final edited = <String>[];

    await tester.pumpWidget(_app(repository, onEdit: edited.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();

    final rowIds = await repository.expectedIds(pageSize: 8);
    expect(rowIds, hasLength(8));
    expect(_tableRowIds(), rowIds);

    await tester.tap(find.byKey(Key('group-table-row-${rowIds.first}')));
    await tester.pumpAndSettle();

    expect(edited, [rowIds.first]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups.list: voltar para o diretório relê o repositório em vez de servir cache', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.pageQueries, hasLength(1));
    final firstLoadIds = _visibleCardIds(tester);

    // Sai para o formulário e volta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(repository.pageQueries, hasLength(2));
    expect(_visibleCardIds(tester), firstLoadIds);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Teclado e foco
  // ---------------------------------------------------------------------------
  testWidgets(
    'groups.list: Tab alcança busca, filtros, abas, o toggle Cards/Tabela, a paginação e Criar',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));

      await tester.pumpWidget(_app(_ScriptedGroupDirectoryRepository()));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'busca': _searchField(),
        'filtro de instituições': find.byKey(const Key('group-institution-filter')),
        'filtro de unidades': find.byKey(const Key('group-unit-filter')),
        'filtro de tipo': find.byKey(const Key('group-type-filter')),
        'segmento Cards': find.byKey(const Key('group-view-cards')),
        'segmento Tabela': find.byKey(const Key('group-view-table')),
        'abas de status': find.byKey(const Key('group-status-tabs')),
        'card Criar': find.byType(CoeloAdminCreateAction),
        'tamanho de página': find.byKey(const Key('coelo-admin-pagination-page-size')),
        'próxima página': _nextPage,
      };
      final reached = <String>{};

      for (var step = 0; step < 260 && reached.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (!reached.contains(entry.key) && _focusTouches(entry.value)) reached.add(entry.key);
        }
        // Se algum controle abrir um flyout ao receber foco, Escape o fecha e
        // devolve o foco para que o percurso continue.
        if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      expect(
        reached,
        containsAll(targets.keys),
        reason: 'não alcançados por Tab: ${targets.keys.toSet().difference(reached)}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('groups.edit: o card de turma abre a edição no primeiro ponto de foco', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));
    final edited = <String>[];

    await tester.pumpWidget(_app(_ScriptedGroupDirectoryRepository(), onEdit: edited.add));
    await tester.pumpAndSettle();
    final firstId = _visibleCardIds(tester).first;
    final card = find.byKey(Key('group-card-$firstId'));

    // Linha de base por toque, contra a qual o teclado é medido.
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(edited, [firstId]);

    // Percorre os pontos de foco dentro do card e registra em qual deles Enter
    // abre a edição. O contrato é que o primeiro ponto de foco já ative.
    expect(await _tabUntil(tester, card), isTrue, reason: 'Tab não alcançou o card da turma');
    var stopsInsideCard = 0;
    int? activatedAtStop;
    while (_focusWithin(card) && stopsInsideCard < 5) {
      stopsInsideCard += 1;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      if (edited.length > 1) {
        activatedAtStop = stopsInsideCard;
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    expect(
      edited.skip(1).toList(),
      [firstId],
      reason: 'Enter dentro do card não abriu a edição (pontos de foco: $stopsInsideCard)',
    );
    expect(
      activatedAtStop,
      1,
      reason:
          'Enter só abriu a edição no ponto de foco $activatedAtStop do card; o card expõe '
          'ao menos $stopsInsideCard pontos de foco por Tab e o primeiro apenas realça.',
    );
  });

  testWidgets('groups.create: o banner Criar da tabela aciona no primeiro ponto de foco', (
    tester,
  ) async {
    await _useSurface(tester, const Size(1440, 900));
    var creates = 0;

    await tester.pumpWidget(
      _app(_ScriptedGroupDirectoryRepository(), onCreate: () => creates += 1),
    );
    await tester.pumpAndSettle();

    // O card Criar vive na visão de cards; o banner Criar, na de tabela.
    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    final banner = find.byKey(const Key('group-create-banner'));
    expect(banner, findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);

    expect(await _tabUntil(tester, banner), isTrue, reason: 'Tab não alcançou o banner Criar');
    var stopsInsideBanner = 0;
    int? activatedAtStop;
    while (_focusWithin(banner) && stopsInsideBanner < 5) {
      stopsInsideBanner += 1;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      if (creates > 0) {
        activatedAtStop = stopsInsideBanner;
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    expect(
      creates,
      1,
      reason: 'Enter dentro do banner não acionou Criar (pontos de foco: $stopsInsideBanner)',
    );
    expect(
      activatedAtStop,
      1,
      reason:
          'Enter só acionou Criar no ponto de foco $activatedAtStop do banner; o banner expõe '
          'ao menos $stopsInsideBanner pontos de foco por Tab e o primeiro apenas realça sem '
          'ativar (o FocusableActionDetector sem `actions:` que envolve o InkWell).',
    );
  });

  testWidgets('groups.list: o retry é acionado por teclado e relê uma única vez', (tester) async {
    await _useSurface(tester, const Size(1440, 900));
    final repository = _ScriptedGroupDirectoryRepository()
      ..pageFailure = () => StateError('indisponível');

    await tester.pumpWidget(_app(repository));
    await _settleLoad(tester);
    expect(find.text(_failureTitle), findsOneWidget);

    final readsBefore = repository.pageQueries.length;
    expect(await _tabUntil(tester, _retry), isTrue, reason: 'Tab não alcançou o retry');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settleLoad(tester);

    expect(repository.pageQueries, hasLength(readsBefore + 1));
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // 375 e 1440
  // ---------------------------------------------------------------------------
  for (final width in const [375.0, 1440.0]) {
    final label = width.toInt();

    testWidgets('groups.list @$label: cards e tabela alternam o conteúdo sem overflow', (
      tester,
    ) async {
      await _useSurface(tester, Size(width, 900));
      final repository = _ScriptedGroupDirectoryRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_visibleCardIds(tester), hasLength(11));
      expect(_tableRowIds(), isEmpty);
      expect(
        tester.getRect(find.byKey(const Key('group-filter-toolbar'))).right,
        lessThanOrEqualTo(width),
      );

      await tester.ensureVisible(find.byKey(const Key('group-view-table')));
      await tester.tap(find.byKey(const Key('group-view-table')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('group-directory-table')), findsOneWidget);
      expect(_visibleCardIds(tester), isEmpty);
      expect(_tableRowIds(), hasLength(8));
      expect(
        tester.getRect(find.byKey(const Key('group-directory-table'))).right,
        lessThanOrEqualTo(width),
      );
      expect(find.byKey(const Key('group-directory-pagination-footer')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('group-view-cards')));
      await tester.tap(find.byKey(const Key('group-view-cards')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_visibleCardIds(tester), hasLength(11));
      expect(find.byKey(const Key('group-directory-table')), findsNothing);
      expect(repository.pageQueries.map((query) => query.pageSize), [11, 8, 11]);
    });

    testWidgets('groups.list @$label: a falha compõe sem overflow com retry de 48', (tester) async {
      await _useSurface(tester, Size(width, 900));

      await tester.pumpWidget(
        _app(_ScriptedGroupDirectoryRepository()..pageFailure = () => StateError('indisponível')),
      );
      await _settleLoad(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_failureTitle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.ensureVisible(_retry);
      final size = tester.getSize(_retry);
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(tester.getRect(_retry).right, lessThanOrEqualTo(width));
    });
  }
}

// -----------------------------------------------------------------------------
// Cenários de erro
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
    label: 'StateError assíncrono na página',
    pageFailure: () => StateError('detalhe de estado'),
    optionsFailure: null,
    synchronous: false,
    leakedDetail: 'detalhe de estado',
  ),
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
    label: 'RangeError síncrono nas opções de filtro',
    pageFailure: null,
    optionsFailure: () => RangeError.index(3, const <Object>[], 'options', 'detalhe de opções'),
    synchronous: true,
    leakedDetail: 'detalhe de opções',
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
// Fixtures e finders
// -----------------------------------------------------------------------------

Widget _app(
  domain.GroupDirectoryRepository repository, {
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
  bool allowCreate = true,
}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: GroupDirectoryPage(
    repository: repository,
    logout: () async => const LogoutResult.success(),
    onCreate: allowCreate ? (onCreate ?? () {}) : null,
    onEdit: onEdit ?? (_) {},
  ),
);

Future<void> _useSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
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

/// A busca é adiada por 300 ms antes de reler o diretório.
Future<void> _settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Finder _searchField() => find.byWidgetPredicate(
  (widget) => widget is CoeloSearchField && widget.semanticLabel == 'Buscar turma por nome',
);

Finder _searchInput() => find.descendant(of: _searchField(), matching: find.byType(TextField));

Finder get _retry => find.widgetWithText(OutlinedButton, _retryLabel);

/// `OutlinedButton.icon` constrói uma subclasse privada, então `byType` não a vê.
Finder _outlinedButtonLabelled(String label) => find
    .ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is OutlinedButton))
    .first;

Finder get _nextPage => _outlinedButtonLabelled('Próxima');

Finder get _previousPage => _outlinedButtonLabelled('Anterior');

Finder _pageButton(int page) => find.byKey(Key('coelo-admin-pagination-page-$page'));

/// Ids dos cards de turma presentes na grade, em ordem de renderização.
List<String> _visibleCardIds(WidgetTester tester) => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('group-card-demo-');
  }).evaluate())
    (element.widget.key! as ValueKey<String>).value.substring('group-card-'.length),
];

/// Ids das linhas da tabela, em ordem de renderização.
List<String> _tableRowIds() => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('group-table-row-demo-');
  }).evaluate())
    (element.widget.key! as ValueKey<String>).value.substring('group-table-row-'.length),
];

/// Verdadeiro quando o foco primário está em [finder] ou em um descendente dele.
bool _focusWithin(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) return false;
  final targets = finder.evaluate().toSet();
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

/// Verdadeiro quando o foco primário está dentro de [finder] ou o envolve: os
/// segmentos do toggle focam o botão que contém o ícone com a chave.
bool _focusTouches(Finder finder) {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null || finder.evaluate().isEmpty) return false;
  if (_focusWithin(finder)) return true;
  final focused = find.byElementPredicate((element) => identical(element, focusedContext));
  return find.descendant(of: focused, matching: finder, matchRoot: true).evaluate().isNotEmpty;
}

/// Pressiona Tab até o foco entrar em [finder]; falso após [maxSteps].
Future<bool> _tabUntil(WidgetTester tester, Finder finder, {int maxSteps = 160}) async {
  for (var step = 0; step < maxSteps; step++) {
    if (_focusWithin(finder)) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  }
  return _focusWithin(finder);
}

/// Envolve o fake local para registrar as leituras e poder falhar com `Error`
/// de verdade (não `Exception`) ou com o sinal de acesso negado.
final class _ScriptedGroupDirectoryRepository implements domain.GroupDirectoryRepository {
  _ScriptedGroupDirectoryRepository({List<domain.GroupRecord>? records})
    : _delegate = FakeGroupDirectoryRepository(
        FakeInstitutionDirectoryRepository(),
        records: records,
      );

  final FakeGroupDirectoryRepository _delegate;
  final pageQueries = <domain.GroupDirectoryQuery>[];
  int optionReads = 0;

  /// Construída a cada leitura, para que cada falha seja um objeto distinto.
  Object Function()? pageFailure;
  Object Function()? optionsFailure;

  /// Lança antes de devolver o Future, como um parser malformado faria.
  bool failSynchronously = false;

  domain.GroupDirectoryQuery get lastQuery => pageQueries.last;

  List<domain.GroupRecord> get records => _delegate.records;

  int get activeCount =>
      _delegate.records.where((record) => record.status == domain.GroupStatus.active).length;

  /// O que o próprio fake devolve para a mesma consulta, para comparação.
  Future<List<String>> expectedIds({
    int page = 0,
    int pageSize = domain.GroupDirectoryQuery.defaultPageSize,
    String search = '',
    Set<domain.GroupStatus> statuses = const {},
  }) async {
    final result = await _delegate.fetchPage(
      domain.GroupDirectoryQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        statuses: statuses,
      ),
    );
    return [for (final item in result.items) item.id];
  }

  @override
  Future<domain.GroupDirectoryPage> fetchPage(domain.GroupDirectoryQuery query) {
    pageQueries.add(query);
    final failure = pageFailure;
    if (failure != null && failSynchronously) throw failure();
    return _readPage(query, failure);
  }

  Future<domain.GroupDirectoryPage> _readPage(
    domain.GroupDirectoryQuery query,
    Object Function()? failure,
  ) async {
    if (failure != null) throw failure();
    return _delegate.fetchPage(query);
  }

  @override
  Future<domain.GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) {
    optionReads += 1;
    final failure = optionsFailure;
    if (failure != null && failSynchronously) throw failure();
    return _readOptions(institutionIds, failure);
  }

  Future<domain.GroupDirectoryFilterOptions> _readOptions(
    Set<String> institutionIds,
    Object Function()? failure,
  ) async {
    if (failure != null) throw failure();
    return _delegate.fetchFilterOptions(institutionIds: institutionIds);
  }

  @override
  String createId(String institutionId, String unitId, String name) =>
      _delegate.createId(institutionId, unitId, name);

  @override
  Future<domain.GroupRecord?> findById(String id) => _delegate.findById(id);

  @override
  Future<void> upsert(domain.GroupRecord record) => _delegate.upsert(record);

  @override
  Future<domain.GroupDirectorySaveResult> saveComposition(
    domain.GroupDirectorySaveRequest request,
  ) => _delegate.saveComposition(request);

  @override
  Future<domain.GroupDirectoryFormContext> fetchFormContext({String? institutionId}) =>
      _delegate.fetchFormContext(institutionId: institutionId);

  @override
  Future<domain.GroupDirectoryExportResult> requestExport(domain.GroupDirectoryQuery query) =>
      _delegate.requestExport(query);
}
