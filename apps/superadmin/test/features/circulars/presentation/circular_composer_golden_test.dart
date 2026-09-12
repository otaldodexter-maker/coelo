import 'dart:io';

import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Familia Publicacao (Owner, 11/09/2026 17:19): o compositor de Circular e
/// comparado as referencias `circular-{mobile-375,web-1440}.png` em
/// docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/.
/// O golden congela so o conteudo do conteiner (o shell real e do hospedeiro).
void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('composer follows the Publicacao family at 375 and 1440', (tester) async {
    for (final brightness in Brightness.values) {
      for (final (width, height) in [(375.0, 1320.0), (1440.0, 1100.0)]) {
        await _pump(tester, Size(width, height), brightness: brightness);
        await expectLater(
          find.byKey(const Key('circular-composer-golden-root')),
          matchesGoldenFile('goldens/circular_composer_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  for (final (name, width, height, textScale) in [
    ('375', 375.0, 1320.0, 1.0),
    ('375 text 200', 375.0, 1320.0, 2.0),
    ('1440 text 200', 1440.0, 1100.0, 2.0),
  ]) {
    testWidgets('composer A+ light $name preserves interleaving', (tester) async {
      await _pump(
        tester,
        Size(width, height),
        brightness: Brightness.light,
        textScaler: TextScaler.linear(textScale),
      );
      await expectLater(
        find.byKey(const Key('circular-composer-golden-root')),
        matchesGoldenFile(
          'goldens/circular_composer_light_${width.toInt()}'
          '${textScale == 1 ? '' : '_text_200'}.png',
        ),
      );
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  required Brightness brightness,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final controller = CircularComposerController(
    repository: _Repository(),
    scope: const CircularScope(institutionId: 'institution-1'),
    initialDraft: const CircularDraft(
      id: '',
      title: 'Reunião de pais e responsáveis — 3º ano',
      blocks: [
        CircularTextBlock(
          id: 'text',
          text:
              'Convidamos as famílias para a reunião do 3º ano, com apresentação do plano do semestre e orientações da coordenação.',
        ),
        CircularMediaBlock(id: 'media', assetIds: ['plano-semestre.pdf']),
        CircularQuestionBlock(
          id: 'ack',
          prompt: 'Confirmo ciência desta circular',
          kind: CircularQuestionKind.singleChoice,
          required: true,
          options: [
            CircularQuestionOption(id: 'a', label: 'Estou ciente'),
            CircularQuestionOption(id: 'b', label: 'Preciso de mais informações'),
          ],
        ),
        CircularTextBlock(
          id: 'text-after',
          text: 'Se precisar de apoio, responda a pergunta acima antes da data da reunião.',
        ),
      ],
      audiences: {CircularAudienceKind.families},
    ),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('circular-composer-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: (_) async {},
            onChooseSchedule: () async => null,
            contextLabel: 'Colégio Coelo',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Repository implements CircularRepository {
  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async => const CircularSaveResult(
    id: 'circular-1',
    revisionId: 'revision-1',
    version: 1,
    status: CircularStatus.draft,
  );

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async => const CircularSaveResult(
    id: 'circular-1',
    revisionId: 'revision-2',
    version: 2,
    status: CircularStatus.published,
  );

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      throw UnimplementedError();

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();

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
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
