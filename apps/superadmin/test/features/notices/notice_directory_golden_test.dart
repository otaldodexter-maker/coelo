import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the communication directory across canonical breakpoints', (tester) async {
    for (final brightness in Brightness.values) {
      for (final size in const [Size(375, 900), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
        await _pumpGolden(tester, size, brightness: brightness);
        await expectLater(
          find.byKey(const Key('communication-directory-golden-root')),
          matchesGoldenFile(
            'goldens/communication_directory_${brightness.name}_${size.width.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('matches the communication directory at 200 percent text', (tester) async {
    for (final size in const [Size(375, 1100), Size(1440, 1100)]) {
      await _pumpGolden(tester, size, textScaler: const TextScaler.linear(2));
      await expectLater(
        find.byKey(const Key('communication-directory-golden-root')),
        matchesGoldenFile('goldens/communication_directory_text_200_${size.width.toInt()}.png'),
      );
    }
  });

  testWidgets('captures empty, no-results, error and unauthorized communication states', (
    tester,
  ) async {
    final empty = _emptyRepository();
    await _pumpGolden(tester, const Size(375, 900), repository: empty);
    await expectLater(
      find.byKey(const Key('communication-directory-golden-root')),
      matchesGoldenFile('goldens/communication_directory_empty_light_375_v4_22.png'),
    );

    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('communication-directory-golden-root')),
      matchesGoldenFile('goldens/communication_directory_no_results_light_375_v4_22.png'),
    );

    await _pumpGolden(
      tester,
      const Size(1440, 900),
      brightness: Brightness.dark,
      repository: const _FailureNoticeRepository(NoticeUnexpectedException()),
    );
    await expectLater(
      find.byKey(const Key('communication-directory-golden-root')),
      matchesGoldenFile('goldens/communication_directory_error_dark_1440_v4_22.png'),
    );

    await _pumpGolden(
      tester,
      const Size(375, 1000),
      repository: const _FailureNoticeRepository(NoticeUnauthorizedException()),
      textScaler: const TextScaler.linear(2),
    );
    await expectLater(
      find.byKey(const Key('communication-directory-golden-root')),
      matchesGoldenFile('goldens/communication_directory_unauthorized_light_375_200_v4_22.png'),
    );
  });
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  NoticeRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('communication-directory-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: NoticeDirectoryPage(
          repository: repository ?? _repository(),
          onCreate: () {},
          onEdit: (_) {},
          enableInlinePreview: true,
          canManageLifecycle: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FakeNoticeRepository _repository() {
  final now = DateTime.utc(2026, 8, 20, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  final repository = FakeNoticeRepository(store: store, now: () => now);
  for (final type in CommunicationType.values) {
    repository.create(
      NoticeDraft(
        type: type,
        title: '${type.label} de exemplo',
        message: 'Comunicação operacional para conferência.',
        priority: type == CommunicationType.notice ? NoticePriority.urgent : NoticePriority.routine,
        audience: NoticeAudience.everyone,
        audienceLabel: 'Global',
        behavior: NoticeBehavior.dismissible,
      ),
    );
  }
  return repository;
}

FakeNoticeRepository _emptyRepository() {
  final now = DateTime.utc(2026, 8, 20, 12);
  return FakeNoticeRepository(
    store: SuperadminPrototypeStore(
      activityController: SuperadminActivityController(now: () => now),
      now: () => now,
    ),
    now: () => now,
  );
}

final class _FailureNoticeRepository implements NoticeRepository {
  const _FailureNoticeRepository(this.error);

  final NoticeRepositoryException error;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
