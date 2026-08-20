import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
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

  Future<void> pumpRoute(WidgetTester tester, FakeNoticeRepository repository) async {
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
}
