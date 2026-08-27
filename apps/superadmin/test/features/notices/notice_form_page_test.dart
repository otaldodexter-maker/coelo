import 'dart:async';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  testWidgets('validates and advances through the five notice wizard steps on mobile', (
    tester,
  ) async {
    await _pumpForm(tester, const Size(375, 812));

    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.text('Informe o título do aviso para continuar.'), findsOneWidget);
    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-title')), 'Manutenção programada');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-content')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-audience')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-schedule')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('notice-date-Data de início')));
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

Finder _fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

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
