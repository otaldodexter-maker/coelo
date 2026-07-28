import 'package:flutter/foundation.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../data/account_profile_repository.dart';
import '../domain/account_profile.dart';

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

  AccountProfile? get profile => _profile;
  bool get busy => _busy;
  String? get message => _message;

  Future<void> load() async {
    _profile = await repository.load();
    notifyListeners();
  }

  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String email,
    required AccountAvatar avatar,
  }) async {
    final current = _profile;
    if (current == null || _busy) return;
    _setBusy(true);
    var next = current.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      avatar: avatar,
    );
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail != current.email) {
      next = next.requestEmailChange(normalizedEmail);
      if (_emailActivityId != null) activities.removeActivity(_emailActivityId!);
      _emailActivityId = activities.addEmailApproval(requestedEmail: normalizedEmail);
      _message = 'Solicitação enviada para aprovação.';
    } else {
      _message = 'Perfil atualizado.';
    }
    await repository.save(next);
    _profile = next;
    _setBusy(false);
  }

  Future<void> cancelEmailChange() async {
    final current = _profile;
    if (current == null || current.emailChange?.status != EmailChangeStatus.pending) return;
    final next = current.copyWith(clearEmailChange: true);
    await repository.save(next);
    if (_emailActivityId != null) activities.removeActivity(_emailActivityId!);
    _emailActivityId = null;
    _profile = next;
    _message = 'Solicitação cancelada.';
    notifyListeners();
  }

  Future<void> resolveEmailChange(String activityId, {required bool approved}) async {
    final current = _profile;
    if (current == null || activityId != _emailActivityId) return;
    final next = current.resolveEmailChange(approved: approved);
    await repository.save(next);
    activities.resolveEmailApproval(activityId, approved: approved);
    _profile = next;
    _message = approved ? 'Novo e-mail aprovado.' : 'Alteração de e-mail recusada.';
    notifyListeners();
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (currentPassword != 'coelo-demo') return 'A senha atual não confere.';
    if (newPassword != confirmation) return 'As senhas não coincidem.';
    if (newPassword.length < 8) return 'Use pelo menos 8 caracteres.';
    _message = 'Senha alterada neste protótipo.';
    notifyListeners();
    return null;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (activities.onEmailApprovalDecision == resolveEmailChange) {
      activities.onEmailApprovalDecision = null;
    }
    super.dispose();
  }
}
