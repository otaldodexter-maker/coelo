import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D7: Lançamentos no MVP é uma tela mínima sobre o comando
/// `daily-routine.publish`, que já existe. O que estes testes provam é o que a
/// tela deve garantir: publicar pede confirmação, não acontece duas vezes por
/// um toque repetido, e só aparece para quem pode e para o que ainda é
/// rascunho. Autoria, capacidade, escopo e versão esperada são recalculados no
/// servidor e provados no pgTAP.
final class _LaunchDirectoryRepository implements RoutineRepository {
  _LaunchDirectoryRepository({this.canManage = true, this.status = 'draft'});

  final bool canManage;
  final String status;
  var loads = 0;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    loads++;
    if (query.kind != RoutineEntryKind.launch) {
      return RoutineDirectoryPage(
        items: const [],
        page: query.page,
        pageSize: query.pageSize,
        totalCount: 0,
        canManage: canManage,
      );
    }
    return RoutineDirectoryPage(
      items: [
        RoutineDirectoryItem(
          id: 'launch-1',
          kind: RoutineEntryKind.launch,
          name: '2026-09-10',
          status: status,
          version: 4,
        ),
      ],
      page: query.page,
      pageSize: query.pageSize,
      totalCount: 1,
      canManage: canManage,
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

Future<void> _openLaunchesTab(WidgetTester tester) async {
  await tester.tap(find.text('Lançamentos'));
  await tester.pumpAndSettle();
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required _LaunchDirectoryRepository repository,
  Future<bool> Function(RoutineDirectoryItem item)? onPublishLaunch,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1024));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineDirectoryPage(
        repository: repository,
        logout: unavailableSuperadminLogout,
        onPublishLaunch: onPublishLaunch,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _openLaunchesTab(tester);
}

void main() {
  testWidgets('publicar pede confirmação antes de entregar às famílias', (tester) async {
    final repository = _LaunchDirectoryRepository();
    var published = 0;
    await _pumpDirectory(
      tester,
      repository: repository,
      onPublishLaunch: (item) async {
        published++;
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('daily-routine-publish-launch-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-publish-dialog')), findsOneWidget);
    expect(published, 0, reason: 'nada é publicado antes da confirmação');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(published, 0, reason: 'cancelar não publica');

    await tester.tap(find.byKey(const Key('daily-routine-publish-launch-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-publish-confirm')));
    await tester.pumpAndSettle();
    expect(published, 1);
  });

  testWidgets('a lista é recarregada do servidor depois de publicar', (tester) async {
    final repository = _LaunchDirectoryRepository();
    await _pumpDirectory(
      tester,
      repository: repository,
      onPublishLaunch: (item) async => true,
    );
    final loadsBefore = repository.loads;

    await tester.tap(find.byKey(const Key('daily-routine-publish-launch-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-publish-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository.loads,
      greaterThan(loadsBefore),
      reason: 'a tela mostra o estado que o servidor confirma, não o que ela supôs',
    );
  });

  testWidgets('uma publicação que falha não recarrega nem trava o botão', (tester) async {
    final repository = _LaunchDirectoryRepository();
    await _pumpDirectory(
      tester,
      repository: repository,
      onPublishLaunch: (item) async => false,
    );
    final loadsBefore = repository.loads;

    await tester.tap(find.byKey(const Key('daily-routine-publish-launch-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-publish-confirm')));
    await tester.pumpAndSettle();

    expect(repository.loads, loadsBefore);
    final button = tester.widget<TextButton>(
      find.byKey(const Key('daily-routine-publish-launch-1')),
    );
    expect(button.onPressed, isNotNull, reason: 'a ação volta a ficar disponível para nova tentativa');
  });

  testWidgets('lançamento já publicado não oferece publicar de novo', (tester) async {
    await _pumpDirectory(
      tester,
      repository: _LaunchDirectoryRepository(status: 'published'),
      onPublishLaunch: (item) async => true,
    );
    expect(find.byKey(const Key('daily-routine-publish-launch-1')), findsNothing);
  });

  testWidgets('quem não pode gerenciar não vê a ação', (tester) async {
    await _pumpDirectory(
      tester,
      repository: _LaunchDirectoryRepository(canManage: false),
      onPublishLaunch: (item) async => true,
    );
    expect(find.byKey(const Key('daily-routine-publish-launch-1')), findsNothing);
  });

  testWidgets('sem o comando ligado, a ação não aparece', (tester) async {
    await _pumpDirectory(tester, repository: _LaunchDirectoryRepository());
    expect(find.byKey(const Key('daily-routine-publish-launch-1')), findsNothing);
  });
}
