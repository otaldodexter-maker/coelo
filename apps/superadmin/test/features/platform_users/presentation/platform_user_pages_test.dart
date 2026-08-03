import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_detail_page.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates through five explicit preview steps', (tester) async {
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

    expect(find.text('Identidade'), findsWidgets);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('platform-user-form-footer-surface')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('platform-user-first-name')), 'Lia');
    await tester.enterText(find.byKey(const Key('platform-user-last-name')), 'Coelo');
    await tester.enterText(find.byKey(const Key('platform-user-email')), 'lia@coelo.me');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Membership de plataforma'), findsWidgets);
    expect(find.text('Convidado'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Papel'), findsWidgets);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Escopo'), findsWidgets);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum convite real será enviado.'), findsOneWidget);
    expect(find.textContaining('CPF'), findsNothing);
    expect(find.textContaining('Supabase'), findsNothing);
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

  testWidgets('uses a measured compact form footer without covering content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserFormPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = tester.widget<ListView>(find.byKey(const Key('platform-user-form-scroll')));
    expect((scroll.padding! as EdgeInsets).bottom, greaterThan(CoeloSpacing.space4));
    expect(
      tester.getSize(find.byKey(const Key('platform-user-form-footer-surface'))).width,
      greaterThan(250),
    );
    expect(tester.takeException(), isNull);
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
    expect(email.controller!.text, user.maskedEmail);
    expect(find.text(user.email), findsNothing);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Permissões derivadas do papel'), findsOneWidget);
    expect(find.text('Overrides não são editáveis neste preview.'), findsOneWidget);
  });
}
