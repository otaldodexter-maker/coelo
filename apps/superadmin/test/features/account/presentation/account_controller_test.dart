import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FailsOnceAccountProfileRepository implements AccountProfileRepository {
  AccountProfile _profile = AccountProfile.prototype();
  bool _failsNextSave = true;

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
      mobilePhone: controller.profile!.mobilePhone,
      avatar: controller.profile!.avatar,
    );

    expect(controller.profile!.email, 'owner@coelo.me');
    expect(controller.profile!.emailChange?.status, EmailChangeStatus.pending);
    expect(activities.activities.single.kind, SuperadminActivityKind.emailApproval);
    expect(activities.activities.single.actionStatus, SuperadminActivityActionStatus.pending);
  });

  test('saves the trimmed mobile phone in the profile', () async {
    await controller.saveProfile(
      firstName: 'Owner',
      lastName: 'Coelo',
      email: 'owner@coelo.me',
      mobilePhone: ' +55 11 98888-7777 ',
      avatar: controller.profile!.avatar,
    );

    expect(controller.profile!.mobilePhone, '+55 11 98888-7777');
  });

  test('save failure keeps the draft state and permits a retry', () async {
    final failingRepository = _FailsOnceAccountProfileRepository();
    final failingActivities = SuperadminActivityController();
    final failingController = AccountController(
      repository: failingRepository,
      activities: failingActivities,
    );
    await failingController.load();

    Future<void> saveDraft() => failingController.saveProfile(
      firstName: 'Maria',
      lastName: 'Silva',
      email: 'maria@coelo.me',
      mobilePhone: '+55 11 98888-7777',
      avatar: failingController.profile!.avatar,
    );

    await expectLater(saveDraft(), throwsA(isA<StateError>()));

    expect(failingController.busy, isFalse);
    expect(failingController.profile!.firstName, 'Owner');
    expect(failingController.profile!.emailChange, isNull);
    expect(failingActivities.activities, isEmpty);

    await saveDraft();

    expect(failingController.busy, isFalse);
    expect(failingController.profile!.firstName, 'Maria');
    expect(failingController.profile!.emailChange?.requestedEmail, 'maria@coelo.me');
    expect(failingActivities.activities, hasLength(1));

    failingController.dispose();
    failingActivities.dispose();
  });

  test('approval applies the pending email and updates the activity', () async {
    await controller.saveProfile(
      firstName: 'Owner',
      lastName: 'Coelo',
      email: 'novo@coelo.me',
      mobilePhone: controller.profile!.mobilePhone,
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
      mobilePhone: controller.profile!.mobilePhone,
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
