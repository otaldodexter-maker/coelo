import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_detail_page.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates through three steps with an explicit preview warning', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePlatformUserRepository();
    PlatformUserCreateResult? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserFormPage(
          repository: repository,
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
          onCreated: (result) => saved = result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identidade e contato'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('platform-user-first-name')), 'Lia');
    await tester.enterText(find.byKey(const Key('platform-user-last-name')), 'Coelo');
    await tester.enterText(find.byKey(const Key('platform-user-email')), 'lia@coelo.me');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso interno'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum convite real será enviado.'), findsOneWidget);
    await tester.tap(find.text('Salvar preview'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.invitationSent, isFalse);
  });

  testWidgets('views separated identity, membership, permissions and invitation sections', (
    tester,
  ) async {
    final repository = FakePlatformUserRepository();
    final user = repository.records.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: PlatformUserDetailPage(
          repository: repository,
          internalUserId: user.id,
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identidade'), findsOneWidget);
    expect(find.text('Vínculo interno'), findsOneWidget);
    expect(find.text('Papel e permissões'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Convite e status'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Convite e status'), findsOneWidget);
    expect(find.textContaining('MFA'), findsNothing);
  });

  testWidgets('keeps email and derived permissions read only while editing', (tester) async {
    final repository = FakePlatformUserRepository();
    final user = repository.records.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserFormPage(
          repository: repository,
          internalUserId: user.id,
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final email = tester.widget<TextFormField>(find.byKey(const Key('platform-user-email')));
    expect(email.enabled, isFalse);
    await tester.scrollUntilVisible(
      find.text('Permissões derivadas do papel'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Permissões derivadas do papel'), findsOneWidget);
    expect(find.text('Overrides não são editáveis neste preview.'), findsOneWidget);
  });
}
