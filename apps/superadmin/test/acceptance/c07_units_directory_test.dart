// C07 - Unidades: aceitacao de fluxo do diretorio (sem golden).
//
// Acoes: units.list, units.filter, units.error, units.access-denied,
// units.reload. Cobre apenas o que `test/features/units/` ainda nao prova:
// falha por `Error` real (bad cast e RangeError sincrono, hunk de fdf0972d),
// filtro de instituicao/status preservado por retry, toggle, paginacao e
// tamanho de pagina, paginacao com a query certa em 1440 e 375, negado sem
// dado/criar/retry/releitura, releitura ao voltar para a tela, alcance por Tab
// e alternancia Cards/Tabela em 375 e 1440 sem excecao de layout.
//
// O fake local traz 12 unidades ativas em 5 instituicoes (Aurora 3, Mare Alta
// 4, Pontes 2, Sementes 2, Horizonte 1 "Unidade Cambui"). Os testes de
// paginacao semeiam 12 unidades a mais pelo proprio `upsert` do fake e marcam
// a Cambui como rascunho, para haver tres paginas reais e um item que a aba
// "Ativos" de fato exclua.
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_directory_view_model.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_directory_cards.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _failureMessage = 'Não foi possível carregar as unidades. Tente novamente.';
const _deniedMessage = 'Você não tem permissão para ver as unidades.';
const _auroraId = 'demo-institution-aurora';
const _auroraUnitIds = ['$_auroraId-unit-01', '$_auroraId-unit-02', '$_auroraId-unit-03'];
const _cambuiId = 'demo-institution-horizonte-unit-01';
const _active = {domain.UnitStatus.active};

final _unitSearch = find.byWidgetPredicate(
  (widget) => widget is CoeloSearchField && widget.semanticLabel == 'Buscar unidade por nome',
);
final _retry = find.widgetWithText(OutlinedButton, 'Tentar novamente');
final _nextPage = _outlinedButtonLabelled('Próxima');
final _previousPage = _outlinedButtonLabelled('Anterior');

