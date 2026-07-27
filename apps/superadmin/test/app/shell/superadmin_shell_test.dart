import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_activity_center.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('renders appearance previews in light and dark, expanded and collapsed', (
    tester,
  ) async {
    for (final configuration in [
      (
        preview: superadminExpandedFooterLightPreview,
        size: const Size(260, 180),
        brightness: Brightness.light,
      ),
      (
        preview: superadminExpandedFooterDarkPreview,
        size: const Size(260, 180),
        brightness: Brightness.dark,
      ),
      (
        preview: superadminCollapsedFooterLightPreview,
        size: const Size(88, 220),
        brightness: Brightness.light,
      ),
      (
        preview: superadminCollapsedFooterDarkPreview,
        size: const Size(88, 220),
        brightness: Brightness.dark,
      ),
    ]) {
      await tester.binding.setSurfaceSize(configuration.size);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());

      expect(find.byKey(const Key('superadmin-onboarding-egg')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-theme-carrot')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-theme-mode-control')), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byKey(const Key('superadmin-theme-mode-control')))).brightness,
        configuration.brightness,
      );
      expect(
        MediaQuery.of(
          tester.element(find.byKey(const Key('superadmin-theme-mode-control'))),
        ).disableAnimations,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('renders the tour submenu preview in light and dark', (tester) async {
    for (final configuration in [
      (preview: superadminTourSubmenuLightPreview, brightness: Brightness.light),
      (preview: superadminTourSubmenuDarkPreview, brightness: Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(const Size(260, 260));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('superadmin-tour-screen')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-tour-menu')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-tour-complete')), findsOneWidget);
      final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      final colors = Theme.of(tester.element(find.byType(MenuAnchor))).colorScheme;
      expect(anchor.style?.elevation?.resolve({}), 4);
      final screenItem = tester.widget<MenuItemButton>(
        find.byKey(const Key('superadmin-tour-screen')),
      );
      expect(
        screenItem.style?.backgroundColor?.resolve({WidgetState.hovered}),
        colors.primaryContainer,
      );
      expect(screenItem.style?.foregroundColor?.resolve({WidgetState.focused}), colors.primary);
      expect(
        Theme.of(tester.element(find.byType(MenuAnchor))).brightness,
        configuration.brightness,
      );
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('matches the light and dark egg and carrot goldens', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (name: 'light', preview: superadminExpandedFooterLightPreview, size: const Size(260, 180)),
      (name: 'dark', preview: superadminExpandedFooterDarkPreview, size: const Size(260, 180)),
      (
        name: 'collapsed_light',
        preview: superadminCollapsedFooterLightPreview,
        size: const Size(88, 220),
      ),
      (
        name: 'collapsed_dark',
        preview: superadminCollapsedFooterDarkPreview,
        size: const Size(88, 220),
      ),
    ]) {
      tester.view.physicalSize = configuration.size;
      await tester.pumpWidget(configuration.preview());

      await expectLater(
        find.byKey(const Key('superadmin-footer-preview')),
        matchesGoldenFile('goldens/superadmin_footer_illustrations_${configuration.name}.png'),
      );
    }
  });

  testWidgets('shows the approved floating hierarchical navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());

    expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-home')), findsOneWidget);

    for (final label in ['Estrutura', 'Acessos', 'Operação', 'Comunicação', 'Governança']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in ['Unidades', 'Grupos']) {
      expect(find.text(label), findsOneWidget);
    }

    for (final entry in {
      'access': ['Pessoas', 'Usuários internos', 'Perfis e permissões'],
      'operations': ['Planos', 'Importações'],
      'communication': ['Convites', 'Avisos'],
      'governance': ['Suporte', 'Auditoria'],
    }.entries) {
      await tester.tap(find.byKey(Key('superadmin-navigation-section-${entry.key}')));
      await tester.pumpAndSettle();
      for (final label in entry.value) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byKey(Key('superadmin-navigation-section-${entry.key}')));
      await tester.pumpAndSettle();
    }

    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('superadmin-brand-divider')),
              matching: find.byType(Divider),
            ),
          )
          .width,
      lessThan(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width),
    );
  });

  testWidgets('brand and Home destination open Home without router coupling', (tester) async {
    final destinations = <String>[];
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp(onDestinationSelected: destinations.add));

    expect(find.bySemanticsLabel('Ir para Home'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('superadmin-brand-home'))).height,
      greaterThanOrEqualTo(CoeloSize.touchMin),
    );

    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    await tester.tap(find.byKey(const Key('superadmin-navigation-home')));
    expect(destinations, ['home', 'home']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(destinations, ['home', 'home', 'home', 'home']);

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-brand-home')),
        matching: find.text('Superadmin'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    expect(destinations.last, 'home');

    destinations.clear();
    await tester.pumpWidget(
      _shellApp(currentDestination: 'home', onDestinationSelected: destinations.add),
    );
    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    await tester.tap(find.byKey(const Key('superadmin-navigation-home')));
    expect(destinations, isEmpty);
    semantics.dispose();
  });

  testWidgets('keeps expansion disabled for a partial generic navigation callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      onDestinationSelected: (_) {},
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: shell));

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();

    final expand = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.open_in_full));
    expect(expand.tooltip, 'Expandir conversas indisponível nesta tela');
    expect(expand.onPressed, isNull);
  });

  testWidgets('expands through the specific conversations capability', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var expansions = 0;

    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      onDestinationSelected: (_) {},
      onOpenConversations: () => expansions += 1,
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: shell));

    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();

    final expand = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.open_in_full));
    expect(expand.tooltip, 'Expandir conversas');
    expect(expand.onPressed, isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.open_in_full));
    expect(expansions, 1);
  });

  testWidgets('keeps the legacy visibility default false', (tester) async {
    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      child: const SizedBox.expand(),
    );

    // ignore: deprecated_member_use_from_same_package
    expect(shell.showChatLauncher, isFalse);
  });

  testWidgets('keeps the legacy visibility flag without hiding the global launcher', (
    tester,
  ) async {
    // ignore: deprecated_member_use_from_same_package
    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      showChatLauncher: false,
      child: const SizedBox.expand(),
    );
    // ignore: deprecated_member_use_from_same_package
    expect(shell.showChatLauncher, isFalse);
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: shell));

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
  });

  testWidgets('starts Home with Structure collapsed and opens the active section contextually', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp(currentDestination: 'home'));

    expect(find.byKey(const Key('superadmin-navigation-home')), findsOneWidget);
    expect(find.text('Estrutura'), findsOneWidget);
    expect(find.text('Unidades'), findsNothing);
    expect(find.text('Grupos'), findsNothing);

    await tester.pumpWidget(_shellApp(currentDestination: 'institutions'));
    await tester.pump();

    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Grupos'), findsOneWidget);
  });

  testWidgets('keeps the Superadmin brand background transparent in every interaction state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final inkWell = tester.widget<InkWell>(find.byKey(const Key('superadmin-brand-home')));

    for (final states in [
      <WidgetState>{WidgetState.hovered},
      <WidgetState>{WidgetState.focused},
      <WidgetState>{WidgetState.pressed},
    ]) {
      expect(inkWell.overlayColor?.resolve(states), Colors.transparent);
    }
  });

  testWidgets('mobile brand closes the drawer before opening Home', (tester) async {
    final destinations = <String>[];
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp(onDestinationSelected: destinations.add));

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    await tester.pumpAndSettle();

    expect(destinations, ['home']);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('collapses to an icon rail and opens a section flyout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    expect(find.text('Estrutura'), findsNothing);

    final activeSection = tester.widget<IconButton>(
      find.byKey(const Key('superadmin-navigation-section-structure')),
    );
    final colors = CoeloTheme.light.colorScheme;
    final actionColors = CoeloTheme.light.extension<CoeloActionColors>()!;
    expect(activeSection.style?.backgroundColor?.resolve({}), colors.primary);
    expect(
      activeSection.style?.backgroundColor?.resolve({WidgetState.hovered}),
      actionColors.primaryHover,
    );
    expect(activeSection.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    final flyout = find.byKey(const Key('superadmin-navigation-flyout-structure'));
    expect(flyout, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final triggerRect = tester.getRect(
      find.byKey(const Key('superadmin-navigation-section-structure')),
    );
    final sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    final flyoutRect = tester.getRect(
      find.byKey(const Key('superadmin-navigation-flyout-structure')),
    );
    const flyoutSurfacePadding = CoeloSpacing.space2;
    expect(flyoutRect.left, greaterThanOrEqualTo(triggerRect.right));
    expect(flyoutRect.left, sidebarRect.right + CoeloSpacing.space1);
    expect(flyoutRect.left - flyoutSurfacePadding, sidebarRect.right - CoeloSpacing.space1);
    expect((flyoutRect.top - triggerRect.top).abs(), lessThanOrEqualTo(CoeloSpacing.space2));
    final navigationAnchor = tester.widget<MenuAnchor>(
      find
          .ancestor(
            of: find.byKey(const Key('superadmin-navigation-section-structure')),
            matching: find.byType(MenuAnchor),
          )
          .first,
    );
    expect(
      navigationAnchor.alignmentOffset,
      const Offset(CoeloSpacing.space1, -CoeloSpacing.space1),
    );
    expect(navigationAnchor.style?.elevation?.resolve({}), 4);
    expect(navigationAnchor.style?.padding?.resolve({}), const EdgeInsets.all(CoeloSpacing.space2));
    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Grupos'), findsOneWidget);
    final units = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-navigation-units')),
    );
    final institutions = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-navigation-institutions')),
    );
    expect(
      institutions.style?.backgroundColor?.resolve({}),
      colors.primary.withValues(alpha: 0.10),
    );
    expect(
      institutions.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primary.withValues(alpha: 0.16),
    );
    expect(institutions.style?.foregroundColor?.resolve({}), colors.primary);
    expect(institutions.style?.iconColor?.resolve({}), colors.primary);
    expect(units.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(units.style?.backgroundColor?.resolve({WidgetState.pressed}), colors.primaryContainer);
    expect(units.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.primary);
    expect(units.style?.foregroundColor?.resolve({WidgetState.pressed}), colors.primary);
    expect(units.style?.iconColor?.resolve({WidgetState.hovered}), colors.primary);
    expect(units.style?.iconColor?.resolve({WidgetState.pressed}), colors.primary);
    expect(units.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('does not overflow while the sidebar collapses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('does not overflow while the sidebar expands', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('coordinates sidebar geometry and content throughout collapse and expansion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final sidebar = find.byKey(const Key('superadmin-sidebar'));
    final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Estrutura'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getSize(sidebar).width, greaterThan(230));
    expect(find.text('Estrutura'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 88);
    expect(find.text('Estrutura'), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.byKey(const Key('superadmin-navigation-section-structure')), findsWidgets);
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 260);
    expect(find.text('Estrutura'), findsOneWidget);
  });

  testWidgets('collapses the sidebar immediately when reduced motion is requested', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp(disableAnimations: true));

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pump();

    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    expect(find.text('Estrutura'), findsNothing);
  });

  testWidgets('keeps the collapse toggle clickable at its right inner edge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));
    final toggleRect = tester.getRect(toggle);
    final sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    expect(toggleRect.right, sidebarRect.right + CoeloSpacing.space5);

    await tester.tapAt(Offset(toggleRect.right - 1, toggleRect.center.dy));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width,
      88,
      reason: 'visual $toggleRect, sidebar $sidebarRect',
    );
  });

  testWidgets('keeps the visual collapse circle partly outside the sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    final toggleRect = tester.getRect(find.byKey(const Key('superadmin-sidebar-collapse')));
    final visualRect = tester.getRect(find.byKey(const Key('superadmin-sidebar-collapse-visual')));

    expect(visualRect.left, lessThan(sidebarRect.right));
    expect(visualRect.right, sidebarRect.right + CoeloSpacing.space2);
    expect(visualRect.size, const Size.square(CoeloSpacing.space6));
    expect(visualRect.center, toggleRect.center);
  });

  testWidgets('names the sidebar toggle without showing a visual tooltip', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    expect(find.byTooltip('Recolher menu'), findsNothing);
    expect(find.bySemanticsLabel('Recolher menu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Expandir menu'), findsNothing);
    expect(find.bySemanticsLabel('Expandir menu'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('keeps compact header actions four pixels below the app bar top', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actionsPadding, const EdgeInsetsDirectional.only(top: 4, end: 20));
  });

  testWidgets('uses aligned compact headers and collapses the desktop sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());

    expect(find.text('Coelo'), findsNothing);
    expect(find.text('Instituições'), findsWidgets);
    expect(find.text('Owner Coelo'), findsOneWidget);
    expect(find.text('Sair'), findsNothing);
    expect(find.byKey(const Key('superadmin-notifications')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-report-bug')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-profile-menu')), findsOneWidget);
    expect(find.text('Perfis'), findsNothing);
    for (final label in ['Estrutura', 'Acessos', 'Operação', 'Comunicação', 'Governança']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Configurações'), findsNothing);
    expect(find.text('Menu Dev'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 260);
    expect(
      tester.getSize(find.byKey(const Key('superadmin-sidebar-collapse'))),
      const Size.square(CoeloSize.touchMin),
    );
    expect(tester.getSize(find.byKey(const Key('superadmin-brand-mark'))), const Size(48, 48));
    expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);

    final activeDecoration =
        tester
                .widget<Container>(find.byKey(const Key('superadmin-navigation-institutions')))
                .decoration!
            as BoxDecoration;
    expect(activeDecoration.color, CoeloTheme.light.colorScheme.primary.withValues(alpha: 0.10));
    final activeSectionDecoration =
        tester
                .widget<Container>(find.byKey(const Key('superadmin-navigation-section-structure')))
                .decoration!
            as BoxDecoration;
    expect(activeSectionDecoration.color, CoeloTheme.light.colorScheme.primary);
    final inactiveSectionDecoration =
        tester
                .widget<Container>(find.byKey(const Key('superadmin-navigation-section-access')))
                .decoration!
            as BoxDecoration;
    expect(
      inactiveSectionDecoration.color,
      CoeloTheme.light.colorScheme.primaryContainer.withValues(alpha: 0),
    );
    final inactiveDestinationDecoration =
        tester.widget<Container>(find.byKey(const Key('superadmin-navigation-units'))).decoration!
            as BoxDecoration;
    expect(
      inactiveDestinationDecoration.color,
      CoeloTheme.light.colorScheme.primaryContainer.withValues(alpha: 0),
    );

    final brandDivider = find.byKey(const Key('superadmin-brand-divider'));
    final pageDivider = find.byKey(const Key('superadmin-page-divider'));
    expect(tester.getTopLeft(brandDivider).dy, 100);
    expect(tester.getTopLeft(brandDivider).dy, tester.getTopLeft(pageDivider).dy);

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    expect(find.text('Owner Coelo'), findsOneWidget);
    expect(find.text('Configurações'), findsNothing);
  });

  testWidgets('uses the Coelo orange hover state on inactive navigation items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final access = find.byKey(const Key('superadmin-navigation-section-access'));
    expect(access, findsOneWidget);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(access));
    await tester.pumpAndSettle();

    final decoration = tester.widget<Container>(access).decoration! as BoxDecoration;
    expect(decoration.color, CoeloTheme.light.colorScheme.primaryContainer);

    await gesture.removePointer();
  });

  testWidgets('uses a drawer navigation without putting the profile inside it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());

    expect(tester.getSize(find.byType(AppBar)).height, 48);
    expect(find.text('Coelo'), findsNothing);
    await tester.tap(find.byKey(const Key('superadmin-mobile-menu')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-operations')));
    await tester.pumpAndSettle();
    expect(find.text('Planos'), findsOneWidget);
    expect(find.text('Configurações'), findsNothing);
    expect(find.text('Menu Dev'), findsNothing);
    expect(find.text('Owner Coelo'), findsNothing);

    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    expect(find.text('Planos será implementado em breve.'), findsOneWidget);
  });

  testWidgets('keeps the official brand in mobile and tablet drawers', (tester) async {
    for (final configuration in [
      (width: 375.0, brightness: Brightness.light),
      (width: 768.0, brightness: Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(Size(configuration.width, 800));
      await tester.pumpWidget(_shellApp(brightness: configuration.brightness));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('superadmin-mobile-menu')));
      await tester.pumpAndSettle();

      final drawer = find.byType(Drawer);
      expect(
        find.descendant(of: drawer, matching: find.byKey(const Key('superadmin-brand-mark'))),
        findsOneWidget,
      );
      expect(find.descendant(of: drawer, matching: find.text('Superadmin')), findsOneWidget);
      expect(
        find.descendant(of: drawer, matching: find.byKey(const Key('superadmin-brand-divider'))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.byKey(const Key('superadmin-brand-logo'))),
        findsOneWidget,
      );
      expect(find.descendant(of: drawer, matching: find.text('Owner Coelo')), findsNothing);
      Navigator.of(tester.element(drawer)).pop();
      await tester.pumpAndSettle();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('opens profile actions and invokes logout only from its menu', (tester) async {
    var logoutCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminShell(
          logout: () async {
            logoutCount += 1;
            return const LogoutResult.success();
          },
        ),
      ),
    );

    expect(find.byTooltip('Sair'), findsNothing);
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-profile-action')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-settings-action')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('superadmin-profile-divider-spacing'))).height,
      CoeloSpacing.space2 + 1,
    );
    final logoutButton = find.byKey(const Key('superadmin-logout-action'));
    expect(logoutButton, findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('keeps the compact profile menu subtly inset from the right edge', (tester) async {
    for (final width in [375.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_shellApp());
      await tester.pumpAndSettle();

      final trigger = find.byKey(const Key('superadmin-profile-menu'));
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      final triggerRect = tester.getRect(trigger);
      final actionRect = tester.getRect(find.byKey(const Key('superadmin-profile-action')));
      final panelRects =
          find
              .ancestor(
                of: find.byKey(const Key('superadmin-profile-action')),
                matching: find.byType(Material),
              )
              .evaluate()
              .map((element) {
                final box = element.renderObject! as RenderBox;
                return box.localToGlobal(Offset.zero) & box.size;
              })
              .where((rect) => rect.width >= actionRect.width && rect.height > actionRect.height)
              .toList()
            ..sort(
              (left, right) => (left.width * left.height).compareTo(right.width * right.height),
            );
      expect(panelRects, isNotEmpty);
      final panelRect = panelRects.first;
      expect(
        panelRect.right,
        closeTo(triggerRect.right, 1),
        reason:
            'viewport $width, trigger $triggerRect, '
            'panel $panelRect',
      );
      expect(panelRect.left, greaterThanOrEqualTo(0));
      expect(panelRect.bottom, lessThanOrEqualTo(800));

      await tester.tap(trigger);
      await tester.pumpAndSettle();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('opens the rounded profile menu below its trigger', (tester) async {
    await tester.pumpWidget(_shellApp());

    final trigger = find.byKey(const Key('superadmin-profile-menu'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final logout = tester.widget<MenuItemButton>(find.byKey(const Key('superadmin-logout-action')));
    final profile = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-profile-action')),
    );
    final settings = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-settings-action')),
    );
    expect(logout.style?.foregroundColor?.resolve({}), CoeloTheme.light.colorScheme.error);
    expect(logout.style?.iconColor?.resolve({}), CoeloTheme.light.colorScheme.error);
    expect(
      logout.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
    expect(logout.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    for (final action in [profile, settings]) {
      expect(
        action.style?.foregroundColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.colorScheme.primary,
      );
      expect(
        action.style?.iconColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.colorScheme.primary,
      );
      expect(
        action.style?.backgroundColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.colorScheme.primaryContainer,
      );
      expect(action.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('superadmin-profile-action'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(trigger).dy),
    );

    for (final key in ['superadmin-report-bug', 'superadmin-notifications']) {
      final button = tester.widget<IconButton>(find.byKey(Key(key)));
      expect(button.style?.shape?.resolve({}), const CircleBorder());
      expect(
        button.style?.overlayColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.colorScheme.primaryContainer,
      );
      expect(
        button.style?.foregroundColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.extension<CoeloActionColors>()!.primaryHover,
      );
    }
  });

  testWidgets('uses the official circular brand treatment for light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());
    final lightMark = tester.widget<Container>(find.byKey(const Key('superadmin-brand-mark')));
    final lightDecoration = lightMark.decoration! as BoxDecoration;
    final lightLogo = tester.widget<SvgPicture>(find.byKey(const Key('superadmin-brand-logo')));
    final lightLoader = lightLogo.bytesLoader as SvgAssetLoader;
    expect(lightDecoration.shape, BoxShape.circle);
    expect(lightDecoration.color, CoeloTheme.light.colorScheme.primary);
    expect(lightLoader.assetName, 'assets/brand/logo-coelo-white.svg');
    expect(lightLogo.colorFilter, isNull);
    expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);

    await tester.pumpWidget(_shellApp(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final darkMark = tester.widget<Container>(find.byKey(const Key('superadmin-brand-mark')));
    final darkDecoration = darkMark.decoration! as BoxDecoration;
    final darkLogo = tester.widget<SvgPicture>(find.byKey(const Key('superadmin-brand-logo')));
    final darkLoader = darkLogo.bytesLoader as SvgAssetLoader;
    expect(darkDecoration.shape, BoxShape.circle);
    expect(darkDecoration.color, CoeloPalette.neutral0);
    expect(darkLoader.assetName, 'assets/brand/logo-coelo-orange.svg');
    expect(darkLogo.colorFilter, isNull);
    expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);
  });

  testWidgets('shows safe feedback when logout fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminShell(
          logout: () async => const LogoutResult.failure(LogoutResult.genericFailureMessage),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-logout-action')));
    await tester.pumpAndSettle();

    expect(find.text(LogoutResult.genericFailureMessage), findsOneWidget);
  });

  testWidgets('opens notifications and the bug report form', (tester) async {
    final activities = SuperadminActivityController();
    addTearDown(activities.dispose);
    activities.completeDemoExport(SuperadminExportFormat.csv);
    await tester.pumpWidget(_shellApp(activities: activities));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('instituicoes.csv'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-activity-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    final dialogFinder = find.byKey(const Key('superadmin-bug-report-dialog'));
    expect(dialogFinder, findsOneWidget);
    final dialog = tester.widget<Dialog>(dialogFinder);
    final theme = Theme.of(tester.element(dialogFinder));
    expect(dialog.backgroundColor, theme.colorScheme.surface);
    expect(dialog.backgroundColor, isNot(theme.colorScheme.primaryContainer));
    expect(
      (dialog.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(CoeloRadius.lg),
    );
    expect(
      tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .any((barrier) => barrier.color == theme.extension<CoeloOverlayColors>()!.scrim),
      isTrue,
    );
    expect(find.text('Bug? O Coelo resolve!'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-bug-screen')),
        matching: find.text('Instituições'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('superadmin-bug-report-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-settings-action')));
    await tester.pumpAndSettle();
    expect(find.text('Configurações será implementado em breve.'), findsOneWidget);
  });

  testWidgets('keeps a completion unread when a breakpoint replaces an open center', (
    tester,
  ) async {
    final activities = SuperadminActivityController();
    addTearDown(activities.dispose);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp(activities: activities));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(375, 800));
    await tester.pumpAndSettle();

    activities.completeDemoExport(SuperadminExportFormat.csv);
    await tester.pump();

    expect(activities.unreadCount, 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-notification-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not reactivate notifications when Bug or OC closes the panel', (tester) async {
    await tester.pumpWidget(_shellApp());

    final notifications = find.byKey(const Key('superadmin-notifications'));
    await tester.tap(notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(notifications).focusNode?.hasPrimaryFocus, isFalse);
    expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-bug-report-close')));
    await tester.pumpAndSettle();

    await tester.tap(notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(notifications).focusNode?.hasPrimaryFocus, isFalse);
    expect(find.byKey(const Key('superadmin-profile-action')), findsOneWidget);
  });

  testWidgets('submits a bug report with current screen, multiline text and demo attachment', (
    tester,
  ) async {
    await tester.pumpWidget(_shellApp());

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    final screenField = find.byKey(const Key('superadmin-bug-screen'));
    final description = find.byKey(const Key('superadmin-bug-description'));
    expect(screenField, findsOneWidget);
    expect(find.descendant(of: screenField, matching: find.text('Instituições')), findsOneWidget);
    expect(tester.widget<TextField>(description).maxLines, greaterThanOrEqualTo(4));
    expect(find.text('Outro'), findsNothing);

    await tester.tap(screenField);
    await tester.pumpAndSettle();
    expect(find.text('Outro'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-bug-screen-option-Outro')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_shellApp());
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    final refreshedDescription = find.byKey(const Key('superadmin-bug-description'));
    await tester.enterText(refreshedDescription, 'A tabela não atualizou após o filtro.');
    await tester.tap(find.byKey(const Key('superadmin-bug-attach')));
    await tester.pump();
    expect(find.text('evidencia-anexada.png'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-menu-option-Outros')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-bug-other-subject')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-bug-screen')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('superadmin-bug-other-subject')),
      'Support request',
    );

    final submit = find.byKey(const Key('superadmin-bug-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Relato enviado com sucesso.'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsNothing);
    expect(find.byKey(const Key('superadmin-transient-notice')), findsOneWidget);
  });

  testWidgets('validates and submits one trimmed support draft from the bug report dialog', (
    tester,
  ) async {
    final drafts = <SupportReportDraft>[];
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: drafts.add));

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    final description = find.byKey(const Key('superadmin-bug-description'));
    final submit = find.byKey(const Key('superadmin-bug-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(description, '  First line subject\nDetails  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(drafts, hasLength(1));
    expect(drafts.single.menu, 'Estrutura');
    expect(drafts.single.screen, startsWith('Institui'));
    expect(drafts.single.subject, 'First line subject');
    expect(drafts.single.description, 'First line subject\nDetails');
    expect(drafts.single.requester, 'Owner Coelo');
    expect(drafts.single.includeDemoAttachment, isFalse);
  });

  testWidgets('requires a custom subject for Outros and does not submit on cancel', (tester) async {
    final drafts = <SupportReportDraft>[];
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: drafts.add));

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-bug-description')), 'Description');
    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-menu-option-Outros')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('superadmin-bug-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('superadmin-bug-other-subject')),
      '  Custom subject  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('superadmin-bug-report-close')));
    await tester.pumpAndSettle();

    expect(drafts, isEmpty);
  });

  testWidgets('uses the live navigation hierarchy and the approved bug menu states', (
    tester,
  ) async {
    await tester.pumpWidget(_shellApp());
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    for (final section in [
      'Estrutura',
      'Acessos',
      'Operação',
      'Comunicação',
      'Governança',
      'Conta',
      'Outros',
    ]) {
      expect(find.byKey(Key('superadmin-bug-menu-option-$section')), findsOneWidget);
    }

    final selectedItem = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-bug-menu-option-Estrutura')),
    );
    final selectedShape = selectedItem.style?.shape?.resolve({}) as RoundedRectangleBorder;
    final hoverShape =
        selectedItem.style?.shape?.resolve({WidgetState.hovered}) as RoundedRectangleBorder;
    expect(selectedShape.borderRadius, BorderRadius.zero);
    expect(hoverShape.borderRadius, BorderRadius.zero);
    final idleItem = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-bug-menu-option-Conta')),
    );
    final idleShape = idleItem.style?.shape?.resolve({}) as RoundedRectangleBorder;
    final idleHoverShape =
        idleItem.style?.shape?.resolve({WidgetState.hovered}) as RoundedRectangleBorder;
    expect(idleShape.borderRadius, BorderRadius.circular(CoeloRadius.md));
    expect(idleHoverShape.borderRadius, BorderRadius.zero);

    await tester.tap(find.byKey(const Key('superadmin-bug-menu-option-Acessos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-screen')));
    await tester.pumpAndSettle();
    for (final screen in ['Pessoas', 'Usuários internos', 'Perfis e permissões', 'Outro']) {
      expect(find.byKey(Key('superadmin-bug-screen-option-$screen')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('superadmin-bug-screen-option-Pessoas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-menu-option-Conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-bug-screen')));
    await tester.pumpAndSettle();
    for (final screen in ['Perfil', 'Configurações', 'Outros']) {
      expect(find.byKey(Key('superadmin-bug-screen-option-$screen')), findsOneWidget);
    }
  });

  testWidgets('underlines evidence in orange only on hover without duplicate tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(_shellApp());
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    final attach = find.byKey(const Key('superadmin-bug-attach'));
    expect(find.ancestor(of: attach, matching: find.byType(Tooltip)), findsNothing);
    final button = tester.widget<TextButton>(attach);
    final idleStyle = button.style?.textStyle?.resolve({});
    final hoverStyle = button.style?.textStyle?.resolve({WidgetState.hovered});
    expect(idleStyle?.decoration, TextDecoration.none);
    expect(hoverStyle?.decoration, TextDecoration.underline);
    expect(hoverStyle?.decorationColor, CoeloTheme.light.colorScheme.primary);
  });

  testWidgets('clears the notification focus after an outside close', (tester) async {
    await tester.pumpWidget(_shellApp());

    final notifications = find.byKey(const Key('superadmin-notifications'));
    await tester.tap(notifications);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(500, 500));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(notifications).focusNode?.hasFocus, isFalse);
  });

  testWidgets('uses a full-width carrot theme control and preserves the compact toggle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness());

    final control = find.byKey(const Key('superadmin-theme-mode-control'));
    expect(control, findsOneWidget);
    expect(find.text('Seguir o sistema'), findsNothing);
    expect(tester.getSize(control), const Size(244, 48));
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-theme-carrot')), findsOneWidget);
    expect(tester.widget<InkWell>(control).borderRadius, BorderRadius.circular(CoeloRadius.lg));
    final lightCarrotPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('superadmin-theme-carrot')))
        .painter!;

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('superadmin-sidebar')))).brightness,
      Brightness.dark,
    );
    final darkCarrotPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('superadmin-theme-carrot')))
        .painter!;
    expect(darkCarrotPainter.shouldRepaint(lightCarrotPainter), isTrue);

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-theme-mode-control')), findsOneWidget);
    expect(tester.getSize(control), const Size(48, 80));
    expect(tester.widget<InkWell>(control).borderRadius, BorderRadius.circular(CoeloRadius.full));
    expect(tester.takeException(), isNull);

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('superadmin-sidebar')))).brightness,
      Brightness.light,
    );
  });

  testWidgets('interpolates theme colors without changing geometry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness());

    final control = find.byKey(const Key('superadmin-theme-mode-control'));
    final lightColor = _themeControlDecoration(tester).color;
    final lightSize = tester.getSize(control);
    final lightRadius = _themeControlDecoration(tester).borderRadius;
    final darkColor = CoeloTheme.dark.colorScheme.surfaceContainerHighest;

    await tester.tap(control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    final middleDecoration = _themeControlDecoration(tester);
    expect(middleDecoration.color, isNot(lightColor));
    expect(middleDecoration.color, isNot(darkColor));
    expect(tester.getSize(control), lightSize);
    expect(middleDecoration.borderRadius, lightRadius);

    await tester.pump(const Duration(milliseconds: 210));
    final darkDecoration = _themeControlDecoration(tester);
    expect(darkDecoration.color, darkColor);
    expect(tester.getSize(control), lightSize);
    expect(darkDecoration.borderRadius, lightRadius);
  });

  testWidgets('keeps navigation and status colors on the global 210 and 420 ms frames', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness(showStatus: true));

    final navigation = find.byKey(const Key('superadmin-navigation-section-structure'));
    final status = find.byKey(const Key('theme-transition-status'));
    final statusSurface = _statusThemeSurface(status);
    final lightNavigation = _surfaceDecoration(tester, navigation).color;
    final lightStatus = _surfaceDecoration(tester, statusSurface).color;

    await tester.tap(find.byKey(const Key('superadmin-theme-mode-control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    final middleNavigation = Theme.of(tester.element(navigation)).colorScheme.primary;
    final middleStatus = Theme.of(
      tester.element(status),
    ).extension<CoeloStatusColors>()!.successContainer;
    expect(middleNavigation, isNot(lightNavigation));
    expect(middleNavigation, isNot(CoeloTheme.dark.colorScheme.primary));
    expect(middleStatus, isNot(lightStatus));
    expect(middleStatus, isNot(CoeloTheme.dark.extension<CoeloStatusColors>()!.successContainer));
    expect(_surfaceDecoration(tester, navigation).color, middleNavigation);
    expect(_surfaceDecoration(tester, statusSurface).color, middleStatus);

    await tester.pump(const Duration(milliseconds: 210));

    expect(_surfaceDecoration(tester, navigation).color, CoeloTheme.dark.colorScheme.primary);
    expect(
      _surfaceDecoration(tester, statusSurface).color,
      CoeloTheme.dark.extension<CoeloStatusColors>()!.successContainer,
    );
  });

  testWidgets('switches navigation and status surfaces immediately under reduced motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness(disableAnimations: true, showStatus: true));

    final navigation = find.byKey(const Key('superadmin-navigation-section-structure'));
    final statusSurface = _statusThemeSurface(find.byKey(const Key('theme-transition-status')));

    await tester.tap(find.byKey(const Key('superadmin-theme-mode-control')));
    await tester.pump();

    expect(tester.widget<Widget>(navigation), isA<Container>());
    expect(tester.widget<Widget>(statusSurface), isA<Container>());
    expect(_surfaceDecoration(tester, navigation).color, CoeloTheme.dark.colorScheme.primary);
    expect(
      _surfaceDecoration(tester, statusSurface).color,
      CoeloTheme.dark.extension<CoeloStatusColors>()!.successContainer,
    );
  });

  testWidgets('keeps the theme marker and content on the global transition timing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness());

    final control = find.byKey(const Key('superadmin-theme-mode-control'));
    expect(find.descendant(of: control, matching: find.byType(AnimatedContainer)), findsNothing);

    final marker = tester.widget<AnimatedAlign>(
      find.descendant(of: control, matching: find.byType(AnimatedAlign)),
    );
    expect(marker.duration, const Duration(milliseconds: 420));
    expect(marker.curve, Curves.easeInOut);

    final content = tester.widget<AnimatedSwitcher>(
      find.descendant(of: control, matching: find.byType(AnimatedSwitcher)),
    );
    expect(content.duration, const Duration(milliseconds: 420));
    expect(content.switchInCurve, Curves.easeInOut);
    expect(content.switchOutCurve, Curves.easeInOut);
  });

  testWidgets('switches theme instantly without changing geometry under reduced motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness(disableAnimations: true));

    final control = find.byKey(const Key('superadmin-theme-mode-control'));
    final lightSize = tester.getSize(control);
    final lightRadius = _themeControlDecoration(tester).borderRadius;

    await tester.tap(control);
    await tester.pump();

    final darkDecoration = _themeControlDecoration(tester);
    expect(darkDecoration.color, CoeloTheme.dark.colorScheme.surfaceContainerHighest);
    expect(tester.getSize(control), lightSize);
    expect(darkDecoration.borderRadius, lightRadius);

    final marker = tester.widget<AnimatedAlign>(
      find.descendant(of: control, matching: find.byType(AnimatedAlign)),
    );
    final content = tester.widget<AnimatedSwitcher>(
      find.descendant(of: control, matching: find.byType(AnimatedSwitcher)),
    );
    expect(marker.duration, Duration.zero);
    expect(content.duration, Duration.zero);
  });

  testWidgets('opens the three demonstration tour options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    expect(find.text('Fazer tour'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-onboarding-egg')), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-tour-screen')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-tour-menu')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-tour-complete')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('superadmin-tour-screen')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('O tour desta tela será implementado na etapa final.'), findsNothing);

    for (final option in {
      'superadmin-tour-screen': 'O tour desta tela será implementado na etapa final.',
      'superadmin-tour-menu': 'O tour do menu será implementado na etapa final.',
      'superadmin-tour-complete': 'O tour completo será implementado na etapa final.',
    }.entries) {
      await tester.tap(find.byKey(Key(option.key)));
      await tester.pumpAndSettle();
      expect(find.text(option.value), findsOneWidget);
      await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('repaints the onboarding egg when semantic colors change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final lightEggPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('superadmin-onboarding-egg')))
        .painter!;

    await tester.pumpWidget(_shellApp(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    final darkEggPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('superadmin-onboarding-egg')))
        .painter!;
    expect(darkEggPainter.shouldRepaint(lightEggPainter), isTrue);
  });

  testWidgets('swings and rests the onboarding egg', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final motion = find.byKey(const Key('superadmin-onboarding-egg-motion'));
    final resting = tester.widget<Transform>(motion).transform.clone();
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 120));
    final animated = tester.widget<Transform>(motion).transform;
    expect(animated, isNot(resting));
    final angle = math.atan2(animated.entry(1, 0), animated.entry(0, 0)).abs();
    expect(angle, greaterThan(4.5 * math.pi / 180));
    await tester.pump(const Duration(milliseconds: 835));
    expect(tester.widget<Transform>(motion).transform, resting);

    await tester.pumpWidget(_shellApp(disableAnimations: true));
    final reducedInitial = tester.widget<Transform>(motion).transform.clone();
    await tester.pump(const Duration(seconds: 6));
    expect(tester.widget<Transform>(motion).transform, reducedInitial);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the tour menu beside expanded and collapsed triggers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    var trigger = find.byKey(const Key('superadmin-onboarding-tour'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    var firstOption = find.byKey(const Key('superadmin-tour-screen'));
    var sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    const tourSurfacePadding = CoeloSpacing.space2;
    expect(tester.getTopLeft(firstOption).dx, greaterThanOrEqualTo(tester.getTopRight(trigger).dx));
    expect(tester.getTopLeft(firstOption).dx, sidebarRect.right + CoeloSpacing.space1);
    expect(
      tester.getTopLeft(firstOption).dx - tourSurfacePadding,
      sidebarRect.right - CoeloSpacing.space1,
    );
    var tourAnchor = tester.widget<MenuAnchor>(
      find.ancestor(of: trigger, matching: find.byType(MenuAnchor)).first,
    );
    expect(
      tourAnchor.alignmentOffset,
      const Offset(252 - CoeloSpacing.space1, -CoeloSize.touchMin),
    );

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    trigger = find.byKey(const Key('superadmin-onboarding-tour'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    firstOption = find.byKey(const Key('superadmin-tour-screen'));
    sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    expect(tester.getTopLeft(firstOption).dx, greaterThanOrEqualTo(tester.getTopRight(trigger).dx));
    expect(tester.getTopLeft(firstOption).dx, sidebarRect.right + CoeloSpacing.space1);
    expect(
      tester.getTopLeft(firstOption).dx - tourSurfacePadding,
      sidebarRect.right - CoeloSpacing.space1,
    );
    expect(tester.getRect(firstOption).right, lessThanOrEqualTo(1200));
    tourAnchor = tester.widget<MenuAnchor>(
      find.ancestor(of: trigger, matching: find.byType(MenuAnchor)).first,
    );
    expect(
      tourAnchor.alignmentOffset,
      const Offset(CoeloSize.touchMin + CoeloSpacing.space4, -CoeloSize.touchMin),
    );
  });

  testWidgets('does not schedule the egg timer in reduced motion and cancels it on dispose', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final restTimers = <Timer>[];
    final timerCapture = ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createTimer(zone, duration, callback);
        if (duration == const Duration(milliseconds: 3500)) {
          restTimers.add(timer);
        }
        return timer;
      },
    );

    await runZoned(
      () => tester.pumpWidget(_shellApp(disableAnimations: true)),
      zoneSpecification: timerCapture,
    );
    expect(restTimers, isEmpty);

    await runZoned(() => tester.pumpWidget(_shellApp()), zoneSpecification: timerCapture);
    expect(restTimers, hasLength(1));
    expect(restTimers.single.isActive, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(restTimers.single.isActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports the final responsive, theme, text scaling and motion matrix', (
    tester,
  ) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          _shellApp(
            brightness: brightness,
            disableAnimations: true,
            textScaler: const TextScaler.linear(1.5),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'viewport $width / $brightness');
        if (width >= CoeloBreakpoints.expanded.minWidth) {
          expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
          expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('superadmin-mobile-menu')), findsOneWidget);
        }
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

