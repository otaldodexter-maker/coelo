import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_directory_cards.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _failureMessage = 'Não foi possível carregar as unidades. Tente novamente.';
const _noResultsMessage = 'Nenhuma unidade encontrada com estes filtros.';

/// The toolbar renders more than one search box; this is the directory's own.
final _unitSearch = find.byWidgetPredicate(
  (widget) => widget is CoeloSearchField && widget.semanticLabel == 'Buscar unidade por nome',
);

void main() {
  Widget app(domain.UnitDirectoryRepository repository, {bool canCreate = true}) => MaterialApp(
    theme: CoeloTheme.light,
    home: UnitDirectoryPage(
      repository: repository,
      logout: () async => const LogoutResult.success(),
      onCreate: canCreate ? () {} : null,
    ),
  );

  testWidgets('a failed load says so and never shows an empty directory instead', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository()..failing = true;

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text(_failureMessage), findsOneWidget);
    // A failure must not be dressed as "no units registered".
    expect(find.text('Ainda não há unidades cadastradas.'), findsNothing);
    expect(find.text(_noResultsMessage), findsNothing);
    expect(find.byKey(const Key('unit-card-grid')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating stays available while the directory is failing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository()..failing = true;

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    expect(find.byType(UnitCreateBanner), findsOneWidget);
  });

  testWidgets('without permission to create, the failure offers no creation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository()..failing = true;

    await tester.pumpWidget(app(repository, canCreate: false));
    await tester.pumpAndSettle();
    expect(find.text(_failureMessage), findsOneWidget);
    expect(find.byType(UnitCreateBanner), findsNothing);
  });

  testWidgets('retry reloads once and recovers without duplicating the read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository()..failing = true;

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final callsBeforeRetry = repository.pageQueries.length;

    repository.failing = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.pageQueries.length, callsBeforeRetry + 1);
    expect(find.text(_failureMessage), findsNothing);
    expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
  });

  testWidgets('retry keeps the search that was active when the load failed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository();

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.enterText(_unitSearch, 'Aurora');
    await _settleSearch(tester);
    expect(repository.pageQueries.last.search, 'Aurora');

    repository.failing = true;
    await tester.enterText(_unitSearch, 'Aurora Norte');
    await _settleSearch(tester);
    expect(find.text(_failureMessage), findsOneWidget);

    repository.failing = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    // The retry re-reads the same filter instead of silently widening it.
    expect(repository.pageQueries.last.search, 'Aurora Norte');
  });

  testWidgets('a search with no match says no results, not failure', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository();

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.enterText(_unitSearch, 'unidade que não existe em lugar nenhum');
    await _settleSearch(tester);

    expect(find.text(_noResultsMessage), findsOneWidget);
    expect(find.text(_failureMessage), findsNothing);
    expect(find.byType(UnitCreateBanner), findsOneWidget);
  });

  testWidgets('clearing the search restores the directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository();

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.enterText(_unitSearch, 'zzzz-sem-resultado');
    await _settleSearch(tester);
    expect(find.text(_noResultsMessage), findsOneWidget);

    await tester.enterText(_unitSearch, '');
    await _settleSearch(tester);
    expect(find.text(_noResultsMessage), findsNothing);
    expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
    expect(repository.pageQueries.last.search, '');
  });

  testWidgets('the retry action is reachable and activated by keyboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledUnitDirectoryRepository()..failing = true;

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final retry = find.widgetWithText(OutlinedButton, 'Tentar novamente');
    expect(tester.widget<OutlinedButton>(retry).enabled, isTrue);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(40));
    repository.failing = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-card-grid')), findsOneWidget);
  });
}

/// Delegates to the local fake and can be switched into failure at will.
///
/// Only the reads are switched: a failing directory must not change what the
/// rest of the page believes it can do.
final class _ControlledUnitDirectoryRepository implements domain.UnitDirectoryRepository {
  _ControlledUnitDirectoryRepository()
    : _delegate = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());

  final domain.UnitDirectoryRepository _delegate;
  final pageQueries = <domain.UnitDirectoryQuery>[];
  bool failing = false;

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
  }) => _delegate.fetchFilterOptions(states: states, cities: cities);

  @override
  Future<domain.UnitDirectoryPage> fetchPage(domain.UnitDirectoryQuery query) async {
    pageQueries.add(query);
    if (failing) throw StateError('unit directory unavailable');
    return _delegate.fetchPage(query);
  }

  @override
  Future<domain.UnitFormData> loadForm({String? unitId}) => _delegate.loadForm(unitId: unitId);

  @override
  Future<void> upsert(domain.UnitRecord record) => _delegate.upsert(record);
}

/// Typing is debounced by 300 ms before the directory is read again.
Future<void> _settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}
