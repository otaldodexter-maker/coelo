import 'dart:async';

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

final class _FailOnDemandAccountProfileRepository implements AccountProfileRepository {
  AccountProfile _profile = AccountProfile.prototype();
  bool failNextSave = false;

  @override
  Future<AccountProfile> load() async => _profile;

  @override
  Future<void> save(AccountProfile profile) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    _profile = profile;
  }
}

final class _DeferredAccountProfileRepository implements AccountProfileRepository {
  _DeferredAccountProfileRepository({AccountProfile? initial})
    : profile = initial ?? AccountProfile.prototype();

  AccountProfile profile;
  final loadCompleters = <Completer<AccountProfile>>[];
  final saveCompleters = <Completer<void>>[];
  final savedProfiles = <AccountProfile>[];
  var loadCalls = 0;

  @override
  Future<AccountProfile> load() {
    loadCalls += 1;
    final completer = Completer<AccountProfile>();
    loadCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> save(AccountProfile next) {
    savedProfiles.add(next);
    final completer = Completer<void>();
    saveCompleters.add(completer);
    return completer.future.then((_) => profile = next);
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

  test('load exposes typed failure and retry reaches ready', () async {
    final deferred = _DeferredAccountProfileRepository();
    final deferredActivities = SuperadminActivityController();
    final deferredController = AccountController(
      repository: deferred,
      activities: deferredActivities,
    );
    addTearDown(() {
      deferredController.dispose();
      deferredActivities.dispose();
    });

    final first = deferredController.load();
    expect(deferredController.state.phase, AccountControllerPhase.loading);
    expect(deferredController.profile, isNull);
    deferred.loadCompleters.single.completeError(StateError('offline'));
    await first;

    expect(deferredController.state.phase, AccountControllerPhase.failure);
    expect(deferredController.message, 'Não foi possível carregar o perfil. Tente novamente.');

    final retry = deferredController.load();
    expect(deferredController.state.phase, AccountControllerPhase.loading);
    deferred.loadCompleters.last.complete(deferred.profile);
    await retry;

    expect(deferredController.state.phase, AccountControllerPhase.ready);
    expect(deferredController.profile, deferred.profile);
    expect(deferredController.message, isNull);
  });

  test('pending loads ignore every completion after dispose', () async {
    final deferred = _DeferredAccountProfileRepository();
    final deferredActivities = SuperadminActivityController();
    final deferredController = AccountController(
      repository: deferred,
      activities: deferredActivities,
    );
    var notifications = 0;
    deferredController.addListener(() => notifications += 1);

    final first = deferredController.load();
    final second = deferredController.load();
    expect(deferred.loadCalls, 2);
    final beforeDispose = notifications;
    deferredController.dispose();
    for (final completer in deferred.loadCompleters) {
      completer.complete(deferred.profile);
    }
    await Future.wait([first, second]);

    expect(notifications, beforeDispose);
    deferredActivities.dispose();
  });

  test('new reload supersedes an older pending load', () async {
    final deferred = _DeferredAccountProfileRepository();
    final deferredActivities = SuperadminActivityController();
    final deferredController = AccountController(
      repository: deferred,
      activities: deferredActivities,
    );
    addTearDown(() {
      deferredController.dispose();
      deferredActivities.dispose();
    });

    final loadA = deferredController.load();
    final loadB = deferredController.load();
    expect(deferred.loadCalls, 2);
    deferred.loadCompleters[1].complete(
      deferred.profile.copyWith(firstName: 'Perfil B', email: 'b@coelo.me'),
    );
    await loadB;
    deferred.loadCompleters[0].complete(
      deferred.profile.copyWith(firstName: 'Perfil A tardio', email: 'a@coelo.me'),
    );
    await loadA;

    expect(deferredController.profile!.firstName, 'Perfil B');
    expect(deferredController.profile!.email, 'b@coelo.me');
    expect(deferredController.state.updateOrigin, AccountProfileUpdateOrigin.load);
  });

  test('profile mutations share one lock and discard completion after dispose', () async {
    final deferred = _DeferredAccountProfileRepository(
      initial: AccountProfile.prototype().requestEmailChange('pending@coelo.me'),
    );
    final deferredActivities = SuperadminActivityController();
    final deferredController = AccountController(
      repository: deferred,
      activities: deferredActivities,
    );
    final load = deferredController.load();
    deferred.loadCompleters.single.complete(deferred.profile);
    await load;

    final save = deferredController.saveProfile(
      firstName: 'Maria',
      lastName: 'Silva',
      email: 'maria@coelo.me',
      mobilePhone: '+55 11 98888-7777',
      avatar: deferredController.profile!.avatar,
    );
    final cancel = deferredController.cancelEmailChange();
    expect(deferred.savedProfiles, hasLength(1));
    expect(deferredController.busy, isTrue);
    expect(deferred.savedProfiles.single.emailChange?.requestedEmail, 'maria@coelo.me');

    deferredController.dispose();
    deferred.saveCompleters.single.complete();
    await Future.wait([save, cancel]);

    expect(deferredActivities.activities, isEmpty);
    deferredActivities.dispose();
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

  test('save failure reports an error, clears prior success and permits a retry', () async {
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

    await saveDraft();

    expect(failingController.busy, isFalse);
    expect(failingController.profile!.firstName, 'Owner');
    expect(failingController.profile!.emailChange, isNull);
    expect(failingActivities.activities, isEmpty);
    expect(failingController.message, 'Não foi possível salvar o perfil. Tente novamente.');

    await saveDraft();

    expect(failingController.busy, isFalse);
    expect(failingController.profile!.firstName, 'Maria');
    expect(failingController.profile!.emailChange?.requestedEmail, 'maria@coelo.me');
    expect(failingActivities.activities, hasLength(1));

    failingController.dispose();
    failingActivities.dispose();
  });

  test('a save failure replaces a previous success message', () async {
    final failingRepository = _FailOnDemandAccountProfileRepository();
    final failingActivities = SuperadminActivityController();
    final failingController = AccountController(
      repository: failingRepository,
      activities: failingActivities,
    );
    await failingController.load();
    addTearDown(() {
      failingController.dispose();
      failingActivities.dispose();
    });

    await failingController.saveProfile(
      firstName: 'Maria',
      lastName: 'Silva',
      email: 'owner@coelo.me',
      mobilePhone: '+55 11 98888-7777',
      avatar: failingController.profile!.avatar,
    );
    expect(failingController.message, 'Perfil atualizado.');

    failingRepository.failNextSave = true;
    await failingController.saveProfile(
      firstName: 'Ana',
      lastName: 'Lima',
      email: 'owner@coelo.me',
      mobilePhone: '+55 11 97777-6666',
      avatar: failingController.profile!.avatar,
    );

    expect(failingController.profile!.firstName, 'Maria');
    expect(failingController.message, 'Não foi possível salvar o perfil. Tente novamente.');
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

  test('password change validates input and remains fail-closed without backend', () async {
    expect(
      await controller.changePassword(
        currentPassword: '',
        newPassword: 'NovaSenha123!',
        confirmation: 'NovaSenha123!',
      ),
      'Informe a senha atual.',
    );
    expect(
      await controller.changePassword(
        currentPassword: 'senha-atual-local',
        newPassword: 'NovaSenha123!',
        confirmation: 'diferente',
      ),
      'As senhas não coincidem.',
    );
    expect(
      await controller.changePassword(
        currentPassword: 'senha-atual-local',
        newPassword: 'NovaSenha123!',
        confirmation: 'NovaSenha123!',
      ),
      'Troca de senha indisponível nesta versão.',
    );
  });
}
