import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryAccountProfileRepository repository;
  late SuperadminActivityController activities;
  late AccountController controller;

  setUp(() async {
    repository = InMemoryAccountProfileRepository();
    activities = SuperadminActivityController();
    controller = AccountController(repository: repository, activities: activities);
    await controller.load();
  });

  tearDown(() {
    controller.dispose();
    activities.dispose();
  });

  test('requests an email change and publishes an actionable activity', () async {
    await controller.saveProfile(
      firstName: 'Owner',
      lastName: 'Coelo',
      email: 'novo@coelo.me',
      avatar: controller.profile!.avatar,
    );

    expect(controller.profile!.email, 'owner@coelo.me');
    expect(controller.profile!.emailChange?.status, EmailChangeStatus.pending);
    expect(activities.activities.single.kind, SuperadminActivityKind.emailApproval);
    expect(activities.activities.single.actionStatus, SuperadminActivityActionStatus.pending);
  });

  test('approval applies the pending email and updates the activity', () async {
    await controller.saveProfile(
      firstName: 'Owner',
      lastName: 'Coelo',
      email: 'novo@coelo.me',
      avatar: controller.profile!.avatar,
    );
    final activity = activities.activities.single;

    await controller.resolveEmailChange(activity.id, approved: true);

    expect(controller.profile!.email, 'novo@coelo.me');
    expect(activities.activities.single.actionStatus, SuperadminActivityActionStatus.approved);
  });

  test('cancel removes a pending request and its activity', () async {
    await controller.saveProfile(
      firstName: 'Owner',
      lastName: 'Coelo',
      email: 'novo@coelo.me',
      avatar: controller.profile!.avatar,
    );

    await controller.cancelEmailChange();

    expect(controller.profile!.emailChange, isNull);
    expect(activities.activities, isEmpty);
  });

  test('password change validates current password and confirmation locally', () async {
    expect(
      await controller.changePassword(
        currentPassword: 'incorreta',
        newPassword: 'NovaSenha123!',
        confirmation: 'NovaSenha123!',
      ),
      'A senha atual não confere.',
    );
    expect(
      await controller.changePassword(
        currentPassword: 'coelo-demo',
        newPassword: 'NovaSenha123!',
        confirmation: 'diferente',
      ),
      'As senhas não coincidem.',
    );
    expect(
      await controller.changePassword(
        currentPassword: 'coelo-demo',
        newPassword: 'NovaSenha123!',
        confirmation: 'NovaSenha123!',
      ),
      isNull,
    );
  });
}
