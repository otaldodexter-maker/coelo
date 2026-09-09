import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// `hasAuthoritativeMutationCapability` deriva a capacidade de Avisos de
/// `noticeRepository is! UnavailableNoticeRepository`. Estes casos percorrem as
/// rotas reais para provar que a composição chega à tela quando há repositório
/// autorizado, e que ela falha fechada — sem sumir nem abrir formulário mudo —
/// quando não há.
void main() {
  testWidgets('the real notices routes mount the composition with an authorised repository', (
    tester,
  ) async {
    final repository = _StubNoticeRepository();
    final router = _router(tester, repository: repository);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.notices);
    final directory = tester.widget<NoticeDirectoryPage>(find.byType(NoticeDirectoryPage));
    expect(identical(directory.repository, repository), isTrue);
    // Com repositório autorizado o diretório oferece criar e editar.
    expect(directory.onCreate, isNotNull);
    expect(directory.onEdit, isNotNull);
    expect(directory.canManageLifecycle, isTrue);
    expect(repository.pageFetches, greaterThan(0));

    router.go(SuperadminRoutes.noticeCreate);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.noticeCreate);
    final form = tester.widget<NoticeFormPage>(find.byType(NoticeFormPage));
    expect(identical(form.repository, repository), isTrue);
    expect(form.noticeId, isNull);

    router.go('/notices/notice-1/edit');
    await tester.pumpAndSettle();
    final editing = tester.widget<NoticeFormPage>(find.byType(NoticeFormPage));
    // A rota de edição precisa levar o id adiante; sem ele o formulário abriria
    // como criação e uma edição viraria um aviso novo.
    expect(editing.noticeId, 'notice-1');
  });

  testWidgets('without an authorised repository the notices routes fail closed', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // O diretório continua acessível, mas sem oferecer o que o servidor negaria.
    final directory = tester.widget<NoticeDirectoryPage>(find.byType(NoticeDirectoryPage));
    expect(directory.onCreate, isNull);
    expect(directory.onEdit, isNull);
    expect(directory.canManageLifecycle, isFalse);

    router.go(SuperadminRoutes.noticeCreate);
    await tester.pumpAndSettle();
    // A rota existe e responde com indisponibilidade honesta, em vez de montar
    // um formulário que não teria como salvar.
    expect(find.byType(NoticeFormPage), findsNothing);
    expect(
      find.byKey(const Key('production-mutation-capability-unavailable')),
      findsOneWidget,
    );
  });
}

GoRouter _router(WidgetTester tester, {NoticeRepository? repository}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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

final class _StubNoticeRepository implements NoticeRepository {
  var pageFetches = 0;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    pageFetches++;
    return const NoticePage(items: []);
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
