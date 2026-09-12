import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// `notices.publish` e `notices.archive` tinham o defeito de conflito de versão
/// corrigido e a composição verificada por rota, mas nenhuma prova de que a
/// ação de ciclo de vida chega ao repositório PELA ROTA REAL com a versão
/// esperada e uma chave de intenção. Montar a composição não é operar; corrigir
/// o beco sem saída do conflito melhora a ação sem certificá-la.
///
/// Estes casos operam `/notices` pelo router de produção. A prova é o comando
/// que o repositório recebe, não o texto na tela.
void main() {
  testWidgets('publishing from the real route reaches the repository with the seen version', (
    tester,
  ) async {
    final repository = _RecordingNoticeRepository();
    final router = _router(tester, repository: repository);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(repository.pageFetches, 1);

    await _act(tester, 'Publicar');

    // A publicação carrega a versão que o operador realmente viu. Enviar outra
    // coisa transformaria escrita concorrente em sobrescrita silenciosa.
    expect(repository.published.single.expectedVersion, 3);
    expect(repository.published.single.requestId, isNotEmpty);
    expect(repository.published.single.noticeId, 'notice-1');
    expect(repository.statusChanges, isEmpty);
  });

  testWidgets('archiving from the real route asks for cancelled, not for a publish', (
    tester,
  ) async {
    final repository = _RecordingNoticeRepository(status: NoticeStatus.active);
    final router = _router(tester, repository: repository);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // Inativar exige motivo. Abrir e desistir não pode disparar comando: uma
    // comunicação retirada do ar sem registro de motivo é perda de trilha.
    await _act(tester, 'Inativar');
    expect(find.byKey(const Key('notice-inactivate-reason')), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(repository.statusChanges, isEmpty);

    // "Inativar" é como a UI apresenta o arquivamento; o estado de domínio é
    // `cancelled`, e é ele que precisa chegar ao servidor.
    await _act(tester, 'Inativar');
    await tester.enterText(
      find.byKey(const Key('notice-inactivate-reason')),
      'Encerrada a pedido da coordenação.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-inactivate-confirm')));
    await tester.pumpAndSettle();

    expect(repository.statusChanges.single.status, NoticeStatus.cancelled);
    expect(repository.statusChanges.single.expectedVersion, 3);
    expect(repository.statusChanges.single.requestId, isNotEmpty);
    expect(repository.published, isEmpty);
  });

  testWidgets('a lifecycle action is refused when the route has no authorised repository', (
    tester,
  ) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // Sem repositório autorizado o diretório não oferece a ação; esconder o
    // botão não é controle de acesso, mas oferecer o que o servidor negaria
    // seria mentir para o operador antes mesmo da negação.
    expect(find.byTooltip('Ações da comunicação'), findsNothing);
  });
}

Future<void> _act(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Ações da comunicação').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester, {NoticeRepository? repository}) {
  // O diretório só expõe o flyout de ações na composição compacta.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 800);
  addTearDown(tester.view.reset);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    noticeRepository: repository ?? const UnavailableNoticeRepository(),
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  return router;
}

typedef _PublishCall = ({String noticeId, String requestId, int expectedVersion});
typedef _StatusCall = ({
  String noticeId,
  String requestId,
  int expectedVersion,
  NoticeStatus status,
});

final class _RecordingNoticeRepository implements NoticeRepository {
  _RecordingNoticeRepository({this.status = NoticeStatus.draft});

  final NoticeStatus status;
  var pageFetches = 0;
  final List<_PublishCall> published = [];
  final List<_StatusCall> statusChanges = [];

  PlatformNotice get _notice => PlatformNotice(
    id: 'notice-1',
    title: 'Reunião de pais',
    message: 'Confirme presença.',
    priority: NoticePriority.routine,
    audience: NoticeAudience.everyone,
    audienceLabel: 'Todos',
    status: status,
    startsAt: DateTime.utc(2026, 9, 10, 8),
    endsAt: null,
    behavior: NoticeBehavior.dismissible,
    targetDevice: NoticeTargetDevice.all,
    reach: 0,
    managementVersion: 3,
  );

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    pageFetches++;
    return NoticePage(items: [_notice]);
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    published.add((noticeId: notice.id, requestId: requestId, expectedVersion: expectedVersion));
    return _notice;
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) async {
    statusChanges.add((
      noticeId: noticeId,
      requestId: requestId,
      expectedVersion: expectedVersion,
      status: status,
    ));
    return _notice;
  }

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
