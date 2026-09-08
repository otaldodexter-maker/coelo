import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito Sans',
    )..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'))).load();
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('context header measures content $width dark=$dark scale=$scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var agendaOpened = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? CoeloTheme.dark : CoeloTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: PrincipalHappensPreviewPage.demo(onOpenAgenda: () => agendaOpened++),
            ),
          );
          await tester.pumpAndSettle();
          final column = find.byKey(const Key('principal-happens-context-column'));
          if (width < CoeloBreakpoints.large.minWidth) {
            expect(column, findsNothing);
          } else {
            expect(column, findsOneWidget);
            final title = find.text('Aniversariantes');
            await tester.ensureVisible(title);
            await tester.pumpAndSettle();
            final action = find
                .descendant(of: column, matching: find.widgetWithText(TextButton, 'Ver todos'))
                .last;
            if (scale == 1) {
              expect(tester.getCenter(title).dy, closeTo(tester.getCenter(action).dy, 1));
            } else {
              expect(
                tester.getRect(action).top,
                greaterThanOrEqualTo(tester.getRect(title).bottom),
              );
            }
            final agenda = find.widgetWithText(TextButton, 'Ver agenda');
            await tester.ensureVisible(agenda);
            await tester.pumpAndSettle();
            await tester.tap(agenda);
            expect(agendaOpened, 1);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
