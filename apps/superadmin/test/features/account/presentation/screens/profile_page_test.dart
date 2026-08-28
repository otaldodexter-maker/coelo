import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/avatar_crop_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FailsOnceProfileRepository implements AccountProfileRepository {
  AccountProfile _profile = AccountProfile.prototype();
  var _failsNextSave = true;

  @override
  Future<AccountProfile> load() async => _profile;

  @override
  Future<void> save(AccountProfile profile) async {
    if (_failsNextSave) {
      _failsNextSave = false;
      throw StateError('save failed');
    }
    _profile = profile;
  }
}

final class _DeferredProfileRepository implements AccountProfileRepository {
  final Completer<AccountProfile> _load = Completer<AccountProfile>();

  void completeLoad(AccountProfile profile) => _load.complete(profile);

  @override
  Future<AccountProfile> load() => _load.future;

  @override
  Future<void> save(AccountProfile profile) async {}
}

final class _QueuedProfileRepository implements AccountProfileRepository {
  final loads = <Completer<AccountProfile>>[];

  @override
  Future<AccountProfile> load() {
    final completer = Completer<AccountProfile>();
    loads.add(completer);
    return completer.future;
  }

  @override
  Future<void> save(AccountProfile profile) async {}
}

void main() {
  testWidgets('hydrates the form once when a profile arrives after the page mounts', (
    tester,
  ) async {
    final repository = _DeferredProfileRepository();
    final activities = SuperadminActivityController();
    final controller = AccountController(repository: repository, activities: activities);
    final load = controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('account-mobile-phone-field')), findsNothing);

    repository.completeLoad(
      AccountProfile.prototype().copyWith(
        firstName: 'Maria',
        lastName: 'Silva',
        mobilePhone: '+55 11 98888-7777',
        avatar: const AccountAvatar(
          mode: AccountAvatarMode.initials,
          initials: 'MS',
          backgroundColor: Colors.teal,
        ),
      ),
    );
    await load;
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Maria');
    expect(_fieldValue(tester, const Key('account-mobile-phone-field')), '+55 11 98888-7777');
    expect(
      find.descendant(
        of: find.byKey(const Key('account-avatar-initials')),
        matching: find.text('MS'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Rascunho');
    await controller.changePassword(
      currentPassword: 'senha-atual-local',
      newPassword: 'NovaSenha123!',
      confirmation: 'NovaSenha123!',
    );
    await tester.pump();

    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Rascunho');
  });

  testWidgets('shows a recoverable load failure and retry hydrates the profile', (tester) async {
    final repository = _QueuedProfileRepository();
    final activities = SuperadminActivityController();
    final controller = AccountController(repository: repository, activities: activities);
    final firstLoad = controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    repository.loads.single.completeError(StateError('offline'));
    await firstLoad;
    await tester.pump();

    expect(find.text('Não foi possível carregar o perfil'), findsOneWidget);
    expect(find.byKey(const Key('account-first-name-field')), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(repository.loads, hasLength(2));
    repository.loads.last.complete(
      AccountProfile.prototype().copyWith(firstName: 'Perfil recuperado'),
    );
    await tester.pumpAndSettle();

    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Perfil recuperado');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows personal data, access and security cards', (tester) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('Meu acesso'), findsOneWidget);
    expect(find.text('Segurança'), findsOneWidget);
    expect(find.byKey(const Key('account-avatar-initials')), findsOneWidget);
    expect(find.byKey(const Key('account-mobile-phone-field')), findsOneWidget);
  });

  testWidgets('normalizes and validates custom avatar initials', (tester) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('account-initials-field')), 'abc');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    tester.widget<FilledButton>(find.byKey(const Key('account-save-profile'))).onPressed!();
    await tester.pump();

    expect(find.text('Use uma ou duas letras.'), findsOneWidget);
  });

  testWidgets('keeps the profile draft and shows recoverable feedback when save fails', (
    tester,
  ) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: _FailsOnceProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await _pumpProfilePage(tester, controller);

    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Maria');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    tester.widget<FilledButton>(find.byKey(const Key('account-save-profile'))).onPressed!();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Não foi possível salvar o perfil. Tente novamente.'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(controller.profile!.firstName, 'Owner');

    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    tester.widget<FilledButton>(find.byKey(const Key('account-save-profile'))).onPressed!();
    await tester.pumpAndSettle();

    expect(controller.profile!.firstName, 'Maria');
    expect(find.text('Perfil atualizado.'), findsOneWidget);
  });

  testWidgets('cancels every dirty field and restores the last confirmed profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activities = SuperadminActivityController();
    final repository = InMemoryAccountProfileRepository(
      initial: AccountProfile.prototype().copyWith(
        avatar: AccountAvatar(
          mode: AccountAvatarMode.photo,
          initials: 'XX',
          backgroundColor: Colors.black,
          photoBytes: Uint8List.fromList(_transparentPng),
        ),
      ),
    );
    final controller = AccountController(repository: repository, activities: activities);
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await _pumpProfilePage(tester, controller);

    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Maria');
    await tester.enterText(find.byKey(const Key('account-last-name-field')), 'Silva');
    await tester.enterText(find.byKey(const Key('account-email-field')), 'maria@coelo.me');
    await tester.enterText(
      find.byKey(const Key('account-mobile-phone-field')),
      '+55 11 90000-0000',
    );
    await tester.enterText(find.byKey(const Key('account-initials-field')), 'MS');
    await tester.ensureVisible(find.byKey(const Key('account-reset-profile')));
    await tester.tap(find.byKey(const Key('account-reset-profile')));
    await tester.pump();

    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Owner');
    expect(_fieldValue(tester, const Key('account-last-name-field')), 'Coelo');
    expect(_fieldValue(tester, const Key('account-email-field')), 'owner@coelo.me');
    expect(_fieldValue(tester, const Key('account-mobile-phone-field')), '+55 11 99999-0000');
    expect(_fieldValue(tester, const Key('account-initials-field')), 'XX');
    final beforeSave = await repository.load();
    expect(beforeSave.avatar.mode, AccountAvatarMode.photo);
    expect(beforeSave.avatar.backgroundColor, Colors.black);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('account-reset-profile'))).onPressed,
      isNull,
    );
  });

  testWidgets('clears tenant A draft and overlay before hydrating controller B', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activitiesA = SuperadminActivityController();
    final activitiesB = SuperadminActivityController();
    final controllerA = AccountController(
      repository: InMemoryAccountProfileRepository(
        initial: AccountProfile.prototype().copyWith(
          firstName: 'Perfil A',
          email: 'perfil-a@coelo.me',
          avatar: const AccountAvatar(
            mode: AccountAvatarMode.initials,
            initials: 'AA',
            backgroundColor: Colors.red,
          ),
        ),
      ),
      activities: activitiesA,
    );
    final controllerB = AccountController(
      repository: InMemoryAccountProfileRepository(
        initial: AccountProfile.prototype().copyWith(
          firstName: 'Perfil B',
          email: 'perfil-b@coelo.me',
          avatar: const AccountAvatar(
            mode: AccountAvatarMode.initials,
            initials: 'BB',
            backgroundColor: Colors.blue,
          ),
        ),
      ),
      activities: activitiesB,
    );
    await controllerA.load();
    await controllerB.load();
    addTearDown(() {
      controllerA.dispose();
      controllerB.dispose();
      activitiesA.dispose();
      activitiesB.dispose();
    });

    await _pumpProfilePage(tester, controllerA);
    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Rascunho A');
    await tester.tap(find.byKey(const Key('account-avatar-color-picker')));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(
          controller: controllerB,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cor da sigla'), findsNothing);
    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Perfil B');
    expect(_fieldValue(tester, const Key('account-email-field')), 'perfil-b@coelo.me');
    expect(_fieldValue(tester, const Key('account-initials-field')), 'BB');
    expect(find.text('Rascunho A'), findsNothing);
    expect(find.text('perfil-a@coelo.me'), findsNothing);
  });

  testWidgets('keeps only B when late reload A completes after controller swap', (tester) async {
    final repositoryA = _QueuedProfileRepository();
    final repositoryB = _QueuedProfileRepository();
    final activitiesA = SuperadminActivityController();
    final activitiesB = SuperadminActivityController();
    final controllerA = AccountController(repository: repositoryA, activities: activitiesA);
    final controllerB = AccountController(repository: repositoryB, activities: activitiesB);
    final initialA = controllerA.load();
    repositoryA.loads.single.complete(
      AccountProfile.prototype().copyWith(firstName: 'Perfil A', email: 'a@coelo.me'),
    );
    await initialA;
    addTearDown(() {
      controllerA.dispose();
      controllerB.dispose();
      activitiesA.dispose();
      activitiesB.dispose();
    });

    await _pumpProfilePage(tester, controllerA);
    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Rascunho A');
    final lateA = controllerA.load();
    final loadB = controllerB.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(
          controller: controllerB,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('account-first-name-field')), findsNothing);
    repositoryB.loads.single.complete(
      AccountProfile.prototype().copyWith(firstName: 'Perfil B', email: 'b@coelo.me'),
    );
    await loadB;
    await tester.pump();
    repositoryA.loads.last.complete(
      AccountProfile.prototype().copyWith(firstName: 'A tardio', email: 'late-a@coelo.me'),
    );
    await lateA;
    await tester.pumpAndSettle();

    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Perfil B');
    expect(_fieldValue(tester, const Key('account-email-field')), 'b@coelo.me');
    expect(find.text('Rascunho A'), findsNothing);
    expect(find.text('A tardio'), findsNothing);
    expect(find.text('late-a@coelo.me'), findsNothing);
  });

  testWidgets('same controller reload replaces A with B and returns to pristine', (tester) async {
    final repository = _QueuedProfileRepository();
    final activities = SuperadminActivityController();
    final controller = AccountController(repository: repository, activities: activities);
    final loadA = controller.load();
    repository.loads.single.complete(
      AccountProfile.prototype().copyWith(
        firstName: 'Perfil A',
        email: 'a@coelo.me',
        avatar: const AccountAvatar(
          mode: AccountAvatarMode.initials,
          initials: 'AA',
          backgroundColor: Colors.red,
        ),
      ),
    );
    await loadA;
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await _pumpProfilePage(tester, controller);
    await tester.enterText(find.byKey(const Key('account-first-name-field')), 'Rascunho A');

    final loadB = controller.load();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('account-first-name-field')), findsNothing);
    repository.loads.last.complete(
      AccountProfile.prototype().copyWith(
        firstName: 'Perfil B',
        email: 'b@coelo.me',
        avatar: const AccountAvatar(
          mode: AccountAvatarMode.initials,
          initials: 'BB',
          backgroundColor: Colors.blue,
        ),
      ),
    );
    await loadB;
    await tester.pumpAndSettle();

    expect(_fieldValue(tester, const Key('account-first-name-field')), 'Perfil B');
    expect(_fieldValue(tester, const Key('account-email-field')), 'b@coelo.me');
    expect(_fieldValue(tester, const Key('account-initials-field')), 'BB');
    expect(find.text('Rascunho A'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('account-save-profile'))).onPressed,
      isNull,
    );
  });

  testWidgets('email request and cancel rehydrate the confirmed pristine snapshot', (tester) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await _pumpProfilePage(tester, controller);

    await tester.enterText(find.byKey(const Key('account-email-field')), 'novo@coelo.me');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    await tester.tap(find.byKey(const Key('account-save-profile')));
    await tester.pumpAndSettle();

    expect(_fieldValue(tester, const Key('account-email-field')), 'owner@coelo.me');
    expect(find.text('novo@coelo.me · Aguardando aprovação'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('account-save-profile'))).onPressed,
      isNull,
    );

    await tester.ensureVisible(find.text('Cancelar solicitação'));
    await tester.tap(find.text('Cancelar solicitação'));
    await tester.pumpAndSettle();

    expect(_fieldValue(tester, const Key('account-email-field')), 'owner@coelo.me');
    expect(find.textContaining('Aguardando aprovação'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('account-reset-profile'))).onPressed,
      isNull,
    );
  });

  testWidgets('aligns the personal card with the access and security column on wide screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await _pumpProfilePage(tester, controller);

    final personalBottom = tester.getBottomLeft(find.byKey(const Key('account-personal-card'))).dy;
    final sideBottom = tester
        .getBottomLeft(find.byKey(const Key('account-profile-side-column')))
        .dy;
    expect((personalBottom - sideBottom).abs(), lessThanOrEqualTo(CoeloSpacing.space5));
  });

  testWidgets('keeps personal, access and security cards in sequence on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await _pumpProfilePage(tester, controller);

    final personal = find.byKey(const Key('account-personal-card'));
    final access = find.byKey(const Key('account-access-card'));
    final security = find.byKey(const Key('account-security-card'));
    expect(tester.getBottomLeft(personal).dy, lessThan(tester.getTopLeft(access).dy));
    expect(tester.getBottomLeft(access).dy, lessThan(tester.getTopLeft(security).dy));
    expect(tester.getSize(find.byKey(const Key('account-save-profile'))).width, greaterThan(300));
  });

  testWidgets('keeps profile controls accessible at 200 percent text on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('account-reset-profile')));
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    expect(find.byKey(const Key('account-reset-profile')), findsOneWidget);
    expect(find.byKey(const Key('account-save-profile')), findsOneWidget);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('renders profile at ${width.toInt()}px and ${textScale.toInt()}00 percent', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final activities = SuperadminActivityController();
        final controller = AccountController(
          repository: InMemoryAccountProfileRepository(),
          activities: activities,
        );
        await controller.load();
        addTearDown(() {
          controller.dispose();
          activities.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: ProfilePage(
              controller: controller,
              logout: () async => const LogoutResult.success(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('account-personal-card')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
        expect(find.byKey(const Key('account-save-profile')), findsOneWidget);
      });
    }
  }

  testWidgets('does not collect password secrets while the capability is unavailable', (
    tester,
  ) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await _pumpProfilePage(tester, controller);

    final unavailable = tester.widget<OutlinedButton>(
      find.byKey(const Key('account-password-unavailable')),
    );
    expect(unavailable.onPressed, isNull);
    expect(find.text('Alteração de senha indisponível nesta versão.'), findsOneWidget);
    expect(find.byKey(const Key('account-password-dialog')), findsNothing);
    expect(find.text('Senha atual'), findsNothing);
  });

  testWidgets('uses the canonical shell and balanced actions for avatar crop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<AvatarCropResult>(
              context: context,
              builder: (context) => AvatarCropDialog(bytes: Uint8List.fromList(_transparentPng)),
            ),
            child: const Text('Abrir recorte'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir recorte'));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
    final apply = find.widgetWithText(FilledButton, 'Aplicar');
    expect(cancel, findsOneWidget);
    expect(apply, findsOneWidget);
    expect(tester.getSize(cancel).width, tester.getSize(apply).width);
  });
}

String _fieldValue(WidgetTester tester, Key key) => tester
    .widget<EditableText>(find.descendant(of: find.byKey(key), matching: find.byType(EditableText)))
    .controller
    .text;

Future<void> _pumpProfilePage(WidgetTester tester, AccountController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
    ),
  );
  await tester.pumpAndSettle();
}

const _transparentPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
