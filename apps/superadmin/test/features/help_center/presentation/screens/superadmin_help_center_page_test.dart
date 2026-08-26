import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/help_center/presentation/screens/superadmin_help_center_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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

  testWidgets('uses the institution responsive content insets', (tester) async {
    for (final configuration in [
      (width: 375.0, inset: CoeloSpacing.space4),
      (width: 768.0, inset: CoeloSpacing.space6),
      (width: 1600.0, inset: CoeloSpacing.space10),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(configuration.width, 900);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final contentInsets = tester.widget<Padding>(
        find.byKey(const Key('superadmin-help-content-insets')),
      );
      expect(contentInsets.padding, EdgeInsets.all(configuration.inset));
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('collapses and expands the desktop conversation history', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-help-history-panel')), findsOne);
    await tester.tap(find.byTooltip('Recolher histórico'));
    await tester.pumpAndSettle();

    final collapsed = find.byKey(const Key('superadmin-help-history-collapsed'));
    expect(collapsed, findsOne);
    expect(tester.getSize(collapsed).width, 88);

    await tester.tap(find.byTooltip('Expandir histórico'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-help-history-panel')), findsOne);
  });

  testWidgets('keeps the standard send action outside the writing field', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('superadmin-help-composer-field'));
    final send = find.ancestor(
      of: find.byIcon(Icons.send_rounded),
      matching: find.byType(IconButton),
    );
    final colors = Theme.of(tester.element(field)).colorScheme;
    var button = tester.widget<IconButton>(send);

    expect(button.onPressed, isNull);
    expect(button.style?.backgroundColor?.resolve({WidgetState.disabled}), colors.primaryContainer);
    expect(
      button.style?.foregroundColor?.resolve({WidgetState.disabled}),
      colors.onPrimaryContainer,
    );
    expect(tester.getRect(send).left, greaterThan(tester.getRect(field).right));

    await tester.enterText(field, 'Como funciona o Coelo?');
    await tester.pump();
    button = tester.widget<IconButton>(send);
    expect(button.onPressed, isNotNull);
    expect(button.style?.backgroundColor?.resolve({}), colors.primary);
    expect(
      tester.widget<Icon>(find.descendant(of: send, matching: find.byType(Icon))).icon,
      Icons.send_rounded,
    );
  });

  testWidgets(
    'uses approved brand states for the expanded new conversation action in both themes',
    (tester) async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1024, 900);
        await tester.pumpWidget(_app(themeMode: themeMode));
        await tester.pumpAndSettle();

        final theme = Theme.of(
          tester.element(find.byKey(const Key('superadmin-help-composer-field'))),
        );
        final colors = theme.colorScheme;
        final actionColors = theme.extension<CoeloActionColors>()!;
        final newConversation = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Nova conversa'),
        );
        expect(newConversation.style?.backgroundColor?.resolve({}), colors.primary);
        expect(
          newConversation.style?.backgroundColor?.resolve({WidgetState.hovered}),
          actionColors.primaryHover,
        );
        expect(
          newConversation.style?.backgroundColor?.resolve({WidgetState.focused}),
          actionColors.primaryHover,
        );
        expect(
          newConversation.style?.backgroundColor?.resolve({WidgetState.pressed}),
          actionColors.primaryPressed,
        );
        expect(newConversation.style?.foregroundColor?.resolve({}), colors.onPrimary);
        expect(
          newConversation.style?.overlayColor?.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
      }
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
    },
  );

  testWidgets('uses approved brand states for collapsed new conversation action in both themes', (
    tester,
  ) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(768, 900);
      await tester.pumpWidget(_app(themeMode: themeMode));
      await tester.pumpAndSettle();

      final theme = Theme.of(
        tester.element(find.byKey(const Key('superadmin-help-composer-field'))),
      );
      final colors = theme.colorScheme;
      final actionColors = theme.extension<CoeloActionColors>()!;
      final newConversationFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Nova conversa',
      );
      final newConversation = tester.widget<IconButton>(newConversationFinder);

      expect(tester.getSize(newConversationFinder), const Size.square(CoeloSize.touchMin));
      expect(newConversation.style?.backgroundColor?.resolve({}), colors.primary);
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.hovered}),
        actionColors.primaryHover,
      );
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.focused}),
        actionColors.primaryHover,
      );
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.pressed}),
        actionColors.primaryPressed,
      );
      expect(newConversation.style?.foregroundColor?.resolve({}), colors.onPrimary);
      expect(
        newConversation.style?.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('uses approved brand states for stacked new conversation action in both themes', (
    tester,
  ) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 900);
      await tester.pumpWidget(_app(themeMode: themeMode));
      await tester.pumpAndSettle();

      final theme = Theme.of(
        tester.element(find.byKey(const Key('superadmin-help-composer-field'))),
      );
      final colors = theme.colorScheme;
      final actionColors = theme.extension<CoeloActionColors>()!;
      final newConversationFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Nova conversa',
      );
      final newConversation = tester.widget<IconButton>(newConversationFinder);

      expect(tester.getSize(newConversationFinder), const Size.square(CoeloSize.touchMin));
      expect(newConversation.style?.backgroundColor?.resolve({}), colors.primary);
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.hovered}),
        actionColors.primaryHover,
      );
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.focused}),
        actionColors.primaryHover,
      );
      expect(
        newConversation.style?.backgroundColor?.resolve({WidgetState.pressed}),
        actionColors.primaryPressed,
      );
      expect(newConversation.style?.foregroundColor?.resolve({}), colors.onPrimary);
      expect(
        newConversation.style?.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('keeps tonal suggestions and the send icon free of a gray overlay', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final colors = Theme.of(
      tester.element(find.byKey(const Key('superadmin-help-composer-field'))),
    ).colorScheme;

    final suggestion = tester.widget<ActionChip>(
      find.ancestor(
        of: find.text('Como cadastro uma instituição?'),
        matching: find.byType(ActionChip),
      ),
    );
    expect(suggestion.color?.resolve({}), colors.primaryContainer);
    expect(suggestion.color?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(suggestion.color?.resolve({WidgetState.focused}), colors.primaryContainer);
    expect(suggestion.labelStyle?.color, colors.onPrimaryContainer);

    final sendFinder = find.ancestor(
      of: find.byIcon(Icons.send_rounded),
      matching: find.byType(IconButton),
    );
    final send = tester.widget<IconButton>(sendFinder);
    expect(send.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(tester.getSize(sendFinder), const Size.square(CoeloSize.touchMin));
    expect(tester.getSize(find.byIcon(Icons.send_rounded)), const Size.square(CoeloSize.iconMd));
    expect(find.descendant(of: sendFinder, matching: find.byType(Transform)), findsNothing);
  });

  testWidgets('uses the canonical mobile history flyout with safe focus and viewport', (
    tester,
  ) async {
    const question = 'Como cadastro uma institui\u00e7\u00e3o?';
    const secondQuestion = 'Onde encontro os planos?';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('superadmin-help-composer-field')), question);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.enterText(find.byKey(const Key('superadmin-help-composer-field')), secondQuestion);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final flyoutFinder = find.descendant(
      of: find.byKey(const Key('superadmin-help-history-stacked')),
      matching: find.byWidgetPredicate((widget) => widget is CoeloAdminFlyout<String>),
    );
    expect(flyoutFinder, findsOneWidget);

    final triggerFinder = find.descendant(of: flyoutFinder, matching: find.byType(TextButton));
    final triggerFocus = _focusNodeFor(tester, triggerFinder);
    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final itemFinder = find.widgetWithText(MenuItemButton, question);
    expect(itemFinder, findsOneWidget);
    final selectedItemFinder = find.widgetWithText(MenuItemButton, secondQuestion);
    expect(
      find.ancestor(
        of: selectedItemFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
    final itemRect = tester.getRect(itemFinder);
    expect(itemRect.left, greaterThanOrEqualTo(CoeloSpacing.space2));
    expect(itemRect.right, lessThanOrEqualTo(375 - CoeloSpacing.space2));
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(itemFinder, findsNothing);
    expect(triggerFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.text(question).last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: triggerFinder, matching: find.text(question)), findsOneWidget);
    expect(find.descendant(of: triggerFinder, matching: find.text(secondQuestion)), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
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
      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason:
            '${configuration.size}: '
            '${exception is FlutterError ? exception.toStringDeep() : exception}',
      );
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

FocusNode _focusNodeFor(WidgetTester tester, Finder target) {
  final targetElement = tester.element(target);
  return FocusManager.instance.rootScope.descendants.firstWhere((node) {
    final context = node.context;
    if (context is! Element) return false;
    if (context == targetElement) return true;
    var belongsToTarget = false;
    context.visitAncestorElements((element) {
      if (element != targetElement) return true;
      belongsToTarget = true;
      return false;
    });
    return belongsToTarget;
  });
}

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
