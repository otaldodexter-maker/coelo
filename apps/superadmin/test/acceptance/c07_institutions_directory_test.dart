import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart'
    as domain;
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_directory_view_model.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_status_presentation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// C07 - Instituições / Diretório: aceitação de fluxo, sem golden.
///
/// Ações do inventário: institutions.list, institutions.filter,
/// institutions.error, institutions.access-denied, institutions.reload e
/// institutions.detail. Cobre apenas lacunas dos testes focais em
/// `test/features/institutions/`: falha que lança `Error` (não `Exception`),
/// retry único preservando busca/status/página, ausência de dado residual em
/// falha e em negado após sucesso, "sem resultados" com limpeza, recarga após
/// sucesso, foco/teclado, alvos de toque e composição em 375/1440.
const _failureMessage = InstitutionDirectoryViewModel.genericErrorMessage;
const _unauthorizedMessage = InstitutionDirectoryViewModel.unauthorizedMessage;
const _emptyMessage = 'Ainda não há instituições cadastradas.';
const _noResultsMessage = 'Nenhuma instituição encontrada com estes filtros.';
const _retryLabel = 'Tentar novamente';

void main() {
  // ---------------------------------------------------------------------------
  // institutions.error
  // ---------------------------------------------------------------------------
  for (final scenario in _errorScenarios) {
    testWidgets(
      'institutions.error: carga que lança ${scenario.label} sai do loading, '
      'mostra falha segura com retry e não se disfarça de vazio',
      (tester) async {
        await _useSurface(tester, const Size(1440, 900));
        final repository = _ControlledRepository(items: _pagedInstitutions())
          ..pageFailure = scenario.pageFailure
          ..filterOptionsFailure = scenario.filterOptionsFailure
          ..failSynchronously = scenario.synchronous;

        await tester.pumpWidget(_app(repository));
        await _settleLoad(tester);

        // A correção de fdf0972d: qualquer throw deixa o loading. Um spinner
        // preso sem mensagem e sem retry é o modo de falha proibido.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: '${scenario.label}: o diretório ficou preso em loading',
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text(_failureMessage), findsOneWidget);
        expect(find.textContaining(scenario.leakedDetail), findsNothing);
        final retry = _retryButton();
        expect(retry, findsOneWidget);
        expect(tester.widget<OutlinedButton>(retry).enabled, isTrue);

        // Falha não é vazio, nem "sem resultados", nem dado parcial.
        expect(find.text(_emptyMessage), findsNothing);
        expect(find.text(_noResultsMessage), findsNothing);
        expect(_institutionCards(), findsNothing);
        expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
        // Criar continua disponível quando autorizado (institutions.error).
        expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'institutions.error: falha após sucesso remove os dados anteriores da tela '
    'e mantém toolbar e Criar para o usuário autorizado',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(_institutionCards(), findsNWidgets(5));
      expect(find.text('Instituto Aurora'), findsWidgets);

      repository.pageFailure = () => StateError('page cast failed');
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();

      expect(find.text(_failureMessage), findsOneWidget);
      expect(_retryButton(), findsOneWidget);
      expect(_institutionCards(), findsNothing);
      expect(find.text('Instituto Aurora'), findsNothing);
      expect(find.text(_emptyMessage), findsNothing);
      expect(find.text(_noResultsMessage), findsNothing);
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
      expect(find.byKey(const Key('institution-filter-toolbar')), findsOneWidget);
      expect(find.byKey(const Key('institution-status-tabs')), findsOneWidget);
      expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'institutions.error: retry tem alvo de toque de 48 e é acionado por teclado',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository()
        ..pageFailure = () => StateError('unavailable');

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final retry = _retryButton();
      final size = tester.getSize(retry);
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: 'altura $size');
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: 'largura $size');

      final readsBefore = repository.pageQueries.length;
      repository.pageFailure = null;
      final reached = await _tabUntil(tester, retry);
      expect(reached, isTrue, reason: 'Tab não alcançou "$_retryLabel"');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBefore + 1);
      expect(find.text(_failureMessage), findsNothing);
      expect(_institutionCards(), findsNWidgets(5));
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.reload
  // ---------------------------------------------------------------------------
  testWidgets(
    'institutions.reload: retry lê exatamente uma vez e recupera preservando '
    'busca, status e página ativos no momento da falha',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository(items: _pagedInstitutions());

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField(), 'Instituição');
      await _settleSearch(tester);
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.text('Instituição 01'), findsOneWidget);

      // A ida para a página 2 falha: o estado de falha carrega a consulta
      // que estava ativa (busca + status + página 2).
      repository.pageFailure = () => StateError('page 2 unavailable');
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(find.text(_failureMessage), findsOneWidget);
      expect(_institutionCards(), findsNothing);
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
      final failedQuery = repository.pageQueries.last;
      expect(failedQuery.search, 'Instituição');
      expect(failedQuery.statuses, {InstitutionStatus.active});
      expect(failedQuery.page, 1);
      final readsBeforeRetry = repository.pageQueries.length;

      repository.pageFailure = null;
      await tester.tap(_retryButton());
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBeforeRetry + 1, reason: 'retry deve ler uma vez');
      expect(repository.pageQueries.last, failedQuery, reason: 'retry deve reler a mesma consulta');
      expect(find.text(_failureMessage), findsNothing);
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(find.text('Instituição 12'), findsOneWidget);
      expect(find.text('Instituição 13'), findsOneWidget);
      expect(find.text('Instituição 01'), findsNothing);
      expect(find.text('Instituição Inativa A'), findsNothing);
      expect(_institutionCards(), findsNWidgets(2));
      expect(tester.widget<TextField>(_searchField()).controller?.text, 'Instituição');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'institutions.reload: enquanto o retry está em voo a ação some e só há uma leitura',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository()..pageFailure = () => StateError('unavailable');
      addTearDown(repository.releaseReads);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(_retryButton(), findsOneWidget);
      final readsBefore = repository.pageQueries.length;

      repository
        ..pageFailure = null
        ..holdNextReads();
      await tester.tap(_retryButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_retryButton(), findsNothing, reason: 'sem retry duplicável durante a leitura');
      expect(find.text(_failureMessage), findsNothing);
      expect(repository.pageQueries.length, readsBefore + 1);

      repository.releaseReads();
      await tester.pumpAndSettle();
      expect(repository.pageQueries.length, readsBefore + 1);
      expect(_institutionCards(), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'institutions.reload: recarregar após sucesso refaz exatamente uma leitura '
    'com a consulta ativa e sem duplicar itens',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository(items: _pagedInstitutions());

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField(), 'Instituição');
      await _settleSearch(tester);
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();
      final readsBefore = repository.pageQueries.length;

      // Trocar para tabela é a recarga disponível após sucesso: a página é
      // relida com o tamanho da tabela, mantendo busca e status.
      await tester.tap(find.byKey(const Key('institution-view-table')));
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBefore + 1);
      final tableQuery = repository.pageQueries.last;
      expect(tableQuery.search, 'Instituição');
      expect(tableQuery.statuses, {InstitutionStatus.active});
      expect(tableQuery.pageSize, 8);
      expect(tableQuery.page, 0);
      expect(find.byKey(const Key('institution-directory-table')), findsOneWidget);
      expect(_institutionTableRows(), findsNWidgets(8));
      for (var index = 1; index <= 8; index++) {
        expect(find.byKey(Key('institution-table-row-acc-active-$index')), findsOneWidget);
      }
      expect(find.byKey(const Key('institution-table-row-acc-inactive-a')), findsNothing);

      await tester.tap(find.byKey(const Key('institution-view-cards')));
      await tester.pumpAndSettle();
      expect(repository.pageQueries.length, readsBefore + 2);
      expect(repository.pageQueries.last.pageSize, 11);
      expect(repository.pageQueries.last.search, 'Instituição');
      expect(repository.pageQueries.last.statuses, {InstitutionStatus.active});
      expect(_institutionCards(), findsNWidgets(11));
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.access-denied
  // ---------------------------------------------------------------------------
  testWidgets(
    'institutions.access-denied: negado após sucesso remove dados, controles, '
    'Criar e retry sem deixar dado residual',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(_institutionCards(), findsNWidgets(5));

      repository.pageFailure = () => const InstitutionDirectoryUnauthorizedException();
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();

      expect(find.text(_unauthorizedMessage), findsOneWidget);
      expect(_institutionCards(), findsNothing);
      expect(find.text('Instituto Aurora'), findsNothing);
      expect(find.byKey(const Key('institution-filter-toolbar')), findsNothing);
      expect(find.byKey(const Key('institution-status-tabs')), findsNothing);
      expect(find.byKey(const Key('institution-display-toggle')), findsNothing);
      expect(find.byKey(const Key('create-institution-card')), findsNothing);
      expect(find.byKey(const Key('create-institution-banner')), findsNothing);
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
      expect(_retryButton(), findsNothing);
      expect(find.text(_failureMessage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.filter
  // ---------------------------------------------------------------------------
  testWidgets(
    'institutions.filter: busca sem correspondência diz "sem resultados" e '
    'limpar (digitando ou por "Limpar filtros") restaura o diretório',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final repository = _ControlledRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.enterText(_searchField(), 'zzz-sem-correspondencia');
      await _settleSearch(tester);

      expect(find.text(_noResultsMessage), findsOneWidget);
      expect(find.text(_failureMessage), findsNothing);
      expect(find.text(_emptyMessage), findsNothing);
      expect(_institutionCards(), findsNothing);
      expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);

      await tester.enterText(_searchField(), '');
      await _settleSearch(tester);
      expect(find.text(_noResultsMessage), findsNothing);
      expect(_institutionCards(), findsNWidgets(5));
      expect(repository.pageQueries.last.search, '');

      await tester.enterText(_searchField(), 'zzz-sem-correspondencia');
      await _settleSearch(tester);
      expect(find.text(_noResultsMessage), findsOneWidget);
      final readsBeforeClear = repository.pageQueries.length;
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(repository.pageQueries.length, readsBeforeClear + 1);
      expect(repository.pageQueries.last.search, '');
      expect(repository.pageQueries.last.hasActiveFilters, isFalse);
      expect(tester.widget<TextField>(_searchField()).controller?.text, '');
      expect(find.text(_noResultsMessage), findsNothing);
      expect(find.text('Limpar filtros'), findsNothing);
      expect(_institutionCards(), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'institutions.filter: Tab alcança busca, toggle Cards/Tabela, filtros e o card Criar',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      await tester.pumpWidget(_app(_ControlledRepository()));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'busca': _searchField(),
        'toggle Cards/Tabela': find.byKey(const Key('institution-display-toggle')),
        'filtro de tipo': find.byKey(const Key('institution-type-filter')),
        'filtro de UF': find.byKey(const Key('institution-state-filter')),
        'card Criar': find.byKey(const Key('create-institution-card')),
      };
      final reachedInOrder = <String>[];
      for (var step = 0; step < 80 && reachedInOrder.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (!reachedInOrder.contains(entry.key) && _focusWithin(entry.value)) {
            reachedInOrder.add(entry.key);
          }
        }
        // O segmento Tabela abre o flyout ao receber foco por Tab; Escape o
        // fecha para que o percurso continue pelos demais controles.
        if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      for (final name in targets.keys) {
        expect(
          reachedInOrder,
          contains(name),
          reason: 'Tab não alcançou "$name"; alcançados em ordem: $reachedInOrder',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.detail
  // ---------------------------------------------------------------------------
  testWidgets(
    'institutions.detail: o card abre o detalhe com o id da instituição por toque e por Enter',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final opened = <String>[];
      await tester.pumpWidget(_app(_ControlledRepository(), onEdit: opened.add));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('institution-card-demo-institution-aurora'));

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(opened, ['demo-institution-aurora']);

      // Teclado: percorre os pontos de foco dentro do card e registra em qual
      // deles Enter abre o detalhe. O contrato é que o primeiro ponto de foco
      // (o que realça o card) ative.
      final reached = await _tabUntil(tester, card);
      expect(reached, isTrue, reason: 'Tab não alcançou o card');
      var stopsInsideCard = 0;
      int? activatedAtStop;
      while (_focusWithin(card) && stopsInsideCard < 5) {
        stopsInsideCard += 1;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (opened.length > 1) {
          activatedAtStop = stopsInsideCard;
          break;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(
        opened.skip(1).toList(),
        ['demo-institution-aurora'],
        reason: 'Enter dentro do card não abriu o detalhe (pontos de foco: $stopsInsideCard)',
      );
      expect(
        activatedAtStop,
        1,
        reason:
            'Enter só abriu o detalhe no ponto de foco $activatedAtStop do card; o card '
            'expõe ao menos $stopsInsideCard pontos de foco por Tab e o primeiro realça '
            'sem ativar.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.list: ativação por teclado das superfícies clicáveis
  // ---------------------------------------------------------------------------
  testWidgets(
    'institutions.list: o banner Criar da tabela ativa no primeiro ponto de foco',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      var creates = 0;
      await tester.pumpWidget(_app(_ControlledRepository(), onCreate: () => creates += 1));
      await tester.pumpAndSettle();

      // O card Criar vive na visão de cards; o banner Criar, na de tabela.
      await tester.tap(find.byKey(const Key('institution-view-table')));
      await tester.pumpAndSettle();
      final banner = find.byKey(const Key('create-institution-banner'));
      expect(banner, findsOneWidget);
      expect(find.byKey(const Key('create-institution-card')), findsNothing);

      // Percorre os pontos de foco dentro do banner e registra em qual deles
      // Enter aciona Criar. O contrato é que o banner ofereça um único ponto de
      // foco e que ele ative, como qualquer botão.
      final reached = await _tabUntil(tester, banner);
      expect(reached, isTrue, reason: 'Tab não alcançou o banner "Criar instituição"');
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
            'Enter só acionou Criar no ponto de foco $activatedAtStop do banner; o banner '
            'expõe ao menos $stopsInsideBanner pontos de foco por Tab e o primeiro apenas '
            'realça sem ativar.',
      );
    },
  );

  testWidgets(
    'institutions.list: o indicador de status ativa por teclado como se anuncia',
    (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await tester.pumpWidget(_app(_ControlledRepository()));
      await tester.pumpAndSettle();

      const itemId = 'demo-institution-aurora';
      final indicator = find.byKey(const Key('institution-status-$itemId'));
      expect(indicator, findsOneWidget);
      final collapsedWidth = tester.getSize(indicator).width;

      // Anúncio: o indicador se apresenta como botão e expõe a ação de toque.
      final node = tester.getSemantics(indicator);
      expect(
        node,
        isSemantics(label: 'Status: Ativa', isButton: true, hasTapAction: true),
        reason: 'o indicador se anuncia como $node',
      );

      // Toque: expande e, ao tocar de novo, volta ao estado recolhido. Esse
      // ciclo é a linha de base contra a qual o teclado é medido.
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      final tappedWidth = tester.getSize(indicator).width;
      expect(
        tappedWidth,
        greaterThan(collapsedWidth),
        reason: 'toque não expandiu o indicador (largura $collapsedWidth -> $tappedWidth)',
      );
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      final retractedWidth = tester.getSize(indicator).width;
      expect(
        retractedWidth,
        collapsedWidth,
        reason: 'segundo toque não recolheu o indicador (largura $tappedWidth -> $retractedWidth)',
      );

      // Teclado: Tab realça (o realce sozinho já expande, e some ao sair), então
      // a prova de ativação é a expansão permanecer depois que o foco vai embora,
      // exatamente como o toque faz.
      final reached = await _tabUntil(tester, _statusIndicator(itemId));
      expect(reached, isTrue, reason: 'Tab não alcançou o indicador de status');
      await tester.pumpAndSettle();
      final focusedWidth = tester.getSize(indicator).width;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final activatedWidth = tester.getSize(indicator).width;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final afterBlurWidth = tester.getSize(indicator).width;

      expect(
        afterBlurWidth,
        greaterThan(collapsedWidth),
        reason:
            'Enter no indicador focado não o ativou como o toque ativa. Larguras medidas: '
            'recolhido=$collapsedWidth, após toque=$tappedWidth, após segundo toque='
            '$retractedWidth, com foco=$focusedWidth, após Enter=$activatedWidth, após sair '
            'do foco=$afterBlurWidth.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // institutions.list em 375 e 1440
  // ---------------------------------------------------------------------------
  for (final width in const [375.0, 1440.0]) {
    final label = width.toInt();

    testWidgets('institutions.list @$label: cards e tabela alternam o conteúdo sem overflow', (
      tester,
    ) async {
      await _useSurface(tester, Size(width, 900));
      await tester.pumpWidget(_app(_ControlledRepository()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('institution-card-grid')), findsOneWidget);
      expect(find.byKey(const Key('institution-directory-table')), findsNothing);
      expect(_institutionCards(), findsNWidgets(5));

      await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
      await tester.tap(find.byKey(const Key('institution-view-table')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('institution-directory-table')), findsOneWidget);
      expect(find.byKey(const Key('institution-card-grid')), findsNothing);
      expect(_institutionTableRows(), findsNWidgets(5));

      await tester.ensureVisible(find.byKey(const Key('institution-view-cards')));
      await tester.tap(find.byKey(const Key('institution-view-cards')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('institution-card-grid')), findsOneWidget);
      expect(find.byKey(const Key('institution-directory-table')), findsNothing);
    });

    testWidgets('institutions.list @$label: paginação com alvos de toque de 48', (tester) async {
      await _useSurface(tester, Size(width, 900));
      await tester.pumpWidget(_app(_ControlledRepository(items: _pagedInstitutions())));
      await tester.pumpAndSettle();
      final footer = find.byKey(const Key('institution-directory-pagination-footer'));
      expect(footer, findsOneWidget);

      final controls = width < CoeloBreakpoints.medium.minWidth
          ? find.descendant(of: footer, matching: find.byType(IconButton))
          : find.descendant(
              of: footer,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is OutlinedButton &&
                    widget.enabled &&
                    widget.key != const Key('coelo-admin-pagination-page-size'),
              ),
            );
      expect(controls, findsWidgets);
      for (final element in controls.evaluate()) {
        final size = element.size!;
        expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$element $size');
        expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$element $size');
      }

      await tester.tap(
        width < CoeloBreakpoints.medium.minWidth
            ? find.bySemanticsLabel('Próxima página')
            : find.text('Próxima'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(find.text('Instituição 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('institutions.error @$label: falha compõe sem overflow com retry de 48', (
      tester,
    ) async {
      await _useSurface(tester, Size(width, 900));
      await tester.pumpWidget(
        _app(_ControlledRepository()..pageFailure = () => StateError('unavailable')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_failureMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final retry = _retryButton();
      await tester.ensureVisible(retry);
      final size = tester.getSize(retry);
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: '$size');
    });

    testWidgets('institutions.access-denied @$label: negado compõe sem overflow, dado ou Criar', (
      tester,
    ) async {
      await _useSurface(tester, Size(width, 900));
      await tester.pumpWidget(
        _app(
          _ControlledRepository()
            ..pageFailure = () => const InstitutionDirectoryUnauthorizedException(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_unauthorizedMessage), findsOneWidget);
      expect(_institutionCards(), findsNothing);
      expect(find.byKey(const Key('create-institution-card')), findsNothing);
      expect(find.byKey(const Key('create-institution-banner')), findsNothing);
      expect(find.byKey(const Key('institution-filter-toolbar')), findsNothing);
      expect(_retryButton(), findsNothing);
    });
  }
}

// -----------------------------------------------------------------------------
// Cenários de erro (institutions.error)
// -----------------------------------------------------------------------------

typedef _ErrorScenario = ({
  String label,
  Object Function()? pageFailure,
  Object Function()? filterOptionsFailure,
  bool synchronous,
  String leakedDetail,
});

final _errorScenarios = <_ErrorScenario>[
  (
    label: 'StateError assíncrono na página',
    pageFailure: () => StateError('state detail'),
    filterOptionsFailure: null,
    synchronous: false,
    leakedDetail: 'state detail',
  ),
  (
    label: 'TypeError de cast real na página',
    pageFailure: _realCastError,
    filterOptionsFailure: null,
    synchronous: false,
    leakedDetail: 'is not a subtype',
  ),
  (
    label: 'RangeError de página malformada',
    pageFailure: () => RangeError.index(3, const <Object>[], 'items', 'range detail'),
    filterOptionsFailure: null,
    synchronous: false,
    leakedDetail: 'range detail',
  ),
  (
    label: 'StateError síncrono antes do Future',
    pageFailure: () => StateError('sync detail'),
    filterOptionsFailure: null,
    synchronous: true,
    leakedDetail: 'sync detail',
  ),
  (
    label: 'StateError nas opções de filtro',
    pageFailure: null,
    filterOptionsFailure: () => StateError('filter detail'),
    synchronous: false,
    leakedDetail: 'filter detail',
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
  return StateError('the cast unexpectedly succeeded');
}

// -----------------------------------------------------------------------------
// Fixtures e finders
// -----------------------------------------------------------------------------

Widget _app(
  InstitutionDirectoryRepository repository, {
  ValueChanged<String>? onEdit,
  VoidCallback? onCreate,
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    home: InstitutionDirectoryPage(
      repository: repository,
      logout: () async => const LogoutResult.success(),
      onCreate: onCreate ?? () {},
      onEdit: onEdit ?? (_) {},
    ),
  );
}

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

/// A busca é debounced por 300 ms antes de reler o diretório.
Future<void> _settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Finder _searchField() => find.descendant(
  of: find.byKey(const Key('institution-directory-search')),
  matching: find.byType(TextField),
);

Finder _retryButton() => find.widgetWithText(OutlinedButton, _retryLabel);

Finder _institutionCards() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  if (key is! ValueKey<String>) return false;
  final value = key.value;
  return value.startsWith('institution-card-') &&
      value != 'institution-card-grid' &&
      !value.startsWith('institution-card-surface-') &&
      !value.startsWith('institution-card-detail-');
});

/// O indicador de status: a chave fica no filho animado, mas quem recebe foco é
/// o widget inteiro, então o percurso por Tab precisa mirar o widget.
Finder _statusIndicator(String itemId) => find.byWidgetPredicate(
  (widget) => widget is ExpandableInstitutionStatusIndicator && widget.itemId == itemId,
);

Finder _institutionTableRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('institution-table-row-');
});

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

/// Pressiona Tab até o foco entrar em [finder]; falso após [maxSteps].
Future<bool> _tabUntil(WidgetTester tester, Finder finder, {int maxSteps = 80}) async {
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

/// 13 ativas e 2 inativas cujo nome contém "Instituição": com busca e status
/// "Ativos" o diretório em cards (11 por página) tem exatamente 2 páginas.
List<InstitutionDirectoryItem> _pagedInstitutions() => [
  for (var index = 1; index <= 13; index++)
    _item(
      'acc-active-$index',
      'Instituição ${index.toString().padLeft(2, '0')}',
      InstitutionStatus.active,
    ),
  _item('acc-inactive-a', 'Instituição Inativa A', InstitutionStatus.inactive),
  _item('acc-inactive-b', 'Instituição Inativa B', InstitutionStatus.inactive),
];

InstitutionDirectoryItem _item(String id, String name, InstitutionStatus status) {
  return InstitutionDirectoryItem(
    id: id,
    publicName: name,
    tradeName: null,
    legalName: null,
    primaryDomain: null,
    status: status,
    typeId: null,
    typeName: null,
    city: null,
    state: null,
    planId: null,
    planName: null,
    unitsCount: 0,
    groupsCount: 0,
  );
}

/// Delega ao fake local e pode ser posto em falha, negado ou segurado a
/// qualquer momento. Somente as leituras mudam; o restante da página continua
/// acreditando no que pode fazer.
final class _ControlledRepository implements InstitutionDirectoryRepository {
  _ControlledRepository({List<InstitutionDirectoryItem>? items})
    : _delegate = FakeInstitutionDirectoryRepository(items: items);

  final FakeInstitutionDirectoryRepository _delegate;
  final pageQueries = <InstitutionDirectoryQuery>[];

  /// Construído a cada leitura para que cada falha seja um objeto distinto.
  Object Function()? pageFailure;
  Object Function()? filterOptionsFailure;
  bool failSynchronously = false;
  Completer<void>? _gate;

  void holdNextReads() => _gate = Completer<void>();

  void releaseReads() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    pageQueries.add(query);
    final failure = pageFailure;
    if (failure != null && failSynchronously) throw failure();
    return _readPage(query, failure);
  }

  Future<domain.InstitutionDirectoryPage> _readPage(
    InstitutionDirectoryQuery query,
    Object Function()? failure,
  ) async {
    final gate = _gate;
    if (gate != null) await gate.future;
    if (failure != null) throw failure();
    return _delegate.fetchPage(query);
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    final failure = filterOptionsFailure;
    if (failure != null) throw failure();
    return _delegate.fetchFilterOptions(states: states, cities: cities);
  }

  @override
  Future<InstitutionRecord> fetchById(String institutionId) => _delegate.fetchById(institutionId);

  @override
  Future<InstitutionRecord> create(InstitutionRecord draft) => _delegate.create(draft);

  @override
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) =>
      _delegate.update(draft, expectedVersion: expectedVersion);
}
