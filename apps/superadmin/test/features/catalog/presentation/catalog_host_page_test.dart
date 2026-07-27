import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/catalog/presentation/catalog_host_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects the catalog when it shares the Superadmin origin', () {
    expect(
      resolveCatalogOrigin(
        'https://superadmin.coelo.me',
        hostOrigin: 'https://superadmin.coelo.me',
      ),
      isNull,
    );
  });

  testWidgets('hosts a configured private catalog inside the Superadmin shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CatalogHostPage(
          catalogUrl: 'https://catalog.coelo.me',
          logout: _logout,
          onInstitutionsOpen: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catálogo'), findsWidgets);
    expect(find.byKey(const Key('catalog-platform-fallback')), findsOneWidget);
    expect(find.text('Abrir catálogo em nova aba'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-catalog')), findsOneWidget);
  });

  testWidgets('opens conversations through its specific shell capability', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var conversationsOpened = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CatalogHostPage(
          catalogUrl: 'https://catalog.coelo.me',
          logout: _logout,
          onInstitutionsOpen: () {},
          onConversationsOpen: () => conversationsOpened += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expandir conversas'));

    expect(conversationsOpened, 1);
  });

  testWidgets('rejects a catalog URL without an allowed web origin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CatalogHostPage(
          catalogUrl: 'http://catalog.coelo.me',
          logout: _logout,
          onInstitutionsOpen: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Endereço do catálogo indisponível'), findsOneWidget);
    expect(find.byKey(const Key('catalog-platform-fallback')), findsNothing);
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();
