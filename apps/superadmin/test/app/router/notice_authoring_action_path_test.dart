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

/// `notices.publish` e `notices.archive` já tinham prova de que a ação chega ao
/// repositório PELA ROTA REAL. `notices.create` e `notices.edit` não tinham: o
/// assistente é exercido montando a página direto, e a rota só era provada
/// quanto à composição e à falha fechada.
///
/// A diferença importa porque montar a página pula tudo o que o router faz —
/// resolução de parâmetro, escolha de repositório e a decisão entre criar e
/// editar. Uma rota de edição que entregasse a página em modo de CRIAÇÃO
/// passaria em todo teste de página e perderia a comunicação do operador.
void main() {
  testWidgets('creating from the real route reaches the repository without a notice id', (
    tester,
  ) async {
    final repository = _RecordingNoticeRepository();
    final router = _router(tester, repository);

    router.go(SuperadminRoutes.noticeCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await _preencherAssistente(tester, titulo: 'Manutenção programada');
    await _tapVisible(tester, find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    // O que o servidor recebe é a prova. Título e mensagem são os que o
    // operador digitou, e `noticeId` vem NULO: a rota de criação não pode
    // escrever por cima de uma comunicação existente.
    final chamada = repository.saved.single;
    expect(chamada.title, 'Manutenção programada');
    expect(chamada.message, 'O serviço ficará indisponível.');
    expect(chamada.noticeId, isNull);
    expect(chamada.expectedVersion, isNull);
    expect(chamada.requestId, isNotEmpty);
  });

  testWidgets('editing from the real route carries the notice id and the seen version', (
    tester,
  ) async {
    final repository = _RecordingNoticeRepository(existente: true);
    final router = _router(tester, repository);

    router.go('/notices/notice-1/edit');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // A rota resolveu o parâmetro e o assistente abriu a comunicação que
    // existe, e não um rascunho em branco.
    expect(repository.buscasPorId, ['notice-1']);

    await _tapVisible(tester, find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    // Editar carrega o id e a versão que o operador viu. Sem a versão, escrita
    // concorrente vira sobrescrita silenciosa; sem o id, edição vira criação.
    final chamada = repository.saved.single;
    expect(chamada.noticeId, 'notice-1');
    expect(chamada.expectedVersion, 3);
    expect(chamada.requestId, isNotEmpty);
  });

  testWidgets('authoring routes refuse to write without an authorised repository', (tester) async {
    final router = _router(tester, const UnavailableNoticeRepository());

    router.go(SuperadminRoutes.noticeCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // Ausência de botão, sozinha, não prova nada: página em branco também não
    // tem botão. A afirmação tem de ser POSITIVA — a rota desvia para a
    // indisponibilidade declarada e o operador lê o motivo.
    expect(
      router.routeInformationProvider.value.uri.path,
      '/errors/mutation-capability-unavailable',
    );
    expect(find.text('O Coelo está temporariamente indisponível.'), findsOneWidget);

    // E só então a ausência do caminho de escrita passa a significar algo: não
    // existe forma de o operador acreditar que rascunhou alguma coisa.
    expect(find.text('Salvar rascunho'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _preencherAssistente(WidgetTester tester, {required String titulo}) async {
  await tester.enterText(_fieldIn(const Key('notice-title')), titulo);
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
  await tester.pumpAndSettle();
  await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
  await tester.pumpAndSettle();
}

Finder _fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
}

GoRouter _router(WidgetTester tester, NoticeRepository repository) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 800);
  addTearDown(tester.view.reset);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    noticeRepository: repository,
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  return router;
}

typedef _SaveCall = ({
  String? noticeId,
  String requestId,
  int? expectedVersion,
  String title,
  String message,
});

final class _RecordingNoticeRepository implements NoticeRepository {
  _RecordingNoticeRepository({this.existente = false});

  final bool existente;
  final List<_SaveCall> saved = [];
  final List<String> buscasPorId = [];

  PlatformNotice get _notice => PlatformNotice(
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
    managementVersion: 3,
  );

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async =>
      NoticePage(items: existente ? [_notice] : const []);

  @override
  Future<PlatformNotice> getById(String noticeId) async {
    buscasPorId.add(noticeId);
    return _notice;
  }

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    saved.add((
      noticeId: noticeId,
      requestId: requestId,
      expectedVersion: expectedVersion,
      title: draft.title,
      message: draft.message,
    ));
    return _notice;
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) => Future<PlatformNotice>.error(const NoticeUnavailableException());

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
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
