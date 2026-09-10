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

  testWidgets('a successful action keeps the operator on the page they were on', (tester) async {
    final repository = _PagedNoticeRepository();
    await _pump(tester, repository);
    expect(find.text('Aviso pagina 1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Aviso pagina 2'), findsWidgets);

    await _publish(tester);
    await tester.pumpAndSettle();

    // Uma acao bem sucedida nao e motivo para devolver o operador ao inicio.
    // Resetar aqui obrigaria a navegar de volta depois de CADA acao: operar
    // tres avisos da pagina 3 viraria tres viagens. O reset continua certo
    // para conflito e ausencia, onde o instantaneo inteiro esta velho.
    expect(find.text('Aviso pagina 2'), findsWidgets);
    expect(find.text('Aviso pagina 1'), findsNothing);
  });


  testWidgets('acting on the last item of a page leaves an honest state, not a dead end', (
    tester,
  ) async {
    // Borda da propria correcao: se a acao tirar o item do conjunto, reler a
    // pagina corrente devolve uma pagina vazia. Isso precisa parecer vazio de
    // verdade e continuar navegavel, em vez de virar beco.
    final repository = _PagedNoticeRepository(emptyAfterAction: true);
    await _pump(tester, repository);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Aviso pagina 2'), findsWidgets);

    await _publish(tester);
    await tester.pumpAndSettle();

    // A pagina esvaziou, e o rodape de paginacao so existe junto do conteudo:
    // ficar ali seria um beco, sem itens e sem caminho de volta. O operador cai
    // no inicio, que e o unico lugar garantidamente navegavel — e continua
    // vendo conteudo, em vez de uma tela vazia sem saida.
    expect(find.text('Aviso pagina 2'), findsNothing);
    expect(find.text('Aviso pagina 1'), findsWidgets);
    expect(tester.takeException(), isNull);
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

/// Duas paginas reais, para distinguir recarregar a pagina corrente de voltar
/// ao inicio. O cursor decide qual pagina o repositorio devolve.
final class _PagedNoticeRepository implements NoticeRepository {
  _PagedNoticeRepository({this.emptyAfterAction = false});

  final bool emptyAfterAction;
  var _acted = false;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    final onSecondPage = query.cursorId != null;
    if (onSecondPage && _acted) return const NoticePage(items: []);
    return NoticePage(
      items: [
        PlatformNotice(
          id: onSecondPage ? 'notice-2' : 'notice-1',
          title: onSecondPage ? 'Aviso pagina 2' : 'Aviso pagina 1',
          message: 'Confirme presenca.',
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
      nextCursorId: onSecondPage ? null : 'notice-1',
      nextCursorOccurredAt: onSecondPage ? null : DateTime.utc(2026, 9, 10, 8),
    );
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    if (emptyAfterAction) _acted = true;
    return notice;
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) => Future<PlatformNotice>.error(const NoticeUnavailableException());

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
