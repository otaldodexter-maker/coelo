import 'dart:async';

import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_for_you/data/principal_for_you_communications_adapter.dart';
import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../notices/support/fake_notice_repository.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);
  const actorScope = PrincipalForYouAudienceScope(institutionId: 'institution-1');

  PlatformNotice communication(CommunicationType type, {DateTime? endsAt, DateTime? startsAt}) =>
      PlatformNotice(
        type: type,
        id: type.name,
        title: type == CommunicationType.forYou ? 'Orientação real' : 'Popup indevido',
        message: 'Conteúdo vindo de Comunicações.',
        priority: NoticePriority.important,
        status: NoticeStatus.active,
        startsAt: startsAt ?? now.subtract(const Duration(hours: 1)),
        endsAt: endsAt ?? now.add(const Duration(hours: 1)),
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
          audienceScope: actorScope,
          supportingData: PrincipalForYouPreviewData.demo,
          now: () => now,
        ),
      ),
    );
  }

  testWidgets('expires a visible highlight without reopening the hub', (tester) async {
    var current = now;
    final repository = _ControlledNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repository,
          audienceScope: actorScope,
          supportingData: PrincipalForYouPreviewData.demo,
          now: () => current,
        ),
      ),
    );
    repository.page.complete(
      NoticePage(
        items: [
          communication(CommunicationType.forYou, endsAt: now.add(const Duration(seconds: 1))),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsOneWidget);
    current = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsNothing);
    expect(find.byKey(const Key('principal-for-you-empty')), findsOneWidget);
    expect(find.text('Atalhos essenciais'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an authorized active item observes its start boundary', (tester) async {
    var current = now;
    final repository = _ControlledNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repository,
          audienceScope: actorScope,
          supportingData: PrincipalForYouPreviewData.demo,
          now: () => current,
        ),
      ),
    );
    repository.page.complete(
      NoticePage(
        items: [
          communication(CommunicationType.forYou, startsAt: now.add(const Duration(seconds: 1))),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsNothing);
    current = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('old validity timer cannot replace a pending context load', (tester) async {
    var current = now;
    final first = _ControlledNoticeRepository();
    final second = _ControlledNoticeRepository();
    DateTime clock() => current;
    Widget route(NoticeRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalForYouRoutePage(
        repository: repository,
        audienceScope: actorScope,
        supportingData: PrincipalForYouPreviewData.demo,
        now: clock,
      ),
    );
    await tester.pumpWidget(route(first));
    first.page.complete(
      NoticePage(
        items: [
          communication(CommunicationType.forYou, endsAt: now.add(const Duration(seconds: 1))),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(route(second));
    current = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('principal-for-you-loading')), findsOneWidget);
    expect(find.text('Orientação real'), findsNothing);
    second.page.complete(const NoticePage(items: []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-for-you-empty')), findsOneWidget);
    expect(first.calls, 1);
    expect(second.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(hours: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing cancels an armed validity timer', (tester) async {
    final repository = _ControlledNoticeRepository();
    await pumpRoute(tester, repository);
    repository.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    expect(repository.calls, 1);
  });

  testWidgets('an already expired result uses the empty hub state', (tester) async {
    final repository = _ControlledNoticeRepository();
    await pumpRoute(tester, repository);
    repository.page.complete(
      NoticePage(items: [communication(CommunicationType.forYou, endsAt: now)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orientação real'), findsNothing);
    expect(find.byKey(const Key('principal-for-you-empty')), findsOneWidget);
  });

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
          audienceScope: actorScope,
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

  testWidgets('a rebuild with the same authorized scope does not re-read the directory', (
    tester,
  ) async {
    // The route builder constructs the scope and the supporting labels fresh on
    // every build, so comparing them by identity treats each rebuild as a new
    // context: the hub refetched 100 communications and flashed its spinner
    // whenever anything above it rebuilt. Equality here is by value.
    final repository = _ControlledNoticeRepository();
    // One clock instance across builds, as in production: the route does not
    // pass `now`, so the widget keeps the same DateTime.now tear-off.
    DateTime clock() => now;
    Widget routeWith(PrincipalForYouAudienceScope scope) => MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalForYouRoutePage(
        repository: repository,
        audienceScope: scope,
        supportingData: PrincipalForYouPreviewData.contextual(
          id: 'membership-1',
          label: 'Unidade Centro',
          family: 'Instituição Autorizada',
          institution: 'Instituição Autorizada',
        ),
        now: clock,
      ),
    );

    // Built exactly as the route builds it: a fresh instance out of the runtime
    // context, never a const literal, which the compiler would canonicalize and
    // make identical for free.
    PrincipalForYouAudienceScope scopeOf(String groupId) =>
        PrincipalForYouAudienceScope.fromRuntimeContext(
          PrincipalRuntimeContext(
            membershipId: 'membership-1',
            personId: 'person-1',
            institutionId: 'institution-1',
            institutionName: 'Instituição Autorizada',
            roleCode: 'staff',
            scopeKind: 'group',
            unitId: 'unit-1',
            groupId: groupId,
          ),
        );

    await tester.pumpWidget(routeWith(scopeOf('group-1')));
    repository.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    // A different instance carrying the same authorized scope: same actor.
    await tester.pumpWidget(routeWith(scopeOf('group-1')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1, reason: 'the actor did not change, so nothing was re-read');
    expect(find.byKey(const Key('principal-for-you-loading')), findsNothing);
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
  });

  testWidgets('a rebuild with a different authorized scope does re-read', (tester) async {
    final repository = _ControlledNoticeRepository();
    DateTime clock() => now;
    Widget routeWith(PrincipalForYouAudienceScope scope) => MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalForYouRoutePage(
        repository: repository,
        audienceScope: scope,
        supportingData: PrincipalForYouPreviewData.demo,
        now: clock,
      ),
    );

    await tester.pumpWidget(routeWith(const PrincipalForYouAudienceScope(institutionId: 'i-1')));
    repository.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    await tester.pumpWidget(
      routeWith(
        const PrincipalForYouAudienceScope(institutionId: 'i-1', groupId: 'group-outra'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 2, reason: 'a different actor scope must be answered again');
  });

  test('the authorized scope compares by value, not by instance', () {
    const a = PrincipalForYouAudienceScope(
      institutionId: 'i',
      unitId: 'u',
      groupId: 'g',
      personId: 'p',
      roleCode: 'r',
      membershipId: 'm',
    );
    const b = PrincipalForYouAudienceScope(
      institutionId: 'i',
      unitId: 'u',
      groupId: 'g',
      personId: 'p',
      roleCode: 'r',
      membershipId: 'm',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // Every field takes part: none of these may compare equal to `a`.
    expect(a == const PrincipalForYouAudienceScope(institutionId: 'outro'), isFalse);
    expect(
      a ==
          const PrincipalForYouAudienceScope(
            institutionId: 'i',
            unitId: 'u',
            groupId: 'g',
            personId: 'p',
            roleCode: 'r',
            membershipId: 'outro',
          ),
      isFalse,
    );
  });

  testWidgets('never greets a real actor by the fixture name', (tester) async {
    // The hub greeted everyone as "Fernanda", the preview fixture's name.
    // PrincipalRuntimeContext carries the person id and the role, never the
    // person's name, so the real route drops the name instead of inventing one.
    final repository = _ControlledNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repository,
          audienceScope: actorScope,
          supportingData: PrincipalForYouPreviewData.contextual(
            id: 'membership-1',
            label: 'Unidade Centro',
            family: 'Instituição Autorizada',
            institution: 'Instituição Autorizada',
            unit: 'Unidade Centro',
          ),
          now: () => now,
        ),
      ),
    );
    repository.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fernanda'), findsNothing);
    expect(find.text('Bom dia!'), findsOneWidget);
  });

  testWidgets('offers no context switch when there is a single authorized context', (
    tester,
  ) async {
    // The selector refuses to open below two contexts, so both triggers would
    // be controls that answer nothing. The card naming the resolved context
    // stays: that one carries information.
    final repository = _ControlledNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouRoutePage(
          repository: repository,
          audienceScope: actorScope,
          supportingData: PrincipalForYouPreviewData.contextual(
            id: 'membership-1',
            label: 'Unidade Centro',
            family: 'Instituição Autorizada',
            institution: 'Instituição Autorizada',
            unit: 'Unidade Centro',
          ),
          now: () => now,
        ),
      ),
    );
    repository.page.complete(NoticePage(items: [communication(CommunicationType.forYou)]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-context-trigger')), findsNothing);
    expect(find.text('Trocar contexto'), findsNothing);
    expect(find.text('Unidade Centro'), findsWidgets);
  });

  testWidgets('keeps the greeting name and the context switch where they are real', (
    tester,
  ) async {
    // The preview fixture names the actor and carries three contexts, so both
    // survive exactly as the approved composition has them.
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(data: PrincipalForYouPreviewData.demo, embedded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bom dia, Fernanda!'), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-context-trigger')), findsWidgets);
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
