import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_directory_view_model.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_directory_states.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps create available in recoverable states but not when unauthorized', (
    tester,
  ) async {
    final repository = _StateRepository(
      FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
    );
    final viewModel = UnitDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    Future<void> pumpState() => tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: viewModel,
            builder: (context, child) => UnitDirectoryStates(
              viewModel: viewModel,
              createAction: const SizedBox(key: Key('create-unit-state-action')),
              successContent: const SizedBox(key: Key('unit-success-content')),
            ),
          ),
        ),
      ),
    );

    await viewModel.load();
    await pumpState();
    expect(find.byKey(const Key('create-unit-state-action')), findsOneWidget);

    await viewModel.setStatuses({UnitStatus.draft});
    await pumpState();
    expect(find.byKey(const Key('create-unit-state-action')), findsOneWidget);

    repository.failure = true;
    await viewModel.retry();
    await pumpState();
    expect(find.byKey(const Key('create-unit-state-action')), findsOneWidget);

    repository
      ..failure = false
      ..unauthorized = true;
    await viewModel.retry();
    await pumpState();
    expect(find.byKey(const Key('create-unit-state-action')), findsNothing);
  });

  testWidgets('shows a safe technical error and retries without exposing backend details', (
    tester,
  ) async {
    final repository = _StateRepository(
      FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
    )..failure = true;
    final viewModel = UnitDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: viewModel,
            builder: (context, child) => UnitDirectoryStates(
              viewModel: viewModel,
              createAction: const SizedBox(key: Key('create-unit-state-action')),
              successContent: const SizedBox(key: Key('unit-success-content')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Não foi possível carregar as unidades. Tente novamente.'), findsOneWidget);
    expect(find.textContaining('sensitive backend detail'), findsNothing);

    repository.failure = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(viewModel.state, UnitDirectoryLoadState.empty);
    expect(find.text('Ainda não há unidades cadastradas.'), findsOneWidget);
    expect(find.text('Não foi possível carregar as unidades. Tente novamente.'), findsNothing);
  });
}

final class _StateRepository implements UnitDirectoryRepository {
  _StateRepository(this.delegate);

  final UnitDirectoryRepository delegate;
  bool failure = false;
  bool unauthorized = false;

  @override
  List<UnitRecord> get records => delegate.records;

  @override
  String createId(String institutionId, String slug) => delegate.createId(institutionId, slug);

  @override
  UnitRecord? findById(String id) => delegate.findById(id);

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    if (unauthorized) throw const UnitDirectoryUnauthorizedException();
    return delegate.fetchFilterOptions(states: states, cities: cities);
  }

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) {
    if (unauthorized) throw const UnitDirectoryUnauthorizedException();
    if (failure) throw Exception('sensitive backend detail');
    return Future.value(
      UnitDirectoryPage(items: const [], totalCount: 0, page: query.page, pageSize: query.pageSize),
    );
  }

  @override
  Future<UnitFormData> loadForm({String? unitId}) => delegate.loadForm(unitId: unitId);

  @override
  Future<void> upsert(UnitRecord record) => delegate.upsert(record);
}