void main() {
  group('units.error', () {
    testWidgets('a bad cast while reading the page leaves loading and lands on failure', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository()..malformedPage = true;

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      // The Error is a real TypeError from a cast, not an Exception: before
      // fdf0972d it escaped the catch and the spinner stayed on screen.
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(_failureMessage), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_retry).enabled, isTrue);
      expect(repository.pageQueries, hasLength(1));

      repository.malformedPage = false;
      await tester.tap(_retry);
      await tester.pumpAndSettle();

      expect(repository.pageQueries, hasLength(2));
      expect(find.text(_failureMessage), findsNothing);
      expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
    });

    testWidgets('a synchronous RangeError from the filter options read is not a silent hang', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository()..brokenOptions = true;

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      // The second half of the load (filter options) throws before returning
      // a Future; the page must still reach the honest failure state.
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(_failureMessage), findsOneWidget);
      expect(find.byType(UnitCreateBanner), findsOneWidget);
      expect(repository.optionReads, 1);

      repository.brokenOptions = false;
      await tester.tap(_retry);
      await tester.pumpAndSettle();

      expect(repository.optionReads, 2);
      expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
    });

    test('the view model completes a load that throws an Error and recovers on retry', () async {
      final repository = _ScriptedUnitDirectoryRepository()..malformedPage = true;
      final viewModel = UnitDirectoryViewModel(repository);
      addTearDown(viewModel.dispose);

      // A hang would never complete this future; the timeout makes it fail.
      await viewModel.load().timeout(const Duration(seconds: 2));
      expect(viewModel.state, UnitDirectoryLoadState.failure);
      expect(viewModel.isLoading, isFalse);

      repository
        ..malformedPage = false
        ..brokenOptions = true;
      await viewModel.retry().timeout(const Duration(seconds: 2));
      expect(viewModel.state, UnitDirectoryLoadState.failure);

      repository.brokenOptions = false;
      await viewModel.retry().timeout(const Duration(seconds: 2));
      expect(viewModel.state, UnitDirectoryLoadState.success);
      expect(viewModel.page.items, hasLength(11));
    });
  });

  group('units.filter', () {
    testWidgets(
      'the institution filter reaches the repository and survives retry, the display toggle '
      'and clearing',
      (tester) async {
        await _resize(tester, 1440);
        final repository = _ScriptedUnitDirectoryRepository();

        await tester.pumpWidget(_app(repository));
        await tester.pumpAndSettle();
        expect(_visibleCardIds(tester), hasLength(11));

        // The filtered read fails: the failure must carry the filter, not drop it.
        repository.malformedPage = true;
        await _applyInstitutionFilter(tester, 'Instituto Aurora');
        expect(find.text(_failureMessage), findsOneWidget);
        expect(repository.lastQuery.institutionIds, {_auroraId});

        repository.malformedPage = false;
        await tester.tap(_retry);
        await tester.pumpAndSettle();
        expect(repository.lastQuery.institutionIds, {_auroraId});
        expect(_visibleCardIds(tester), _auroraUnitIds);
        expect(
          find.descendant(
            of: find.byKey(const Key('unit-institution-filter')),
            matching: find.text('Instituto Aurora'),
          ),
          findsOneWidget,
        );
        expect(find.text('Limpar filtros'), findsOneWidget);
        expect(find.text('Página 1 de 1'), findsOneWidget);

        // Cards -> table re-reads with eight rows and the same institution.
        await tester.tap(find.byKey(const Key('unit-view-table')));
        await tester.pumpAndSettle();
        expect(repository.lastQuery.pageSize, 8);
        expect(repository.lastQuery.institutionIds, {_auroraId});
        expect(find.byKey(const Key('unit-directory-table')), findsOneWidget);
        for (final id in _auroraUnitIds) {
          expect(find.byKey(Key('copy-unit-email-$id')), findsOneWidget, reason: id);
        }
        expect(find.byKey(const Key('copy-unit-email-$_cambuiId')), findsNothing);

        // Table -> cards restores eleven and still keeps the institution.
        await tester.tap(find.byKey(const Key('unit-view-cards')));
        await tester.pumpAndSettle();
        expect(repository.lastQuery.pageSize, 11);
        expect(repository.lastQuery.institutionIds, {_auroraId});
        expect(_visibleCardIds(tester), _auroraUnitIds);

        await tester.tap(find.text('Limpar filtros'));
        await tester.pumpAndSettle();
        expect(repository.lastQuery.institutionIds, isEmpty);
        expect(repository.lastQuery.hasActiveFilters, isFalse);
        expect(_visibleCardIds(tester), hasLength(11));
        expect(find.text('Limpar filtros'), findsNothing);
      },
    );

    testWidgets('changing the page size re-reads from the first page with the status kept', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository();
      await repository.seedThreePages();

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
      expect(find.text('Página 1 de 2'), findsOneWidget);
      final ids = _visibleCardIds(tester);
      expect(ids, await repository.expectedIds(pageSize: 20, statuses: _active));
      expect(ids, hasLength(20));
      expect(ids, isNot(contains(_cambuiId)));
    });
  });

  group('units.list', () {
    testWidgets('next, previous and numbered pages read the right page with the status kept', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository();
      await repository.seedThreePages();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 3'), findsOneWidget);
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();
      expect(repository.lastQuery.statuses, _active);
      expect(repository.lastQuery.page, 0);
      expect(find.text('Página 1 de 3'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_previousPage).enabled, isFalse);
      for (final target in [_nextPage, _previousPage, _pageButton(2)]) {
        expect(tester.getSize(target).height, greaterThanOrEqualTo(CoeloSize.touchMin));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(CoeloSize.touchMin));
      }
      final firstPageIds = _visibleCardIds(tester);
      expect(firstPageIds, await repository.expectedIds(statuses: _active));

      await tester.tap(_nextPage);
      await tester.pumpAndSettle();
      expect(repository.lastQuery.page, 1);
      expect(repository.lastQuery.statuses, _active);
      expect(find.text('Página 2 de 3'), findsOneWidget);
      final secondPageIds = _visibleCardIds(tester);
      expect(secondPageIds, await repository.expectedIds(page: 1, statuses: _active));
      expect(secondPageIds, isNot(firstPageIds));

      await tester.tap(_pageButton(3));
      await tester.pumpAndSettle();
      expect(repository.lastQuery.page, 2);
      expect(repository.lastQuery.statuses, _active);
      expect(find.text('Página 3 de 3'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_nextPage).enabled, isFalse);
      final thirdPageIds = _visibleCardIds(tester);
      expect(thirdPageIds, await repository.expectedIds(page: 2, statuses: _active));
      // 23 active units: 11 + 11 + 1. The draft never shows up on any page.
      expect(thirdPageIds, hasLength(1));
      expect([...firstPageIds, ...secondPageIds, ...thirdPageIds], isNot(contains(_cambuiId)));

      await tester.tap(_previousPage);
      await tester.pumpAndSettle();
      expect(repository.lastQuery.page, 1);
      expect(repository.lastQuery.statuses, _active);
      expect(_visibleCardIds(tester), secondPageIds);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact pagination at 375 keeps 48 px targets and pages with the status kept', (
      tester,
    ) async {
      await _resize(tester, 375);
      final repository = _ScriptedUnitDirectoryRepository();
      await repository.seedThreePages();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();

      final next = find.byKey(const Key('coelo-admin-pagination-next'));
      final previous = find.byKey(const Key('coelo-admin-pagination-previous'));
      expect(find.text('Página 1 de 3'), findsOneWidget);
      for (final target in [next, previous]) {
        expect(tester.getSize(target).height, greaterThanOrEqualTo(CoeloSize.touchMin));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(CoeloSize.touchMin));
        expect(tester.getRect(target).right, lessThanOrEqualTo(375));
      }
      expect(tester.widget<IconButton>(previous).onPressed, isNull);

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(repository.lastQuery.page, 1);
      expect(repository.lastQuery.statuses, _active);
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(_visibleCardIds(tester), await repository.expectedIds(page: 1, statuses: _active));

      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(repository.lastQuery.page, 0);
      expect(repository.lastQuery.statuses, _active);
      expect(find.text('Página 1 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('units.access-denied', () {
    testWidgets('denied shows only the access message: no data, create, retry or re-read', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository()..unauthorized = true;

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_deniedMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(_failureMessage), findsNothing);
      expect(find.text('Tentar novamente'), findsNothing);
      // Permission to create was granted to the page, but a denied directory
      // must not offer it.
      expect(find.byType(UnitCreateBanner), findsNothing);
      expect(find.byKey(const Key('create-unit-card')), findsNothing);
      expect(find.byKey(const Key('unit-display-toggle')), findsNothing);
      expect(_unitSearch, findsNothing);
      expect(_visibleCardIds(tester), isEmpty);
      expect(find.textContaining('Unidade 0'), findsNothing);
      expect(find.text('Unidade Cambuí'), findsNothing);
      expect(find.byKey(const Key('unit-directory-pagination-footer')), findsNothing);

      // No retry loop hammering a backend that already said no.
      expect(repository.pageQueries, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
      expect(repository.pageQueries, hasLength(1));
      expect(find.text(_deniedMessage), findsOneWidget);
    });
  });

  group('units.reload', () {
    testWidgets('coming back to the directory re-reads the repository and shows the notice', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(repository.pageQueries, hasLength(1));
      expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);

      // Leave (e.g. to the unit form) and return with the save notice.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(repository, successMessage: 'Unidade salva.'));
      await tester.pumpAndSettle();

      expect(repository.pageQueries, hasLength(2));
      expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
      expect(find.text('Unidade salva.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard and widths', () {
    testWidgets('Tab reaches search, filters, status tabs, the cards/table toggle and pagination', (
      tester,
    ) async {
      await _resize(tester, 1440);
      final repository = _ScriptedUnitDirectoryRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'search': _unitSearch,
        'institution filter': find.byKey(const Key('unit-institution-filter')),
        'type filter': find.byKey(const Key('unit-type-filter')),
        'plan filter': find.byKey(const Key('unit-plan-filter')),
        'state filter': find.byKey(const Key('unit-state-filter')),
        'cards segment': find.byKey(const Key('unit-view-cards')),
        'table segment': find.byKey(const Key('unit-view-table')),
        'status tabs': find.byKey(const Key('unit-status-tabs')),
        'page size': find.byKey(const Key('coelo-admin-pagination-page-size')),
        'next page': _nextPage,
      };
      final reached = <String>{};
      final tableMenuItem = find.widgetWithText(MenuItemButton, 'Por turmas');

      for (var step = 0; step < 160 && reached.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (_focusTouches(tester, entry.value)) reached.add(entry.key);
        }
        // Focusing the table segment by Tab opens its view flyout; Escape
        // closes it and hands focus back so traversal can continue.
        if (tableMenuItem.evaluate().isNotEmpty) {
          reached.add('table segment');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      expect(
        reached,
        containsAll(targets.keys),
        reason: 'unreached by Tab: ${targets.keys.toSet().difference(reached)}',
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('cards and table alternate at ${width.toInt()} px without layout exceptions', (
        tester,
      ) async {
        await _resize(tester, width);
        final repository = _ScriptedUnitDirectoryRepository();

        await tester.pumpWidget(_app(repository));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const Key('unit-filter-toolbar'))).right,
          lessThanOrEqualTo(width),
        );

        await tester.ensureVisible(find.byKey(const Key('unit-view-table')));
        await tester.tap(find.byKey(const Key('unit-view-table')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('unit-directory-table')), findsOneWidget);
        expect(find.byKey(const Key('unit-card-grid')), findsNothing);
        expect(
          tester.getRect(find.byKey(const Key('unit-directory-table'))).right,
          lessThanOrEqualTo(width),
        );
        expect(find.byKey(const Key('unit-directory-pagination-footer')), findsOneWidget);

        await tester.ensureVisible(find.byKey(const Key('unit-view-cards')));
        await tester.tap(find.byKey(const Key('unit-view-cards')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
        expect(find.byKey(const Key('unit-directory-table')), findsNothing);
        expect(repository.pageQueries.map((query) => query.pageSize), [11, 8, 11]);
      });
    }
  });
}

Widget _app(domain.UnitDirectoryRepository repository, {String? successMessage}) => MaterialApp(
  theme: CoeloTheme.light,
  home: UnitDirectoryPage(
    repository: repository,
    logout: () async => const LogoutResult.success(),
    onCreate: () {},
    successMessage: successMessage,
  ),
);

Future<void> _resize(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// `OutlinedButton.icon` builds a private subclass, so `byType` cannot see it.
Finder _outlinedButtonLabelled(String label) => find
    .ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is OutlinedButton))
    .first;

Finder _pageButton(int page) => find.byKey(Key('coelo-admin-pagination-page-$page'));

/// Ids of the unit cards currently in the grid, in render order.
List<String> _visibleCardIds(WidgetTester tester) => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('unit-card-demo-');
  }).evaluate())
    (element.widget.key! as ValueKey<String>).value.substring('unit-card-'.length),
];

