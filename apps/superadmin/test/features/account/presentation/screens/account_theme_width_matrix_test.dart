import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cobre a matriz de largura por tema que os goldens de Minha conta deixam fora.
///
/// `account_pages_golden_test.dart` amarra o tema a largura — light apenas
/// abaixo de 1024 e dark apenas acima — entao dark em 375 e 768, e light em 1024
/// e 1440, nunca sao renderizados por aquela suite. Acrescentar goldens exigiria
/// aprovacao nominal da baseline; estes casos nao dependem de imagem de
/// referencia: verificam que a tela renderiza sem excecao de layout e que o
/// brilho efetivo e o esperado.
void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final scale in [1.0, 2.0]) {
        final label = '${width.toInt()}px em ${brightness.name} a ${(scale * 100).toInt()}%';

        testWidgets('Configuracoes renderiza sem overflow a $label', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
          addTearDown(controller.dispose);
          await controller.load();

          await tester.pumpWidget(
            _app(
              brightness,
              SettingsPage(
                controller: controller,
                logout: () async => const LogoutResult.success(),
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(_effectiveBrightness(tester), brightness);
        });

        testWidgets('Perfil renderiza sem overflow a $label', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final activities = SuperadminActivityController();
          final controller = AccountController(
            repository: InMemoryAccountProfileRepository(),
            activities: activities,
          );
          addTearDown(() {
            controller.dispose();
            activities.dispose();
          });
          await controller.load();

          await tester.pumpWidget(
            _app(
              brightness,
              ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
              scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(_effectiveBrightness(tester), brightness);
        });
      }
    }
  }
}

Widget _app(Brightness brightness, Widget home, double scale) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Brightness _effectiveBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
