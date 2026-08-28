import 'dart:async';

import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_route_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../notices/support/fake_notice_repository.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  PlatformNotice communication(CommunicationType type) => PlatformNotice(
    type: type,
    id: type.name,
    title: type == CommunicationType.forYou ? 'Orientação real' : 'Popup indevido',
    message: 'Conteúdo vindo de Comunicações.',
    priority: NoticePriority.important,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: now.add(const Duration(hours: 1)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Todos',
    behavior: NoticeBehavior.dismissible,
    targetDevice: NoticeTargetDevice.all,
    reach: 1,
  );

  Future<void> pumpRoute(WidgetTester tester, NoticeRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repository,
          supportingData: PrincipalForYouPreviewData.demo,
          now: () => now,
        ),
      ),
    );
  }

  testWidgets('loads Communications through repository and excludes popup notices', (tester) async {
    final repository = FakeNoticeRepository()
      ..seed(communication(CommunicationType.notice))
      ..seed(communication(CommunicationType.forYou));

    await pumpRoute(tester, repository);
    expect(find.byKey(const Key('principal-for-you-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Orientação real'), findsOneWidget);
    expect(find.text('Popup indevido'), findsNothing);
  });

  testWidgets('keeps the useful hub visible when Communications is empty', (tester) async {
    await pumpRoute(tester, FakeNoticeRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-empty')), findsOneWidget);
    expect(find.text('Atalhos essenciais'), findsOneWidget);
  });

  testWidgets('shows a safe error and retries the repository', (tester) async {
    final repository = FakeNoticeRepository()..nextError = const NoticeUnavailableException();
    await pumpRoute(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-error')), findsOneWidget);
    expect(find.text('Não foi possível carregar Para você.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-empty')), findsOneWidget);
  });

  testWidgets('loads B and ignores a late result from repository A', (tester) async {
    final repositoryA = _ControlledNoticeRepository();
    final repositoryB = _ControlledNoticeRepository();
    await pumpRoute(tester, repositoryA);
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repositoryB,
          supportingData: PrincipalForYouPreviewData.demo,
          now: () => now.add(const Duration(minutes: 1)),
        ),
      ),
    );
    await tester.pump();
    expect(repositoryA.calls, 1);
    expect(repositoryB.calls, 1);
    expect(find.byKey(const Key('principal-for-you-loading')), findsOneWidget);

    repositoryB.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsOneWidget);

    repositoryA.page.complete(
      NoticePage(
        items: [
          PlatformNotice(
            type: CommunicationType.forYou,
            id: 'notice-a',
            title: 'Conteúdo A',
            message: 'PII A',
            priority: NoticePriority.important,
            status: NoticeStatus.active,
            startsAt: now.subtract(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 1)),
            audience: NoticeAudience.everyone,
            audienceLabel: 'Todos',
            behavior: NoticeBehavior.dismissible,
            targetDevice: NoticeTargetDevice.all,
            reach: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsOneWidget);
    expect(find.text('Conteúdo A'), findsNothing);
    expect(find.text('PII A'), findsNothing);
  });

  testWidgets('shows unauthorized without a retry action', (tester) async {
    final repository = FakeNoticeRepository()..nextError = const NoticeUnauthorizedException();
    await pumpRoute(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-unauthorized')), findsOneWidget);
    expect(find.text('Acesso não disponível.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(PrincipalForYouPreviewPage), findsNothing);
  });
}

final class _ControlledNoticeRepository implements NoticeRepository {
  final page = Completer<NoticePage>();
  var calls = 0;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) {
    calls++;
    return page.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
