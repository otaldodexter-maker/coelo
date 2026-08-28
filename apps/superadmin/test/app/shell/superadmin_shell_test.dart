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
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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

      expect(find.text('Tour desta tela'), findsOneWidget);
      expect(find.text('Tour do menu'), findsOneWidget);
      expect(find.text('Tour completo'), findsOneWidget);
      final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      final colors = Theme.of(tester.element(find.byType(MenuAnchor))).colorScheme;
      expect(anchor.style?.elevation?.resolve({}), CoeloElevation.level2);
      final screenItem = tester.widget<MenuItemButton>(_menuItemWithText('Tour desta tela'));
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

  testWidgets('compact light shell uses the semantic surface at mobile and tablet widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [375.0, 768.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_shellApp());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final colors = Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme;
      expect(scaffold.backgroundColor, colors.surface, reason: 'width $width');
    }
  });
  testWidgets('mobile drawer uses the semantic surface in light and dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(_shellApp(brightness: brightness));
      await tester.tap(find.byTooltip('Abrir menu'));
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      final colors = Theme.of(tester.element(find.byType(Drawer))).colorScheme;
      expect(drawer.backgroundColor, colors.surface, reason: brightness.name);

      await tester.tapAt(const Offset(360, 400));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('host shell shows the compact chat launcher on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final destinations = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: () async => const LogoutResult.success(),
          currentDestination: 'institutions',
          onDestinationSelected: destinations.add,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(launcher, findsOneWidget);
    expect(tester.getSize(launcher).width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getSize(launcher).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getRect(launcher).right, lessThanOrEqualTo(375 - CoeloSpacing.space2));
    expect(tester.getRect(launcher).bottom, lessThanOrEqualTo(812 - CoeloSpacing.space2));
  });

  testWidgets('shows the approved floating hierarchical navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());

    expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-home')), findsOneWidget);

    for (final section in ['structure', 'access', 'health-care', 'operations', 'communication']) {
      final sectionFinder = find.byKey(Key('superadmin-navigation-section-$section'));
      await tester.scrollUntilVisible(
        sectionFinder,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('superadmin-navigation-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(sectionFinder, findsOneWidget);
    }
    for (final label in ['Unidades', 'Turmas']) {
      expect(find.text(label), findsOneWidget);
    }

    for (final entry in {
      'access': ['Pessoas', 'Perfis e permissões'],
      'health-care': ['Perfis de cuidado', 'Planos de medicação'],
      'operations': ['Formulários', 'Importações'],
      'communication': ['Convites', 'Comunicações'],
      'governance': ['Suporte e implantação', 'Auditoria'],
    }.entries) {
      final section = find.byKey(Key('superadmin-navigation-section-${entry.key}'));
      await tester.scrollUntilVisible(
        section,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('superadmin-navigation-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(section);
      await tester.pumpAndSettle();
      for (final label in entry.value) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(section);
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
    expect(destinations, ['home']);
    semantics.dispose();
  });

  testWidgets('opens conversations through the generic navigation callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final destinations = <String>[];

    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      onDestinationSelected: destinations.add,
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: shell));

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    expect(destinations, ['conversations']);
  });

  testWidgets('does not expose a dead chat launcher without a navigation capability', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell(
          logout: () async => const LogoutResult.success(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
  });

  testWidgets('does not reserve global bottom clearance for the launcher', (tester) async {
    final destinations = <String>[];
    for (final width in [375.0, 768.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: SuperadminShell(
            key: ValueKey(width),
            logout: () async => const LogoutResult.success(),
            onDestinationSelected: destinations.add,
            child: Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                key: const Key('bottom-right-content-action'),
                tooltip: 'Ação inferior direita',
                onPressed: () {},
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-chat-launcher-clearance')), findsNothing);
      if (width == 1440) {
        expect(
          tester.getBottomRight(find.byKey(const Key('superadmin-floating-content'))).dy,
          900 - CoeloSpacing.space3,
        );
      }
      expect(tester.takeException(), isNull, reason: 'viewport $width');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    expect(expansions, 1);
  });

  testWidgets('hides the global launcher on the conversations route', (tester) async {
    final shell = SuperadminShell(
      logout: () async => const LogoutResult.success(),
      currentDestination: 'conversations',
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: shell));

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
  });

  testWidgets('starts Home with Structure collapsed and opens the active section contextually', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp(currentDestination: 'home'));

    expect(find.byKey(const Key('superadmin-navigation-home')), findsOneWidget);
    expect(
      tester.widget<Container>(find.byKey(const Key('superadmin-navigation-home'))).decoration,
      isA<BoxDecoration>()
          .having(
            (decoration) => decoration.color,
            'color',
            Theme.of(
              tester.element(find.byKey(const Key('superadmin-navigation-home'))),
            ).colorScheme.primary,
          )
          .having(
            (decoration) => decoration.borderRadius,
            'borderRadius',
            BorderRadius.circular(CoeloRadius.md),
          ),
    );
    expect(find.text('Estrutura'), findsOneWidget);
    expect(find.text('Unidades'), findsNothing);
    expect(find.text('Turmas'), findsNothing);

    await tester.pumpWidget(_shellApp(currentDestination: 'institutions'));
    await tester.pump();

    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Turmas'), findsOneWidget);
    expect(
      tester
          .widget<Container>(find.byKey(const Key('superadmin-navigation-institutions')))
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        Theme.of(
          tester.element(find.byKey(const Key('superadmin-navigation-institutions'))),
        ).colorScheme.primaryContainer,
      ),
    );
  });

  testWidgets('distinguishes the active section from its active destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp(currentDestination: 'institutions'));

    final sectionDecoration =
        tester
                .widget<Container>(find.byKey(const Key('superadmin-navigation-section-structure')))
                .decoration!
            as BoxDecoration;
    final destinationDecoration =
        tester
                .widget<Container>(find.byKey(const Key('superadmin-navigation-institutions')))
                .decoration!
            as BoxDecoration;

    expect(sectionDecoration.color, isNot(destinationDecoration.color));
  });

  testWidgets('shows Activities after Groups as an active Structure destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final destinations = <String>[];

    await tester.pumpWidget(_shellApp(onDestinationSelected: destinations.add));

    expect(find.text('Atividades'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Atividades')).dy,
      greaterThan(tester.getTopLeft(find.text('Turmas')).dy),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-activities')));
    await tester.pump();
    expect(destinations, ['activities']);
  });

  testWidgets('activates Units and gives Conversations a distinct icon', (tester) async {
    final destinations = <String>[];
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shellApp(currentDestination: 'conversations', onDestinationSelected: destinations.add),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-units')));
    expect(destinations, ['units']);

    await tester.scrollUntilVisible(
      find.byKey(const Key('superadmin-navigation-section-communication')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('superadmin-navigation-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    final communicationIcon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(const Key('superadmin-navigation-section-communication')),
            matching: find.byType(Icon),
          )
          .first,
    );
    final conversationsIcon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(const Key('superadmin-navigation-conversations')),
            matching: find.byType(Icon),
          )
          .first,
    );
    expect(conversationsIcon.icon, isNot(communicationIcon.icon));
  });

  testWidgets('removes section and item geometry motion when reduced motion is requested', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp(disableAnimations: true));

    for (final animatedSize in tester.widgetList<AnimatedSize>(find.byType(AnimatedSize))) {
      expect(animatedSize.duration, Duration.zero);
    }
    for (final animatedPadding in tester.widgetList<AnimatedPadding>(
      find.byType(AnimatedPadding),
    )) {
      expect(animatedPadding.duration, Duration.zero);
    }
  });

  testWidgets('keeps the Superadmin brand background transparent in every interaction state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

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
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    expect(find.text('Estrutura'), findsNothing);

    final activeSection = tester.widget<IconButton>(
      find.byKey(const Key('superadmin-navigation-section-structure')),
    );
    final colors = CoeloTheme.light.colorScheme;
    expect(activeSection.style?.backgroundColor?.resolve({}), colors.primaryContainer);
    expect(
      activeSection.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(activeSection.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byKey(const Key('superadmin-navigation-section-structure')),
        matching: find.byType(CoeloAdminFlyout<String>),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    final navigationAnchor = tester.widget<MenuAnchor>(
      find
          .ancestor(
            of: find.byKey(const Key('superadmin-navigation-section-structure')),
            matching: find.byType(MenuAnchor),
          )
          .first,
    );
    expect(navigationAnchor.alignmentOffset, isNotNull);
    expect(navigationAnchor.style?.elevation?.resolve({}), CoeloElevation.level2);
    expect(navigationAnchor.style?.padding?.resolve({}), const EdgeInsets.all(CoeloSpacing.space2));
    expect(navigationAnchor.style?.minimumSize?.resolve({})?.width, 236);
    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Turmas'), findsOneWidget);
    final sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    expect(
      tester.getTopLeft(_menuItemWithText('Unidades')).dx,
      sidebarRect.right + CoeloSpacing.space2,
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Instituições'), findsWidgets);
    final units = tester.widget<MenuItemButton>(_menuItemWithText('Unidades'));
    final institutions = tester.widget<MenuItemButton>(_menuItemWithText('Instituições'));
    expect(institutions.style?.backgroundColor?.resolve({}), colors.primaryContainer);
    expect(
      institutions.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(institutions.style?.foregroundColor?.resolve({}), colors.primary);
    expect(units.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(units.style?.backgroundColor?.resolve({WidgetState.pressed}), colors.primaryContainer);
    expect(units.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.primary);
    expect(units.style?.foregroundColor?.resolve({WidgetState.pressed}), colors.primary);
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

  testWidgets('uses one sidebar tree throughout the collapse and expand motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final sidebar = find.byKey(const Key('superadmin-sidebar'));
    final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));
    final home = find.byKey(const Key('superadmin-navigation-home'));

    expect(home, findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.getSize(sidebar).width, inExclusiveRange(88, 260));
    expect(home, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.getSize(sidebar).width, inExclusiveRange(88, 260));
    expect(home, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotates the collapse chevron with the sidebar progress', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));
    final chevron = find.byKey(const Key('superadmin-sidebar-collapse-chevron'));

    expect(tester.widget<Transform>(chevron).transform, Matrix4.identity());

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final intermediate = tester.widget<Transform>(chevron).transform;
    final intermediateAngle = math.atan2(intermediate.entry(1, 0), intermediate.entry(0, 0));
    expect(intermediateAngle.abs(), inExclusiveRange(0, math.pi));

    await tester.pumpAndSettle();
    final collapsed = tester.widget<Transform>(chevron).transform;
    expect(math.atan2(collapsed.entry(1, 0), collapsed.entry(0, 0)).abs(), closeTo(math.pi, 0.001));
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

    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

    expect(find.text('Coelo'), findsNothing);
    expect(find.text('Instituições'), findsWidgets);
    expect(find.text('Owner Coelo'), findsOneWidget);
    expect(find.text('Sair'), findsNothing);
    expect(find.byKey(const Key('superadmin-notifications')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-report-bug')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-profile-menu')), findsOneWidget);
    expect(find.text('Perfis'), findsNothing);
    for (final section in ['structure', 'access', 'health-care', 'operations', 'communication']) {
      final sectionFinder = find.byKey(Key('superadmin-navigation-section-$section'));
      await tester.scrollUntilVisible(
        sectionFinder,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('superadmin-navigation-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(sectionFinder, findsOneWidget);
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
    expect(activeDecoration.color, CoeloTheme.light.colorScheme.primaryContainer);
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
    expect(find.text('Formulários'), findsOneWidget);
    expect(find.text('Importações'), findsOneWidget);
    expect(find.text('Planos'), findsNothing);
    expect(find.text('Configurações'), findsNothing);
    expect(find.text('Menu Dev'), findsNothing);
    expect(find.text('Owner Coelo'), findsNothing);
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

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    final logoutButton = _menuItemWithText('Sair');
    expect(logoutButton, findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-logout-dialog')), findsOneWidget);
    expect(logoutCount, 0);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('superadmin-logout-dialog')),
        matching: find.text('Sair'),
      ),
    );
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('uses canonical flyouts and keeps logout semantically negative', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    expect(find.byType(CoeloAdminFlyout<String>), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();

    final logout = tester.widget<MenuItemButton>(
      find.ancestor(of: find.text('Sair'), matching: find.byType(MenuItemButton)),
    );
    final colors = CoeloTheme.light.colorScheme;
    expect(logout.style?.foregroundColor?.resolve({}), colors.error);
    expect(logout.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.errorContainer);

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminFlyout<String>), findsWidgets);
  });

  testWidgets('uses the canonical surface and elevation for profile and tour flyouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shellApp());

    final colors = CoeloTheme.light.colorScheme;
    for (final triggerKey in const [
      Key('superadmin-profile-menu'),
      Key('superadmin-onboarding-tour'),
    ]) {
      final anchor = tester.widget<MenuAnchor>(
        find.ancestor(of: find.byKey(triggerKey), matching: find.byType(MenuAnchor)).first,
      );
      expect(anchor.style?.backgroundColor?.resolve({}), colors.surface);
      expect(anchor.style?.surfaceTintColor?.resolve({}), Colors.transparent);
      expect(anchor.style?.elevation?.resolve({}), CoeloElevation.level2);
    }
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
      final actionRect = tester.getRect(_menuItemWithText('Perfil'));
      final panelRects =
          find
              .ancestor(of: _menuItemWithText('Perfil'), matching: find.byType(Material))
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
      expect(panelRect.right, lessThanOrEqualTo(triggerRect.right));
      expect(panelRect.right, lessThanOrEqualTo(width - CoeloSpacing.space2));
      expect(panelRect.left, greaterThanOrEqualTo(CoeloSpacing.space2));
      expect(panelRect.bottom, lessThanOrEqualTo(800));

      await tester.tap(trigger);
      await tester.pumpAndSettle();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('opens the rounded profile menu below its trigger', (tester) async {
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

    final trigger = find.byKey(const Key('superadmin-profile-menu'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final logout = tester.widget<MenuItemButton>(_menuItemWithText('Sair'));
    final profile = tester.widget<MenuItemButton>(_menuItemWithText('Perfil'));
    final settings = tester.widget<MenuItemButton>(_menuItemWithText('Configurações'));
    expect(logout.style?.foregroundColor?.resolve({}), CoeloTheme.light.colorScheme.error);
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
        action.style?.backgroundColor?.resolve({WidgetState.hovered}),
        CoeloTheme.light.colorScheme.primaryContainer,
      );
      expect(action.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    }
    expect(
      tester.getTopLeft(_menuItemWithText('Perfil')).dy,
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
    await tester.tap(_menuItemWithText('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('superadmin-logout-dialog')),
        matching: find.text('Sair'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(LogoutResult.genericFailureMessage), findsOneWidget);
  });

  testWidgets('opens notifications and the bug report form', (tester) async {
    final activities = SuperadminActivityController();
    addTearDown(activities.dispose);
    activities.completeDemoExport(SuperadminExportFormat.csv);
    await tester.pumpWidget(_shellApp(activities: activities, onBugReportSubmitted: (_) {}));

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
    await tester.tap(_menuItemWithText('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações será implementado em breve.'), findsNothing);
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
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

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
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('submits a bug report with current screen, multiline text and demo attachment', (
    tester,
  ) async {
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));

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
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    final refreshedDescription = find.byKey(const Key('superadmin-bug-description'));
    await tester.enterText(refreshedDescription, 'A tabela não atualizou após o filtro.');
    await tester.tap(find.byKey(const Key('superadmin-bug-attach')));
    await tester.pump();
    expect(find.text('evidencia-anexada.png'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    final otherOption = find.byKey(const Key('superadmin-bug-menu-option-Outros'));
    await tester.scrollUntilVisible(otherOption, 160, scrollable: find.byType(Scrollable).last);
    await tester.tap(otherOption.hitTestable());
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
    final otherOption = find.byKey(const Key('superadmin-bug-menu-option-Outros'));
    await tester.scrollUntilVisible(otherOption, 160, scrollable: find.byType(Scrollable).last);
    await tester.tap(otherOption.hitTestable());
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
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-bug-menu')));
    await tester.pumpAndSettle();
    final bugMenuAnchor = tester.widget<MenuAnchor>(
      find.descendant(
        of: find.byKey(const Key('superadmin-bug-menu')),
        matching: find.byType(MenuAnchor),
      ),
    );
    expect(bugMenuAnchor.style?.surfaceTintColor?.resolve({}), Colors.transparent);
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
    await tester.pumpWidget(_shellApp(onBugReportSubmitted: (_) {}));
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
    expect(find.text('Tour desta tela'), findsOneWidget);
    expect(find.text('Tour do menu'), findsOneWidget);
    expect(find.text('Tour completo'), findsOneWidget);

    await tester.tap(
      find.text('Tour desta tela'),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('O tour desta tela será implementado na etapa final.'), findsNothing);

    for (final option in {
      'Tour desta tela': 'O tour desta tela será implementado na etapa final.',
      'Tour do menu': 'O tour do menu será implementado na etapa final.',
      'Tour completo': 'O tour completo será implementado na etapa final.',
    }.entries) {
      await tester.tap(find.text(option.key));
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
    var firstOption = _menuItemWithText('Tour desta tela');
    var sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    expect(tester.getTopLeft(firstOption).dx, greaterThanOrEqualTo(tester.getTopRight(trigger).dx));
    expect(tester.getTopLeft(firstOption).dx, sidebarRect.right + CoeloSpacing.space1);
    expect(
      tester.getRect(_menuItemWithText('Tour completo')).bottom,
      lessThanOrEqualTo(800 - (CoeloSpacing.space2 * 2)),
    );
    var tourAnchor = tester.widget<MenuAnchor>(
      find.ancestor(of: trigger, matching: find.byType(MenuAnchor)).first,
    );
    expect(tourAnchor.alignmentOffset, const Offset(252 - CoeloSpacing.space1, 0));

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    trigger = find.byKey(const Key('superadmin-onboarding-tour'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    firstOption = _menuItemWithText('Tour desta tela');
    sidebarRect = tester.getRect(find.byKey(const Key('superadmin-sidebar')));
    expect(tester.getTopLeft(firstOption).dx, greaterThanOrEqualTo(tester.getTopRight(trigger).dx));
    expect(tester.getTopLeft(firstOption).dx, sidebarRect.right + CoeloSpacing.space1);
    expect(tester.getRect(firstOption).right, lessThanOrEqualTo(1200));
    final collapsedPanelBottom =
        tester.getRect(_menuItemWithText('Tour completo')).bottom + CoeloSpacing.space2;
    expect(collapsedPanelBottom, lessThanOrEqualTo(800 - CoeloSpacing.space2));
    tourAnchor = tester.widget<MenuAnchor>(
      find.ancestor(of: trigger, matching: find.byType(MenuAnchor)).first,
    );
    expect(tourAnchor.alignmentOffset, const Offset(CoeloSize.touchMin + CoeloSpacing.space4, 0));
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

  testWidgets('keeps compact navigation in the official header and drawer', (tester) async {
    for (final width in [375.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        _shellApp(currentDestination: 'institutions', textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('superadmin-compact-navigation')), findsNothing);
      expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);
      final menu = find.byKey(const Key('superadmin-mobile-menu'));
      expect(tester.getSize(menu).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen, isTrue);
      expect(find.byKey(const Key('superadmin-navigation-search')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'compact width $width at 200% text');
      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await tester.pumpAndSettle();
    }

    await tester.binding.setSurfaceSize(const Size(1024, 900));
    await tester.pumpWidget(_shellApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-compact-navigation')), findsNothing);
    expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

  testWidgets('uses only the unread loader injected by the composition root', (tester) async {
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shellApp(
        onDestinationSelected: (_) {},
        chatUnreadCountLoader: () async {
          calls += 1;
          return 3;
        },
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(find.text('3'), findsOneWidget);
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
  Future<int> Function()? chatUnreadCountLoader,
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
          chatUnreadCountLoader: chatUnreadCountLoader,
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

Finder _menuItemWithText(String label) {
  return find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));
}
