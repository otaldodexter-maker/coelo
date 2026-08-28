import 'package:flutter/foundation.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../data/account_profile_repository.dart';
import '../domain/account_profile.dart';

enum AccountControllerPhase { idle, loading, ready, failure }

enum AccountProfileUpdateOrigin { load, save, cancelEmailChange, resolveEmailChange }

@immutable
final class AccountControllerState {
  const AccountControllerState({
    required this.phase,
    this.profile,
    this.busy = false,
    this.message,
    this.profileRevision = 0,
    this.updateOrigin,
  });

  final AccountControllerPhase phase;
  final AccountProfile? profile;
  final bool busy;
  final String? message;
  final int profileRevision;
  final AccountProfileUpdateOrigin? updateOrigin;
}

final class AccountController extends ChangeNotifier {
  AccountController({required this.repository, required this.activities}) {
    activities.onEmailApprovalDecision = resolveEmailChange;
  }

  final AccountProfileRepository repository;
  final SuperadminActivityController activities;
  AccountProfile? _profile;
  String? _emailActivityId;
  bool _busy = false;
  String? _message;
  AccountControllerState _state = const AccountControllerState(phase: AccountControllerPhase.idle);
  var _loadGeneration = 0;
  var _loadInFlight = false;
  var _commandGeneration = 0;
  var _commandInFlight = false;
  var _disposed = false;
  var _profileRevision = 0;

  AccountControllerState get state => _state;
  AccountProfile? get profile => _profile;
  bool get busy => _busy;
  String? get message => _message;

  Future<void> load() async {
    if (_disposed || _busy) return;
    final generation = ++_loadGeneration;
    _loadInFlight = true;
    _profile = null;
    _message = null;
    _state = const AccountControllerState(phase: AccountControllerPhase.loading);
    notifyListeners();
    try {
      final loaded = await repository.load();
      if (!_isCurrentLoad(generation)) return;
      _profile = loaded;
      _profileRevision += 1;
      _state = AccountControllerState(
        phase: AccountControllerPhase.ready,
        profile: loaded,
        profileRevision: _profileRevision,
        updateOrigin: AccountProfileUpdateOrigin.load,
      );
      notifyListeners();
    } catch (_) {
      if (!_isCurrentLoad(generation)) return;
      _message = 'Não foi possível carregar o perfil. Tente novamente.';
      _state = AccountControllerState(phase: AccountControllerPhase.failure, message: _message);
      notifyListeners();
    } finally {
      if (_isCurrentLoad(generation)) _loadInFlight = false;
    }
  }

  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String mobilePhone,
    required AccountAvatar avatar,
  }) async {
    final current = _profile;
    if (current == null) return;
    final generation = _beginCommand();
    if (generation == null) return;
    var next = current.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      mobilePhone: mobilePhone.trim(),
      avatar: avatar,
    );
    final normalizedEmail = email.trim().toLowerCase();
    final requestsEmailChange = normalizedEmail != current.email;
    if (requestsEmailChange) {
      next = next.requestEmailChange(normalizedEmail);
    }
    try {
      await repository.save(next);
      if (!_isCurrentCommand(generation)) return;
      _profile = next;
      _profileRevision += 1;
      if (requestsEmailChange) {
        if (_emailActivityId != null) activities.removeActivity(_emailActivityId!);
        _emailActivityId = activities.addEmailApproval(requestedEmail: normalizedEmail);
        _message = 'Solicitação enviada para aprovação.';
      } else {
        _message = 'Perfil atualizado.';
      }
      _state = AccountControllerState(
        phase: AccountControllerPhase.ready,
        profile: next,
        busy: true,
        message: _message,
        profileRevision: _profileRevision,
        updateOrigin: AccountProfileUpdateOrigin.save,
      );
    } catch (_) {
      if (!_isCurrentCommand(generation)) return;
      _message = 'Não foi possível salvar o perfil. Tente novamente.';
    } finally {
      _finishCommand(generation);
    }
  }

  Future<void> cancelEmailChange() async {
    final current = _profile;
    if (current == null || current.emailChange?.status != EmailChangeStatus.pending) return;
    final generation = _beginCommand();
    if (generation == null) return;
    final next = current.copyWith(clearEmailChange: true);
    try {
      await repository.save(next);
      if (!_isCurrentCommand(generation)) return;
      if (_emailActivityId != null) activities.removeActivity(_emailActivityId!);
      _emailActivityId = null;
      _profile = next;
      _message = 'Solicitação cancelada.';
      _profileRevision += 1;
      _state = AccountControllerState(
        phase: AccountControllerPhase.ready,
        profile: next,
        busy: true,
        message: _message,
        profileRevision: _profileRevision,
        updateOrigin: AccountProfileUpdateOrigin.cancelEmailChange,
      );
    } catch (_) {
      if (!_isCurrentCommand(generation)) return;
      _message = 'Não foi possível cancelar a solicitação. Tente novamente.';
    } finally {
      _finishCommand(generation);
    }
  }

  Future<void> resolveEmailChange(String activityId, {required bool approved}) async {
    final current = _profile;
    if (current == null || activityId != _emailActivityId) return;
    final generation = _beginCommand();
    if (generation == null) return;
    final next = current.resolveEmailChange(approved: approved);
    try {
      await repository.save(next);
      if (!_isCurrentCommand(generation)) return;
      activities.resolveEmailApproval(activityId, approved: approved);
      _profile = next;
      _message = approved ? 'Novo e-mail aprovado.' : 'Alteração de e-mail recusada.';
      _profileRevision += 1;
      _state = AccountControllerState(
        phase: AccountControllerPhase.ready,
        profile: next,
        busy: true,
        message: _message,
        profileRevision: _profileRevision,
        updateOrigin: AccountProfileUpdateOrigin.resolveEmailChange,
      );
    } catch (_) {
      if (!_isCurrentCommand(generation)) return;
      _message = 'Não foi possível concluir a decisão. Tente novamente.';
    } finally {
      _finishCommand(generation);
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (currentPassword.trim().isEmpty) return 'Informe a senha atual.';
    if (newPassword != confirmation) return 'As senhas não coincidem.';
    if (newPassword.length < 8) return 'Use pelo menos 8 caracteres.';
    return 'Troca de senha indisponível nesta versão.';
  }

  bool _isCurrentLoad(int generation) => !_disposed && generation == _loadGeneration;

  int? _beginCommand() {
    if (_disposed || _loadInFlight || _commandInFlight) return null;
    final generation = ++_commandGeneration;
    _commandInFlight = true;
    _busy = true;
    _message = null;
    _state = AccountControllerState(
      phase: _profile == null ? AccountControllerPhase.idle : AccountControllerPhase.ready,
      profile: _profile,
      busy: true,
      profileRevision: _profileRevision,
    );
    notifyListeners();
    return generation;
  }

  bool _isCurrentCommand(int generation) =>
      !_disposed && _commandInFlight && generation == _commandGeneration;

  void _finishCommand(int generation) {
    if (!_isCurrentCommand(generation)) return;
    _commandInFlight = false;
    _busy = false;
    _state = AccountControllerState(
      phase: _profile == null ? AccountControllerPhase.idle : AccountControllerPhase.ready,
      profile: _profile,
      message: _message,
      profileRevision: _profileRevision,
      updateOrigin: _state.updateOrigin,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration += 1;
    _commandGeneration += 1;
    _commandInFlight = false;
    if (activities.onEmailApprovalDecision == resolveEmailChange) {
      activities.onEmailApprovalDecision = null;
    }
    super.dispose();
  }
}
