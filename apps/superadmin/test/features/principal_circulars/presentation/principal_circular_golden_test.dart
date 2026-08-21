import 'dart:io';

import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_composer_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_reader.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_surfaces.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  for (final configuration in <(double, Brightness)>[
    (375, Brightness.light),
    (768, Brightness.light),
    (1024, Brightness.dark),
    (1440, Brightness.dark),
  ]) {
    final (width, brightness) = configuration;
    testWidgets('composer golden ${width.toInt()} ${brightness.name}', (tester) async {
      final controller = CircularComposerController(
        repository: _Repository(),
        scope: const CircularScope(institutionId: 'institution-1'),
        initialDraft: _draft,
      );
      addTearDown(controller.dispose);
      await _pumpGolden(
        tester,
        size: Size(width, 1000),
        brightness: brightness,
        child: PrincipalCircularComposerPage(
          controller: controller,
          onCancel: () {},
          onPickFiles: () async {},
          onChooseSchedule: () async => DateTime.utc(2026, 8, 25, 12),
        ),
      );
      await expectLater(
        find.byKey(const Key('circular-golden-root')),
        matchesGoldenFile('goldens/circular_composer_${brightness.name}_${width.toInt()}.png'),
      );
    });
  }

  for (final configuration in <(double, Brightness)>[
    (375, Brightness.light),
    (1440, Brightness.dark),
  ]) {
    final (width, brightness) = configuration;
    testWidgets('reader golden ${width.toInt()} ${brightness.name}', (tester) async {
      await _pumpGolden(
        tester,
        size: Size(width, 1000),
        brightness: brightness,
        child: Scaffold(
          body: PrincipalCircularReader(detail: _detail, onSubmit: (_) async {}),
        ),
      );
      await expectLater(
        find.byKey(const Key('circular-golden-root')),
        matchesGoldenFile('goldens/circular_reader_${brightness.name}_${width.toInt()}.png'),
      );
    });
  }

  for (final configuration in <(double, Brightness)>[
    (375, Brightness.light),
    (1440, Brightness.dark),
  ]) {
    final (width, brightness) = configuration;
    testWidgets('profile and feed golden ${width.toInt()} ${brightness.name}', (tester) async {
      await _pumpGolden(
        tester,
        size: Size(width, 760),
        brightness: brightness,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Column(
                    children: [
                      const PrincipalProfileContentTabs(
                        selected: PrincipalProfileContentTab.circulars,
                        onSelected: _ignoreTab,
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                      PrincipalCircularFeedCard(item: _summary, onOpen: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const Key('circular-golden-root')),
        matchesGoldenFile('goldens/circular_profile_feed_${brightness.name}_${width.toInt()}.png'),
      );
    });
  }
}

Future<void> _pumpGolden(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, appChild) => RepaintBoundary(
        key: const Key('circular-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
          child: appChild!,
        ),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void _ignoreTab(PrincipalProfileContentTab _) {}

final _draft = CircularDraft(
  id: 'circular-1',
  title: 'Renovação de matrícula para 2027',
  audiences: const {CircularAudienceKind.families},
  blocks: const [
    CircularTextBlock(
      id: 'text-1',
      text: 'Queridos responsáveis, confirme a renovação para o próximo ano até 20/11.',
    ),
    CircularMediaBlock(id: 'media-1', assetIds: ['asset-1', 'asset-2']),
    CircularQuestionBlock(
      id: 'question-1',
      prompt: 'A matrícula será renovada?',
      kind: CircularQuestionKind.singleChoice,
      required: true,
      options: [
        CircularQuestionOption(id: 'yes', label: 'Sim'),
        CircularQuestionOption(id: 'no', label: 'Não'),
      ],
    ),
  ],
);

final _detail = CircularDetail(
  id: 'circular-1',
  revisionId: 'revision-1',
  title: _draft.title,
  authorName: 'Colégio Coelo',
  contextLabel: 'Ensino Fundamental',
  publishedAt: DateTime.utc(2026, 8, 21),
  status: CircularStatus.published,
  responseState: CircularResponseState.partial,
  blocks: _draft.blocks,
);

final _summary = CircularSummary(
  id: 'circular-1',
  title: _draft.title,
  excerpt: 'Confirme a renovação para o próximo ano até 20/11.',
  authorName: 'Colégio Coelo',
  contextLabel: 'Ensino Fundamental',
  publishedAt: DateTime.utc(2026, 8, 21),
  attachmentCount: 2,
  questionCount: 1,
  responseState: CircularResponseState.partial,
);

final class _Repository implements CircularRepository {
  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      throw UnimplementedError();
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
