import 'dart:typed_data';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    await tester.tap(find.byKey(const Key('account-save-profile')));
    await tester.pump();

    expect(find.text('Use uma ou duas letras.'), findsOneWidget);
  });

  testWidgets('resets a photo avatar as a draft and saves the derived initials', (tester) async {
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
    await tester.ensureVisible(find.byKey(const Key('account-reset-profile')));
    await tester.tap(find.byKey(const Key('account-reset-profile')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('account-avatar-initials')),
        matching: find.text('MS'),
      ),
      findsOneWidget,
    );
    final beforeSave = await repository.load();
    expect(beforeSave.avatar.mode, AccountAvatarMode.photo);
    expect(beforeSave.avatar.backgroundColor, Colors.black);

    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    await tester.tap(find.byKey(const Key('account-save-profile')));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.avatar.mode, AccountAvatarMode.initials);
    expect(saved.avatar.initials, 'MS');
    expect(saved.avatar.backgroundColor, AccountAvatar.defaultBackgroundColor);
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

    expect(
      tester.getBottomLeft(find.byKey(const Key('account-personal-card'))).dy,
      tester.getBottomLeft(find.byKey(const Key('account-profile-side-column'))).dy,
    );
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
}

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
