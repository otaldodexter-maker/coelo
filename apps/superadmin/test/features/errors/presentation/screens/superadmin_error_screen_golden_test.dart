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
      final pendingApproval = kind == SuperadminErrorKind.conflict;
      final label = pendingApproval
          ? 'renders ${kind.code} in ${themeCase.name} '
                '(sem baseline: goldens 409 aguardam aprovacao nominal)'
          : 'renders ${kind.code} in ${themeCase.name}';
      testWidgets(label, (tester) async {
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
          matchesGoldenFile('goldens/error_${kind.code}_${themeCase.name}.png'),
        );
      },
      // A variante 409 nao tem baseline: os arquivos error_409_light.png e
      // error_409_dark.png nunca existiram. A spec
      // docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md
      // determina que "goldens novos 409 ainda precisam aprovacao nominal, sem
      // rebaseline automatico", entao gera-los aqui seria oficializar uma
      // baseline sem a aprovacao exigida. Marcado como skip com motivo para que
      // a suite reporte S em vez de um vermelho permanente que esconderia
      // regressao real nas outras quatro variantes.
      skip: pendingApproval);
    }
  }
}
