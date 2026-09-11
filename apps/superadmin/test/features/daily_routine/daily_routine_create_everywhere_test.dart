import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// V-15 (Owner, 11/09/2026, A+): o card Criar aparece em Modelos, Rotinas e
/// Lançamentos, em cards e na tabela, mesmo com dados; a tabela oferece as
/// mesmas ações do card. Rotina nasce de um modelo e lançamento de uma rotina,
/// por isso o card abre um seletor de origem.
final class _Repository implements RoutineRepository {
  _Repository({this.models = const [], this.applications = const []});
  final List<RoutineDirectoryItem> models, applications;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    final items = switch (query.kind) {
      RoutineEntryKind.model => models,
      RoutineEntryKind.application => applications,
      RoutineEntryKind.launch => const <RoutineDirectoryItem>[],
    };
    return RoutineDirectoryPage(
      items: items,
      page: 1,
      pageSize: query.pageSize,
      totalCount: items.length,
      canManage: true,
    );
  }

  Never _unused() => throw UnimplementedError();
  @override
  Future<RoutineModel> fetchModel(String id) async => _unused();
  @override
  Future<RoutineApplication> fetchApplication(String id) async => _unused();
  @override
  Future<RoutineLaunch> fetchLaunch(String id) async => _unused();
  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async => _unused();
  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async => _unused();
  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async => _unused();
  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async =>
      _unused();
  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async => _unused();
  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async => _unused();
}

const _model = RoutineDirectoryItem(
  id: 'model-1',
  kind: RoutineEntryKind.model,
  name: 'Modelo Berçário',
  status: 'active',
  version: 1,
);
const _application = RoutineDirectoryItem(
  id: 'app-1',
  kind: RoutineEntryKind.application,
  name: 'Rotina Berçário',
  status: 'active',
  version: 1,
);

void main() {
  testWidgets('card Criar em toda aba, seletor de origem e ações na tabela', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fromModel = <RoutineDirectoryItem>[];
    final launched = <RoutineDirectoryItem>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineDirectoryPage(
          repository: _Repository(models: const [_model], applications: const [_application]),
          logout: unavailableSuperadminLogout,
          onCreateEntry: (_) {},
          onDuplicateModel: (_) {},
          onCreateFromModel: fromModel.add,
          onCreateLaunch: (item) async {
            launched.add(item);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Modelos: card Criar com dados, e a tabela repete as ações do card.
    expect(find.text('Criar modelo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-create-banner')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-duplicate-model-1-row')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-apply-model-1-row')));
    expect(fromModel.single.id, 'model-1');

    // Rotinas: Criar rotina abre o seletor de modelo.
    await tester.tap(find.text('Rotinas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rotina'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-origin-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-origin-model-1')));
    await tester.pumpAndSettle();
    expect(fromModel.length, 2);

    // Rotina aplicada: Lançar hoje cria o rascunho e leva a Lançamentos.
    await tester.tap(find.byKey(const Key('daily-routine-launch-app-1-row')));
    await tester.pumpAndSettle();
    expect(launched.single.id, 'app-1');
    expect(find.text('Criar lançamento'), findsOneWidget, reason: 'aba Lançamentos aberta');

    // Lançamentos vazio ainda mostra Criar e o seletor de rotina.
    await tester.tap(find.text('Criar lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-origin-app-1')));
    await tester.pumpAndSettle();
    expect(launched.length, 2);
  });
}
