import 'package:coelo_superadmin/features/forms/presentation/operations/forms_media_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development resolves a deterministic protected media fixture', (tester) async {
    var temporaryCopyRequests = 0;

    await _pump(
      tester,
      FormsMediaPage.development(
        assetId: FormsMediaPage.developmentPreviewAssetId,
        onRequestTemporaryCopy: () => temporaryCopyRequests++,
      ),
    );

    expect(find.text('Mídia protegida'), findsOneWidget);
    expect(find.text('Comprovante da atividade'), findsOneWidget);
    expect(find.text('Imagem JPEG'), findsOneWidget);
    expect(find.text('248 KB'), findsOneWidget);
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.byKey(const Key('forms-media-protected-surface')), findsOneWidget);
    expect(find.textContaining('storage_path'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Mostrar prévia'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-media-local-preview')), findsOneWidget);
    expect(find.text('Ocultar prévia'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Preparar cópia temporária'));
    expect(temporaryCopyRequests, 1);
  });

  testWidgets('unknown development asset is not found and returns safely', (tester) async {
    var backCount = 0;
    await _pump(
      tester,
      FormsMediaPage.development(assetId: 'asset-missing', onBack: () => backCount++),
    );

    expect(find.byKey(const Key('forms-media-not-found')), findsOneWidget);
    expect(find.text('Mídia não encontrada'), findsOneWidget);
    await tester.tap(find.text('Voltar aos arquivos'));
    expect(backCount, 1);
  });

  testWidgets('production preserves the media composition and fails closed', (tester) async {
    await _pump(tester, const FormsMediaPage(assetId: FormsMediaPage.developmentPreviewAssetId));

    expect(find.text('Mídia protegida'), findsOneWidget);
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('forms-media-protected-surface')), findsOneWidget);
    expect(find.text('Nenhuma mídia autorizada carregada'), findsOneWidget);
    expect(find.text('Comprovante da atividade'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Preparar cópia temporária'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('development can represent an unavailable resolver', (tester) async {
    await _pump(
      tester,
      const FormsMediaPage.development(
        assetId: FormsMediaPage.developmentPreviewAssetId,
        state: FormsMediaState.unavailable,
      ),
    );

    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(find.text('Comprovante da atividade'), findsNothing);
  });

  testWidgets('protected media remains responsive at 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: CoeloTheme.light,
            home: const FormsMediaPage.development(
              assetId: FormsMediaPage.developmentPreviewAssetId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: page));
  await tester.pumpAndSettle();
}
