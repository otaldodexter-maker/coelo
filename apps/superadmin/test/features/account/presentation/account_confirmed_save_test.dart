import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServerProfileRepository implements AccountProfileRepository {
  final original = AccountProfile.prototype();
  @override
  Future<AccountProfile> load() async => original;
  @override
  Future<AccountProfile> save(AccountProfile profile) async =>
      original.copyWith(firstName: profile.firstName);
}

void main() {
  test('header state uses server confirmation and warns when avatar was not saved', () async {
    final repository = _ServerProfileRepository();
    final activities = SuperadminActivityController();
    final controller = AccountController(repository: repository, activities: activities);
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await controller.load();
    final profile = controller.profile!;
    await controller.saveProfile(
      firstName: 'Nome confirmado',
      lastName: profile.lastName,
      email: profile.email,
      mobilePhone: profile.mobilePhone,
      avatar: profile.avatar.copyWith(backgroundColor: Colors.blue),
    );
    expect(controller.profile!.firstName, 'Nome confirmado');
    expect(controller.profile!.avatar.backgroundColor, repository.original.avatar.backgroundColor);
    expect(controller.message, contains('não confirmou'));
  });
}
