// C00 regression derived from C07's compact page-header inset reproduction.
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = 'Conversas';
const _subtitle = 'Comunicacao institucional privada e contextual.';

void main() {
  setUpAll(() async {
    final loader = FontLoader(CoeloTypography.fontFamily)
      ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
    await loader.load();
  });

  for (final width in [375.0, 768.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('compact header reserves text and action space $width $brightness $scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var selections = 0;
          Widget app(bool withActions) => MaterialApp(
            theme: CoeloTheme.light,
            darkTheme: CoeloTheme.dark,
            themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: SuperadminShell(
              logout: () async => const LogoutResult.success(),
              title: _title,
              subtitle: _subtitle,
              compactActions: withActions
                  ? [
                      CoeloAdminFileActions(
                        compact: true,
                        actions: [
                          CoeloAdminFileAction(
                            label: 'Importar',
                            icon: Icons.upload_file_outlined,
                            onPressed: () => selections++,
                          ),
                        ],
                      ),
                    ]
                  : const [],
              currentDestination: 'conversations',
              child: const SizedBox.expand(),
            ),
          );

          await tester.pumpWidget(app(false));
          await tester.pumpAndSettle();
          final baselineTitleLeft = tester.getTopLeft(find.text(_title)).dx;
          final baselineSubtitleLeft = tester.getTopLeft(find.text(_subtitle)).dx;
          final brandRect = tester.getRect(find.byKey(const Key('superadmin-brand-logo')));

          await tester.pumpWidget(app(true));
          await tester.pumpAndSettle();
          final titleRect = tester.getRect(find.text(_title));
          final subtitleRect = tester.getRect(find.text(_subtitle));
          final action = find.byKey(const Key('coelo-admin-files-action'));
          final actionRect = tester.getRect(action);

          expect(titleRect.left, closeTo(CoeloSpacing.space5, 0.5));
          expect(titleRect.left, closeTo(baselineTitleLeft, 0.5));
          expect(subtitleRect.left, closeTo(baselineSubtitleLeft, 0.5));
          expect(titleRect.right, lessThanOrEqualTo(actionRect.left));
          expect(subtitleRect.right, lessThanOrEqualTo(actionRect.left));
          expect(actionRect.right, lessThanOrEqualTo(width - CoeloSpacing.space5));
          expect(actionRect.height, greaterThanOrEqualTo(CoeloSize.touchMin));
          expect(tester.getRect(find.byKey(const Key('superadmin-brand-logo'))), brandRect);
          expect(find.byKey(const Key('superadmin-mobile-menu')), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(action);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Importar'));
          await tester.pumpAndSettle();
          expect(selections, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