Future<void> _applyInstitutionFilter(WidgetTester tester, String institutionName) async {
  await tester.tap(find.byKey(const Key('unit-institution-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, institutionName));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
  await tester.pumpAndSettle();
}

/// Whether the primary focus sits inside [target] or wraps it (segments focus
/// the button that contains the keyed icon).
bool _focusTouches(WidgetTester tester, Finder target) {
  final focusedContext = tester.binding.focusManager.primaryFocus?.context;
  if (focusedContext == null || target.evaluate().isEmpty) return false;
  final focused = find.byElementPredicate((element) => identical(element, focusedContext));
  return find.descendant(of: target, matching: focused, matchRoot: true).evaluate().isNotEmpty ||
      find.descendant(of: focused, matching: target, matchRoot: true).evaluate().isNotEmpty;
}

/// Wraps the local fake so reads can be recorded and made to fail with real
/// Errors (not Exceptions) or with the unauthorized signal.
final class _ScriptedUnitDirectoryRepository implements domain.UnitDirectoryRepository {
  _ScriptedUnitDirectoryRepository()
    : _delegate = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());

  final FakeUnitDirectoryRepository _delegate;
  final pageQueries = <domain.UnitDirectoryQuery>[];
  int optionReads = 0;

  /// `fetchPage` completes with a TypeError produced by a real bad cast.
  bool malformedPage = false;

  /// `fetchFilterOptions` throws a RangeError synchronously, before any Future.
  bool brokenOptions = false;
  bool unauthorized = false;

  domain.UnitDirectoryQuery get lastQuery => pageQueries.last;

  /// 12 seeded units + 12 extra = 24; the Cambuí unit becomes a draft, so the
  /// "Ativos" tab sees 23 (11 + 11 + 1) and the whole directory sees 3 pages.
  Future<void> seedThreePages() async {
    final template = _delegate.findById(_auroraUnitIds.first)!;
    for (var index = 1; index <= 12; index++) {
      final slug = 'extra-${index.toString().padLeft(2, '0')}';
      await _delegate.upsert(
        template.copyWith(
          id: _delegate.createId(template.institutionId, slug),
          name: 'Unidade Extra ${index.toString().padLeft(2, '0')}',
          slug: slug,
        ),
      );
    }
    final cambui = _delegate.findById(_cambuiId)!;
    await _delegate.upsert(cambui.copyWith(status: domain.UnitStatus.draft));
  }

  /// What the fake itself returns for the same query, for comparison.
  Future<List<String>> expectedIds({
    int page = 0,
    int pageSize = domain.UnitDirectoryQuery.defaultPageSize,
    Set<domain.UnitStatus> statuses = const {},
  }) async {
    final result = await _delegate.fetchPage(
      domain.UnitDirectoryQuery(page: page, pageSize: pageSize, statuses: statuses),
    );
    return [for (final item in result.items) item.id];
  }

  @override
  List<domain.UnitRecord> get records => _delegate.records;

  @override
  String createId(String institutionId, String slug) => _delegate.createId(institutionId, slug);

  @override
  domain.UnitRecord? findById(String id) => _delegate.findById(id);

  @override
  Future<domain.UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    optionReads += 1;
    // Delivered through the Future, as a real async repository would.
    if (unauthorized) return Future.error(const domain.UnitDirectoryUnauthorizedException());
    if (brokenOptions) throw RangeError.index(3, const <Object>[], 'page');
    return _delegate.fetchFilterOptions(states: states, cities: cities);
  }

  @override
  Future<domain.UnitDirectoryPage> fetchPage(domain.UnitDirectoryQuery query) async {
    pageQueries.add(query);
    if (unauthorized) throw const domain.UnitDirectoryUnauthorizedException();
    if (malformedPage) {
      // A malformed backend row: the cast itself throws a TypeError.
      final Object malformed = <String, Object?>{'items': null};
      return malformed as domain.UnitDirectoryPage;
    }
    return _delegate.fetchPage(query);
  }

  @override
  Future<domain.UnitFormData> loadForm({String? unitId}) => _delegate.loadForm(unitId: unitId);

  @override
  Future<void> upsert(domain.UnitRecord record) => _delegate.upsert(record);
}
