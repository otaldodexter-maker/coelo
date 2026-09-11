import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final fontLoader = FontLoader('Nunito Sans')
      ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
    await fontLoader.load();
  });

  for (final themeCase in [
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    for (final kind in SuperadminErrorKind.values) {
      // Goldens 409 aprovados nominalmente pelo Owner em 11/09/2026 (P26 da
      // Rodada 4, ADR 0034 Decisao 15) a partir das imagens candidatas em
      // docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/.
      // `deferred` compartilha o codigo 503 (recurso adiado por decisao) e
      // ganha golden proprio para nao sobrescrever o 503 aprovado.
      final goldenName = kind == SuperadminErrorKind.deferred ? '503_deferred' : kind.code;
      testWidgets('renders $goldenName in ${themeCase.name}', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: themeCase.theme,
            home: SuperadminErrorScreen(kind: kind, onAction: () {}),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(SuperadminErrorScreen),
          matchesGoldenFile('goldens/error_${goldenName}_${themeCase.name}.png'),
        );
      });
    }
  }
}
