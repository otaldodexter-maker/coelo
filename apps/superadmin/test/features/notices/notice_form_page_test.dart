import 'dart:async';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  for (final change in ['repository-denied', 'notice-id', 'dispose']) {
    testWidgets('form preview is removed after $change context change', (tester) async {
      final repository = FakeNoticeRepository()
        ..seed(_notice('notice-a', 'Prévia privada A'))
        ..seed(_notice('notice-b', 'Comunicação B'));
      final denied = _DeniedLoadNoticeRepository();
      Widget host(bool changed) => MaterialApp(
        home: Scaffold(
          body: changed && change == 'dispose'
              ? const Text('Origem')
              : NoticeFormPage(
                  repository: changed && change == 'repository-denied' ? denied : repository,
                  noticeId: changed && change == 'notice-id' ? 'notice-b' : 'notice-a',
                ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      for (var step = 0; step < 4; step++) {
        await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
      }
      await _tapVisible(tester, find.text('Ver popup final'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notice-preview-dialog')), findsOneWidget);
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notice-preview-dialog')), findsNothing);
      expect(find.text('Prévia privada A'), findsNothing);
      if (change == 'repository-denied') expect(find.text('Sem permissão'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy image feedback explains unavailability and allows text conversion', (
    tester,
  ) async {
    final repository = FakeNoticeRepository();
    repository.seed(
      _notice(
        'image-notice',
        'Aviso com imagem',
      ).copyWith(contentFormat: NoticeContentFormat.image),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeFormPage(repository: repository, noticeId: 'image-notice'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    const message =
        'Este aviso usa uma imagem legada. '
        'Imagens ainda não estão disponíveis neste formulário. '
        'Converta para texto antes de salvar ou publicar.';
    expect(find.text(message), findsOneWidget);
    expect(find.textContaining('Supabase Storage'), findsNothing);
    await _tapVisible(tester, find.text('Converter para texto'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    expect(find.text('Converter para texto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in [NoticeStatus.scheduled, NoticeStatus.active]) {
    testWidgets('publication feedback follows the server status $status', (tester) async {
      final repository = _PublicationResultRepository(status);
      PlatformNotice? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoticeFormPage(
              repository: repository,
              noticeId: 'notice-publish',
              onSaved: (notice) => saved = notice,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 4; step++) {
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Publicar aviso'));
      await tester.pumpAndSettle();
      expect(saved?.status, status);
      expect(saved?.managementVersion, 2);
      expect(
        find.text(
          status == NoticeStatus.scheduled
              ? 'Publicação agendada: Comunicação em fila'
              : 'Aviso publicado: Comunicação em fila',
        ),
        findsOneWidget,
      );
      if (status == NoticeStatus.scheduled) {
        expect(find.text('Aviso publicado: Comunicação em fila'), findsNothing);
      }
    });
  }

  testWidgets('validates and advances through the five notice wizard steps on mobile', (
    tester,
  ) async {
    await _pumpForm(tester, const Size(375, 812));

    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.text('Informe o título do aviso para continuar.'), findsOneWidget);
    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-title')), 'Manutenção programada');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-content')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-audience')), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-schedule')), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-review')), findsOneWidget);
    expect(find.text('Manutenção programada'), findsWidgets);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(const Key('notice-metrics-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the single-date mode for notice schedule fields', (tester) async {
    await _pumpForm(tester, const Size(375, 812));

    await tester.enterText(_fieldIn(const Key('notice-title')), 'Manutenção programada');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    await _tapVisible(tester, find.byKey(const Key('notice-date-Data de início')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CoeloDateRangePicker>(find.byType(CoeloDateRangePicker));
    expect(picker.selectionMode, CoeloDateSelectionMode.single);
  });

  testWidgets('has no layout exception at mobile and desktop widths', (tester) async {
    for (final size in [const Size(375, 812), const Size(1440, 900)]) {
      await _pumpForm(tester, size);

      expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'layout at ${size.width}px');
    }
  });

  testWidgets('route A cannot overwrite route B when notice loads finish out of order', (
    tester,
  ) async {
    final repository = _OrderedNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeFormPage(repository: repository, noticeId: 'notice-a'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeFormPage(repository: repository, noticeId: 'notice-b'),
        ),
      ),
    );
    await tester.pump();

    expect(repository.requests.keys, contains('notice-b'));
    repository.requests['notice-b']!.complete(_notice('notice-b', 'Comunicação B'));
    await tester.pump();
    expect(find.text('Comunicação B'), findsWidgets);

    repository.requests['notice-a']!.complete(_notice('notice-a', 'Comunicação A'));
    await tester.pump();
    expect(find.text('Comunicação B'), findsWidgets);
    expect(find.text('Comunicação A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending save from route A cannot call back after swapping to route B', (
    tester,
  ) async {
    final repository = _SwapDuringSaveNoticeRepository();
    var savedCount = 0;
    Widget page(String id) => MaterialApp(
      home: Scaffold(
        body: NoticeFormPage(repository: repository, noticeId: id, onSaved: (_) => savedCount++),
      ),
    );

    await tester.pumpWidget(page('notice-a'));
    await tester.pumpAndSettle();
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();

    await tester.pumpWidget(page('notice-b'));
    await tester.pumpAndSettle();
    repository.pendingSave.complete(_notice('notice-a', 'Comunicação A'));
    await tester.pump();

    expect(savedCount, 0);
    expect(find.text('Comunicação B'), findsWidgets);
    expect(find.text('Comunicação A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transient load failure shows no wizard actions and retries in place', (
    tester,
  ) async {
    final repository = _RetryLoadNoticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeFormPage(repository: repository, noticeId: 'notice-retry'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notice-form-load-failure')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsNothing);
    expect(find.byType(SuperadminFormActionFooter), findsNothing);
    expect(find.text('Salvar rascunho'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.loads, 2);
    expect(find.text('Comunicação recuperada'), findsWidgets);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unauthorized load stays state-only without retry or mutation footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeFormPage(
            repository: _DeniedLoadNoticeRepository(),
            noticeId: 'notice-denied',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(SuperadminFormStepNavigation), findsNothing);
    expect(find.byType(SuperadminFormActionFooter), findsNothing);
    expect(find.text('Salvar rascunho'), findsNothing);
  });
}

PlatformNotice _notice(String id, String title) => PlatformNotice(
  id: id,
  title: title,
  message: 'Mensagem $title',
  priority: NoticePriority.important,
  status: NoticeStatus.draft,
  startsAt: DateTime(2026, 8, 27),
  endsAt: null,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.confirmation,
  targetDevice: NoticeTargetDevice.all,
  reach: 0,
);

final class _OrderedNoticeRepository implements NoticeRepository {
  final requests = <String, Completer<PlatformNotice>>{};

  @override
  Future<PlatformNotice> getById(String noticeId) =>
      (requests[noticeId] = Completer<PlatformNotice>()).future;

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async => const NoticeAudienceOptionsPage(items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PublicationResultRepository implements NoticeRepository {
  _PublicationResultRepository(this.resultStatus) {
    delegate.seed(_notice('notice-publish', 'Comunicação em fila'));
  }
  final NoticeStatus resultStatus;
  final delegate = FakeNoticeRepository();

  @override
  Future<PlatformNotice> getById(String id) => delegate.getById(id);

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async => const NoticeAudienceOptionsPage(items: []);

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) => delegate.saveDraft(
    draft,
    requestId: requestId,
    noticeId: noticeId,
    expectedVersion: expectedVersion,
  );

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async => notice.copyWith(status: resultStatus, managementVersion: expectedVersion + 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SwapDuringSaveNoticeRepository implements NoticeRepository {
  final pendingSave = Completer<PlatformNotice>();

  @override
  Future<PlatformNotice> getById(String noticeId) async =>
      _notice(noticeId, noticeId == 'notice-a' ? 'Comunicação A' : 'Comunicação B');

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async => const NoticeAudienceOptionsPage(items: []);

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) => pendingSave.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RetryLoadNoticeRepository implements NoticeRepository {
  int loads = 0;

  @override
  Future<PlatformNotice> getById(String noticeId) async {
    loads++;
    if (loads == 1) throw const NoticeUnavailableException();
    return _notice(noticeId, 'Comunicação recuperada');
  }

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async => const NoticeAudienceOptionsPage(items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DeniedLoadNoticeRepository implements NoticeRepository {
  @override
  Future<PlatformNotice> getById(String noticeId) async =>
      throw const NoticeUnauthorizedException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
}

Future<void> _pumpForm(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final now = DateTime.utc(2026, 8, 6, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  final repository = FakeNoticeRepository(store: store, now: () => now);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NoticeFormPage(repository: repository)),
    ),
  );
  await tester.pump();
}
