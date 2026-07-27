import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/help_center/presentation/screens/superadmin_help_center_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates, sends and selects session-only help conversations', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Como podemos ajudar?'), findsOne);
    await tester.enterText(
      find.byKey(const Key('superadmin-help-composer-field')),
      'Como cadastro uma institui\u00e7\u00e3o?',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Como cadastro uma institui\u00e7\u00e3o?'), findsWidgets);
    expect(find.textContaining('demonstra\u00e7\u00e3o'), findsOne);
    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    await tester.pumpAndSettle();
    expect(find.text('Como cadastro uma institui\u00e7\u00e3o?'), findsWidgets);

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.enterText(
      find.byKey(const Key('superadmin-help-composer-field')),
      'Onde encontro os planos?',
    );
    await tester.tap(find.byTooltip('Enviar pergunta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Como cadastro uma institui\u00e7\u00e3o?').first);
    await tester.pumpAndSettle();
    expect(find.text('Onde encontro os planos?'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-help-history-panel')),
        matching: find.text('Como cadastro uma institui\u00e7\u00e3o?'),
      ),
      findsNothing,
    );
    expect(find.textContaining('demonstra\u00e7\u00e3o'), findsNothing);
  });

  testWidgets('ignores empty content and keeps Shift+Enter as a new line', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('superadmin-help-composer-field'));
    await tester.enterText(field, '   ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.textContaining('demonstra\u00e7\u00e3o'), findsNothing);

    await tester.enterText(field, 'Primeira linha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final textField = tester.widget<TextField>(field);
    expect(textField.controller?.text, contains('\n'));
    expect(find.textContaining('demonstra\u00e7\u00e3o'), findsNothing);
  });

  testWidgets('uses stacked, compact rail and expanded history layouts', (tester) async {
    for (final width in [375.0, 768.0, 1024.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final expectedKey = width < CoeloBreakpoints.medium.minWidth
          ? const Key('superadmin-help-history-stacked')
          : width < CoeloBreakpoints.expanded.minWidth
          ? const Key('superadmin-help-history-rail')
          : const Key('superadmin-help-history-panel');
      expect(find.byKey(expectedKey), findsOne, reason: '$width');
      expect(tester.takeException(), isNull, reason: '$width');
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('supports dark theme, 200% text and reduced motion without overflow', (tester) async {
    for (final configuration in [
      (size: const Size(1440, 900), mode: ThemeMode.dark, scaler: TextScaler.noScaling),
      (size: const Size(375, 900), mode: ThemeMode.light, scaler: const TextScaler.linear(2)),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = configuration.size;
      await tester.pumpWidget(
        _app(
          themeMode: configuration.mode,
          textScaler: configuration.scaler,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(find.text('Como podemos ajudar?'), findsOne);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Widget _app({
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: themeMode,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
    child: child!,
  ),
  home: const SuperadminHelpCenterPage(logout: _logout),
);
