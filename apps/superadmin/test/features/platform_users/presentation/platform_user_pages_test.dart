import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates an exclusive Superadmin access through four steps', (tester) async {
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

    expect(find.textContaining('acesso interno exclusivo ao Superadmin'), findsWidgets);
    expect(find.byKey(const Key('platform-user-birth-date')), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    await tester.enterText(find.byKey(const Key('platform-user-first-name')), 'Lia');
    await tester.enterText(find.byKey(const Key('platform-user-last-name')), 'Coelo');
    await tester.enterText(find.byKey(const Key('platform-user-cpf')), '52998224725');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Contato e informações profissionais'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('platform-user-email')), 'lia@coelo.me');
    await tester.enterText(find.byKey(const Key('platform-user-job-title')), 'Analista');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Acesso ao Superadmin'), findsWidgets);
    final scope = tester.widget<CoeloAdminMultiSelectField<String>>(
      find.byType(CoeloAdminMultiSelectField<String>),
    );
    scope.onChanged(const {'institution-1'});
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Revisão'), findsOneWidget);
    expect(find.textContaining('Confira o e-mail profissional'), findsOneWidget);
    expect(find.text('***.***.***-25'), findsOneWidget);
    expect(find.text('l***@coelo.me'), findsOneWidget);
    await tester.tap(find.text('Criar e preparar convite'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.record.status, PlatformMembershipStatus.invited);
    expect(saved!.record.invitationStatus, PlatformInvitationStatus.pending);
    expect(saved!.record.credentialStatus, SuperadminCredentialStatus.noAccess);
    expect(saved!.invitationSent, isFalse);
  });

  testWidgets('compact form has simple surface and no horizontal overflow', (tester) async {
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

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('platform-user-form-scroll')),
    );
    expect((scroll.padding! as EdgeInsets).bottom, greaterThan(CoeloSpacing.space4));
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('platform-user-form-footer-surface'))).width,
      greaterThan(250),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('active credential keeps professional email read only during edit', (tester) async {
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
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final email = tester.widget<TextFormField>(find.byKey(const Key('platform-user-email')));
    expect(email.enabled, isFalse);
    expect(email.controller!.text, user.email);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Permissões derivadas'), findsOneWidget);
    expect(find.textContaining('não podem ser ampliadas'), findsOneWidget);
  });
}
