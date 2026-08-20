import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the communication directory across canonical breakpoints', (tester) async {
    for (final size in const [Size(375, 900), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
      await _pumpGolden(tester, size);
      await expectLater(
        find.byKey(const Key('communication-directory-golden-root')),
        matchesGoldenFile('goldens/communication_directory_${size.width.toInt()}.png'),
      );
    }
  });
}

Future<void> _pumpGolden(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('communication-directory-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
      home: Scaffold(body: NoticeDirectoryPage(repository: _repository())),
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
