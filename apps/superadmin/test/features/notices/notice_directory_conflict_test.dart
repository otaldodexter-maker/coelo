import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um conflito de versão diz que o instantâneo local está velho. A mensagem
/// promete "recarregue"; sem recarregar de fato, o operador repetiria a mesma
/// `managementVersion` obsoleta indefinidamente, porque a lista continuaria
/// exibindo a versão antiga. A prova é a contagem de leituras do repositório,
/// não o texto: a recarga é o comportamento, a mensagem é só o aviso.
void main() {
  testWidgets('a version conflict reloads the directory instead of dead-ending', (tester) async {
    final repository = _ConflictingNoticeRepository();
    await _pump(tester, repository);
    expect(repository.pageFetches, 1);

    await _publish(tester);

    expect(repository.publishAttempts, 1);
    expect(find.text('O aviso foi alterado. Recarregue e tente novamente.'), findsOneWidget);
    expect(repository.pageFetches, 2);
  });

  testWidgets('a missing notice also reloads, since the local snapshot is stale', (tester) async {
    final repository = _ConflictingNoticeRepository(failure: const NoticeNotFoundException());
    await _pump(tester, repository);
    expect(repository.pageFetches, 1);

    await _publish(tester);

    expect(repository.pageFetches, 2);
  });

  testWidgets('an unavailable repository reports without reloading', (tester) async {
    final repository = _ConflictingNoticeRepository(failure: const NoticeUnavailableException());
    await _pump(tester, repository);
    expect(repository.pageFetches, 1);

    await _publish(tester);

    // Indisponibilidade não significa instantâneo velho: recarregar aqui só
    // trocaria a mensagem honesta por outra falha.
    expect(repository.pageFetches, 1);
  });
}

Future<void> _publish(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ações da comunicação').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Publicar').last);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, NoticeRepository repository) async {
  // O diretório só expõe o flyout de ações na composição compacta; na tabela
  // ampla as ações vivem noutro afordância.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: NoticeDirectoryPage(repository: repository, canManageLifecycle: true)),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ConflictingNoticeRepository implements NoticeRepository {
  _ConflictingNoticeRepository({this.failure = const NoticeConflictException()});

  final NoticeRepositoryException failure;
  var pageFetches = 0;
  var publishAttempts = 0;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    pageFetches++;
    return NoticePage(
      items: [
        PlatformNotice(
          id: 'notice-1',
          title: 'Reunião de pais',
          message: 'Confirme presença.',
          priority: NoticePriority.routine,
          audience: NoticeAudience.everyone,
          audienceLabel: 'Todos',
          status: NoticeStatus.draft,
          startsAt: DateTime.utc(2026, 9, 10, 8),
          endsAt: null,
          behavior: NoticeBehavior.dismissible,
          targetDevice: NoticeTargetDevice.all,
          reach: 0,
          managementVersion: 1,
        ),
      ],
    );
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) {
    publishAttempts++;
    return Future<PlatformNotice>.error(failure);
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) => Future<PlatformNotice>.error(failure);

  @override
  Future<PlatformNotice> getById(String noticeId) =>
      Future<PlatformNotice>.error(const NoticeNotFoundException());

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) => Future<PlatformNotice>.error(const NoticeUnavailableException());

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async => const NoticeAudienceOptionsPage(items: []);
}
