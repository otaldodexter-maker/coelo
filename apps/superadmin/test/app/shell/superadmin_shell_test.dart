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

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-navigation-flyout-structure')), findsOneWidget);
    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Grupos'), findsOneWidget);
    final units = tester.widget<MenuItemButton>(
      find.byKey(const Key('superadmin-navigation-units')),
    );
    expect(
      units.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
    expect(
      units.style?.foregroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.primary,
    );
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
    expect(find.byKey(const Key('superadmin-brand-symbol')), findsOneWidget);

    final activeDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('superadmin-navigation-institutions')),
                )
                .decoration!
            as BoxDecoration;
    expect(activeDecoration.color, Colors.transparent);
    final activeSectionDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('superadmin-navigation-section-structure')),
                )
                .decoration!
            as BoxDecoration;
    expect(activeSectionDecoration.color, CoeloTheme.light.colorScheme.primary);

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

  testWidgets('opens the rounded profile menu below its trigger', (tester) async {
    await tester.pumpWidget(_shellApp());

    final trigger = find.byKey(const Key('superadmin-profile-menu'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final logout = tester.widget<MenuItemButton>(find.byKey(const Key('superadmin-logout-action')));
    expect(logout.style?.foregroundColor?.resolve({}), CoeloTheme.light.colorScheme.error);
    expect(
      logout.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
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

Widget _shellApp() {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: SuperadminShell(
      logout: () async => const LogoutResult.success(),
      child: const SizedBox.expand(),
    ),
  );
}