class _ThemeShellHarness extends StatefulWidget {
  const _ThemeShellHarness({this.disableAnimations = false, this.showStatus = false});

  final bool disableAnimations;
  final bool showStatus;

  @override
  State<_ThemeShellHarness> createState() => _ThemeShellHarnessState();
}

class _ThemeShellHarnessState extends State<_ThemeShellHarness> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: _mode,
      themeAnimationStyle: widget.disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeInOut),
      builder: (context, child) => SuperadminThemeModeScope(
        mode: _mode,
        onChanged: (mode) => setState(() => _mode = mode),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: widget.disableAnimations),
          child: child!,
        ),
      ),
      home: SuperadminShell(
        logout: () async => const LogoutResult.success(),
        child: widget.showStatus
            ? const Center(
                child: SuperadminActivityStatusIndicator(
                  key: Key('theme-transition-status'),
                  status: SuperadminActivityStatus.succeeded,
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

Widget _shellApp({
  Brightness brightness = Brightness.light,
  SuperadminActivityController? activities,
  ValueChanged<SupportReportDraft>? onBugReportSubmitted,
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
  String currentDestination = 'institutions',
  ValueChanged<String>? onDestinationSelected,
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations, textScaler: textScaler),
        child: SuperadminShell(
          logout: () async => const LogoutResult.success(),
          activityController: activities,
          onBugReportSubmitted: onBugReportSubmitted,
          currentDestination: currentDestination,
          onDestinationSelected: onDestinationSelected,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

BoxDecoration _themeControlDecoration(WidgetTester tester) {
  return tester
          .widget<Container>(find.byKey(const Key('superadmin-theme-mode-surface')))
          .decoration!
      as BoxDecoration;
}

Finder _statusThemeSurface(Finder status) {
  return find
      .descendant(
        of: status,
        matching: find.byWidgetPredicate(
          (widget) =>
              (widget is AnimatedContainer && widget.decoration is BoxDecoration) ||
              (widget is Container && widget.decoration is BoxDecoration),
        ),
      )
      .first;
}

BoxDecoration _surfaceDecoration(WidgetTester tester, Finder finder) {
  final widget = tester.widget<Widget>(finder);
  if (widget is AnimatedContainer) {
    final renderedContainer = find.descendant(of: finder, matching: find.byType(Container)).first;
    return tester.widget<Container>(renderedContainer).decoration! as BoxDecoration;
  }
  if (widget is Container) {
    return widget.decoration! as BoxDecoration;
  }
  throw StateError('Expected a themed surface, found ${widget.runtimeType}.');
}

Future<void> _loadGoldenFonts() async {
  final fontLoader = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await fontLoader.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
