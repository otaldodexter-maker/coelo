import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the approved floating hierarchical navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shellApp());

    expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);

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
    expect(find.byKey(const Key('superadmin-navigation-flyout-structure')), findsOneWidget);
    final triggerRect = tester.getRect(
      find.byKey(const Key('superadmin-navigation-section-structure')),
    );
    final flyoutRect = tester.getRect(
      find.byKey(const Key('superadmin-navigation-flyout-structure')),
    );
    expect(flyoutRect.left, greaterThanOrEqualTo(triggerRect.right));
    expect((flyoutRect.top - triggerRect.top).abs(), lessThanOrEqualTo(CoeloSpacing.space2));
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
    expect(units.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(units.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.primary);
    expect(units.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
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
      const Size(24, 24),
    );
    expect(tester.getSize(find.byKey(const Key('superadmin-brand-mark'))), const Size(48, 48));
    expect(find.byKey(const Key('superadmin-brand-logo-light')), findsOneWidget);

    final activeDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('superadmin-navigation-institutions')),
                )
                .decoration!
            as BoxDecoration;
    expect(activeDecoration.color, CoeloTheme.light.colorScheme.primary.withValues(alpha: 0.10));
    final activeSectionDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('superadmin-navigation-section-structure')),
                )
                .decoration!
            as BoxDecoration;
    expect(activeSectionDecoration.color, CoeloTheme.light.colorScheme.primary);
    final inactiveSectionDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('superadmin-navigation-section-access')),
                )
                .decoration!
            as BoxDecoration;
    expect(
      inactiveSectionDecoration.color,
      CoeloTheme.light.colorScheme.primaryContainer.withValues(alpha: 0),
    );
    final inactiveDestinationDecoration =
        tester
                .widget<AnimatedContainer>(find.byKey(const Key('superadmin-navigation-units')))
                .decoration!
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

    final decoration = tester.widget<AnimatedContainer>(access).decoration! as BoxDecoration;
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
        find.descendant(
          of: drawer,
          matching: find.byKey(
            Key(
              configuration.brightness == Brightness.dark
                  ? 'superadmin-brand-logo-dark'
                  : 'superadmin-brand-logo-light',
            ),
          ),
        ),
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
    final logoutButton = find.byKey(const Key('superadmin-logout-action'));
    expect(logoutButton, findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('keeps the compact profile menu close to the right edge', (tester) async {
    for (final width in [375.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_shellApp());
      await tester.pumpAndSettle();

      final trigger = find.byKey(const Key('superadmin-profile-menu'));
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      final profileActionRect = tester.getRect(find.byKey(const Key('superadmin-profile-action')));
      expect(
        profileActionRect.right,
        inInclusiveRange(width - CoeloSpacing.space4, width - CoeloSpacing.space2),
        reason: 'viewport $width, trigger ${tester.getRect(trigger)}, action $profileActionRect',
      );

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
    expect(lightDecoration.shape, BoxShape.circle);
    expect(lightDecoration.color, CoeloTheme.light.colorScheme.primary);
    expect(find.byKey(const Key('superadmin-brand-logo-light')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-brand-logo-dark')), findsNothing);

    await tester.pumpWidget(_shellApp(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final darkMark = tester.widget<Container>(find.byKey(const Key('superadmin-brand-mark')));
    final darkDecoration = darkMark.decoration! as BoxDecoration;
    expect(darkDecoration.shape, BoxShape.circle);
    expect(darkDecoration.color, CoeloPalette.neutral0);
    expect(find.byKey(const Key('superadmin-brand-logo-dark')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-brand-logo-light')), findsNothing);
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

  testWidgets('shows safe feedback for header utility actions', (tester) async {
    await tester.pumpWidget(_shellApp());

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pump();
    expect(find.text('As notificações serão implementadas em breve.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pump();
    expect(find.text('O reporte de bugs será implementado em breve.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-settings-action')));
    await tester.pumpAndSettle();
    expect(find.text('Configurações será implementado em breve.'), findsOneWidget);
  });

  testWidgets('uses a horizontal and vertical binary theme toggle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeShellHarness());

    final control = find.byKey(const Key('superadmin-theme-mode-control'));
    expect(control, findsOneWidget);
    expect(find.text('Seguir o sistema'), findsNothing);
    expect(tester.getSize(control), const Size(160, 40));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('superadmin-sidebar')))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-theme-mode-control')), findsOneWidget);
    expect(tester.getSize(control), const Size(40, 80));

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('superadmin-sidebar')))).brightness,
      Brightness.light,
    );
  });

  testWidgets('stays responsive at the supported viewport widths', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_shellApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'viewport $width');
      if (width >= CoeloBreakpoints.expanded.minWidth) {
        expect(find.byKey(const Key('superadmin-floating-sidebar')), findsOneWidget);
        expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('superadmin-mobile-menu')), findsOneWidget);
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

class _ThemeShellHarness extends StatefulWidget {
  const _ThemeShellHarness();

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
      builder: (context, child) => SuperadminThemeModeScope(
        mode: _mode,
        onChanged: (mode) => setState(() => _mode = mode),
        child: child!,
      ),
      home: SuperadminShell(
        logout: () async => const LogoutResult.success(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

Widget _shellApp({Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: SuperadminShell(
      logout: () async => const LogoutResult.success(),
      child: const SizedBox.expand(),
    ),
  );
}
